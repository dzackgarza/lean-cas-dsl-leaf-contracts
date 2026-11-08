#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts>=5.4.0", "pydantic>=2.14.3"]
# ///
"""Explicit, lossless v1 process adapter; no mathematical decoding.

Framing and native leases reuse cas_port and cas_session. Process lifetime uses
subprocess.Popen; aliases use weakref.WeakValueDictionary so the SDK's actual
request-local export leases own their lifetime. References:
https://docs.python.org/3/library/subprocess.html#subprocess.Popen
https://docs.python.org/3/library/weakref.html#weakref.WeakValueDictionary
https://cyclopts.readthedocs.io/en/latest/api.html
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
from threading import Event, Thread
from types import FrameType
from typing import Annotated, Literal, Never
from weakref import WeakValueDictionary

from cyclopts import App
from pydantic import BaseModel, ConfigDict, Field, JsonValue, TypeAdapter

from cas_port import input_ref, read_frame, write_frame
from cas_session import ComputationError, Handler, Proxy, UnsupportedOperation, export, proxy, request_input, serve

LEGACY_REVISION = "f0431bebeb01c93cc65bb3fdc5bd23d9613e4b31"
LEGACY_HELPER_SHA256 = "1a061bfbc3dc40dadc157deaeb11dbd838d7f2710e53f1fe8f369bd60d43e6f5"
ROOT = Path(__file__).resolve().parent.parent
type Text = Annotated[str, Field(strict=True, min_length=1)]
type Natural = Annotated[int, Field(strict=True, ge=0)]
type Capture = tuple[Proxy, JsonValue]


class Record(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", frozen=True, allow_inf_nan=False)


class FileReceipt(Record):
    path: Path
    sha256: Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]

    @classmethod
    def read(cls, path: Path) -> FileReceipt:
        path = path.resolve(strict=True)
        return cls(path=path, sha256=hashlib.sha256(path.read_bytes()).hexdigest())

    def verify(self) -> None:
        if self != self.read(self.path):
            raise ValueError(f"a bridge input changed: {self.path}")


class Backend(BaseModel):
    model_config = ConfigDict(strict=True, extra="ignore", frozen=True)
    name: Text
    command: Text
    args: list[str] = Field(default_factory=list)


class Registration(BaseModel):
    model_config = ConfigDict(strict=True, extra="ignore", frozen=True)
    operation: Text
    input: Text
    backend: Text


class Manifest(BaseModel):
    model_config = ConfigDict(strict=True, extra="ignore", frozen=True)
    backends: list[Backend] = Field(default_factory=list)
    registrations: list[Registration] = Field(default_factory=list)


class LegacyContract(Record):
    root: Path
    revision: Literal["f0431bebeb01c93cc65bb3fdc5bd23d9613e4b31"]
    helper: FileReceipt

    @classmethod
    def read(cls, root: Path) -> LegacyContract:
        root = root.resolve(strict=True)
        revision = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
        if revision != LEGACY_REVISION:
            raise ValueError("the legacy contract is not the required pinned revision")
        dirty = subprocess.check_output(["git", "-C", str(root), "status", "--porcelain"], text=True)
        if dirty:
            raise ValueError("the legacy contract checkout is dirty")
        helper = FileReceipt.read(root / "python/cas_port.py")
        if helper.sha256 != LEGACY_HELPER_SHA256:
            raise ValueError("the legacy helper does not match its required source digest")
        return cls(root=root, revision=LEGACY_REVISION, helper=helper)

    def verify(self) -> None:
        if self != self.read(self.root):
            raise ValueError("the legacy contract identity changed")


class LaunchDescriptor(Record):
    format: Literal["cas-v1-command/1"]
    backend: Backend
    manifest: FileReceipt
    launcher: FileReceipt
    inputs: list[FileReceipt]
    runtime: list[FileReceipt]
    legacy: LegacyContract
    cwd: Path
    environment: dict[str, str]

    def verify(self) -> None:
        self.manifest.verify()
        self.launcher.verify()
        self.legacy.verify()
        for receipt in self.inputs + self.runtime:
            receipt.verify()
        source = Manifest.model_validate_json(self.manifest.path.read_bytes())
        matches = [backend for backend in source.backends if backend.name == self.backend.name]
        if matches != [self.backend] or self.cwd != self.manifest.path.parent:
            raise ValueError("the launch descriptor changed its original backend or cwd")
        required = [ROOT / "python" / name for name in ["cas_v1_bridge.py", "cas_port.py", "cas_session.py"]]
        if [receipt.path for receipt in self.runtime] != required:
            raise ValueError("the descriptor does not name the selected bridge runtime")


class Preparation(Record):
    manifest: Path
    legacy_contract: Path
    output_manifest: Path


class Launch(Record):
    legacy_command_json: Path


class Verification(Record):
    manifest: Path
    execution_manifest: Path


class ExecutionReceipt(Record):
    format: Literal["cas-v1-execution/1"]
    guards: list[FileReceipt]


def verify_execution(options: Verification) -> None:
    original = FileReceipt.read(options.manifest)
    translated = FileReceipt.read(options.execution_manifest)
    source = Manifest.model_validate_json(original.path.read_bytes())
    execution = Manifest.model_validate_json(translated.path.read_bytes())
    if source.registrations != execution.registrations:
        raise ValueError("the execution manifest changed the original registrations")
    names = [backend.name for backend in source.backends]
    if len(names) != len(set(names)) or names != [backend.name for backend in execution.backends]:
        raise ValueError("the execution manifest changed the original backend identities")
    guards = [original, translated]
    for backend, wrapper in zip(source.backends, execution.backends, strict=True):
        if len(wrapper.args) != 3:
            raise ValueError("the execution backend has an invalid wrapper command")
        descriptor_path = Path(wrapper.args[2])
        if not descriptor_path.is_absolute():
            raise ValueError("the launch descriptor path must be absolute")
        receipt = FileReceipt.read(descriptor_path)
        descriptor = LaunchDescriptor.model_validate_json(receipt.path.read_bytes())
        descriptor.verify()
        if descriptor.manifest != original or descriptor.backend != backend:
            raise ValueError("the execution descriptor changed its original backend")
        if (not Path(wrapper.command).is_absolute()
                or Path(wrapper.command).resolve(strict=True) != descriptor.launcher.path
                or wrapper.args != [str(ROOT / "python/cas_v1_bridge.py"),
                                    "--legacy-command-json", str(descriptor_path)]):
            raise ValueError("the execution backend changed its exact wrapper command")
        guards.extend([receipt, descriptor.launcher, descriptor.legacy.helper,
                       *descriptor.inputs, *descriptor.runtime])
    unique = {receipt.path: receipt for receipt in guards}
    print(ExecutionReceipt(format="cas-v1-execution/1",
                           guards=[unique[path] for path in sorted(unique)]).model_dump_json())


def write_new(path: Path, model: BaseModel) -> None:
    # Descriptors retain the exact original environment; only their owner may read them.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(model.model_dump_json(indent=2) + "\n")


def prepare(options: Preparation) -> None:
    original = FileReceipt.read(options.manifest)
    manifest = Manifest.model_validate_json(original.path.read_bytes())
    legacy = LegacyContract.read(options.legacy_contract)
    output = options.output_manifest.resolve()
    if any(output.is_relative_to(source) for source in [original.path.parent, legacy.root, ROOT]):
        raise ValueError("the execution manifest must be outside every source directory")
    names = [backend.name for backend in manifest.backends]
    if len(names) != len(set(names)):
        raise ValueError("the original manifest repeats a backend identity")
    if any(row.backend not in names for row in manifest.registrations):
        raise ValueError("an original registration has no backend")
    environment = dict(os.environ)
    runtime = [FileReceipt.read(ROOT / "python" / name)
               for name in ["cas_v1_bridge.py", "cas_port.py", "cas_session.py"]]
    output.parent.mkdir(parents=True, exist_ok=True)
    backends: list[Backend] = []
    for index, backend in enumerate(manifest.backends):
        executable = shutil.which(backend.command, path=environment["PATH"])
        if "/" in backend.command:
            executable = str(original.path.parent / backend.command)
        if executable is None:
            raise FileNotFoundError(f"the original executable is unavailable: {backend.command}")
        inputs = [FileReceipt.read(Path(executable))]
        for argument in backend.args:
            candidate = original.path.parent / argument
            if candidate.is_file():
                inputs.append(FileReceipt.read(candidate))
        descriptor_path = output.parent / f"backend-{index}.json"
        descriptor = LaunchDescriptor(
            format="cas-v1-command/1", backend=backend, manifest=original,
            launcher=FileReceipt.read(Path(sys.executable)),
            inputs=inputs, runtime=runtime, legacy=legacy,
            cwd=original.path.parent, environment=environment,
        )
        descriptor.verify()
        write_new(descriptor_path, descriptor)
        backends.append(Backend(name=backend.name, command=str(Path(sys.executable).absolute()),
                                args=[str(ROOT / "python/cas_v1_bridge.py"),
                                      "--legacy-command-json", str(descriptor_path)]))
    write_new(output, Manifest(backends=backends, registrations=manifest.registrations))


class Ready(Record):
    op: Literal["ready"]
    protocol: Annotated[int, Field(strict=True, ge=1, le=1)]
    backend: Text
    backend_version: Text
    adapter_version: Text
    capabilities: list[Text]


class Success(Record):
    request_id: Natural
    status: Literal["ok"]
    value: JsonValue


class Failure(Record):
    request_id: Natural
    status: Literal["error"]
    kind: Text
    message: str


class Unsupported(Record):
    request_id: Natural
    status: Literal["unsupported"]
    op: Text


class Opaque(Record):
    ctor: Literal["opaqueData"]
    args: Annotated[list[Text], Field(min_length=1, max_length=1)]


reply_type = TypeAdapter(Annotated[Success | Failure | Unsupported, Field(discriminator="status")])


class Alias:
    def __init__(self, bridge: Bridge, token: str, captures: tuple[Capture, ...]) -> None:
        self.bridge = bridge
        self.token = token
        self.captures = captures

    def __call__(self, context: JsonValue) -> JsonValue:
        assert isinstance(context, dict)
        if context["kind"] != "published":
            raise UnsupportedOperation("$cas.invoke_export")
        operation, input_form = context["operation"], context["input"]
        assert isinstance(operation, str) and isinstance(input_form, str)
        return self.bridge.invoke(operation, input_form, context["args"], self.captures,
                                  context, ["args"])


class Bridge:
    def __init__(self, descriptor: LaunchDescriptor) -> None:
        descriptor.verify()
        environment = dict(descriptor.environment,
                           CAS_LEAF_CONTRACT_PATH=str(descriptor.legacy.root),
                           PYTHONPATH=str(descriptor.legacy.root / "python"))
        self.child = subprocess.Popen(
            [descriptor.backend.command, *descriptor.backend.args], cwd=descriptor.cwd,
            env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        )
        self.stopping = Event()
        self.next_request = 0
        self.aliases: WeakValueDictionary[str, Alias] = WeakValueDictionary()

    def close(self) -> None:
        self.stopping.set()
        assert self.child.stdin is not None and self.child.stdout is not None
        self.child.stdin.close()
        if self.child.poll() is None:
            self.child.terminate()
        self.child.wait()
        self.child.stdout.close()

    def read(self) -> JsonValue:
        assert self.child.stdout is not None
        try:
            value = read_frame(self.child.stdout)
        except EOFError as error:
            raise SystemExit("the original child lost its framed channel") from error
        if value is None:
            raise SystemExit("the original child closed its framed channel")
        return value

    def watch(self) -> None:
        self.child.wait()
        if not self.stopping.is_set():
            print("the original child exited; closing its bridge connection", file=sys.stderr, flush=True)
            os._exit(1)

    def handler(self, operation: str) -> Handler:
        def invoke(arguments: JsonValue) -> JsonValue:
            return self.invoke(operation, request_input(), arguments, (), arguments, [])
        return invoke

    def original(self, value: JsonValue, captures: tuple[Capture, ...], operation: str) -> JsonValue:
        if isinstance(value, dict):
            if value.get("ctor") == "opaqueData":
                token = Opaque.model_validate(value).args[0]
                alias = self.aliases.get(token)
                if alias is None:
                    raise ValueError("a native alias is absent or was discarded")
                return {"ctor": "opaqueData", "args": [alias.token]}
            if value.get("ctor") == "scopeRef":
                for reference, original in captures:
                    if reference.reference() == value:
                        return original
                raise UnsupportedOperation(operation)
            return {key: self.original(item, captures, operation) for key, item in value.items()}
        if isinstance(value, list):
            return [self.original(item, captures, operation) for item in value]
        return value

    def captured(self, arguments: JsonValue, gateway_arguments: JsonValue, prefix: list[str | int],
                 captures: tuple[Capture, ...], operation: str) -> tuple[Capture, ...]:
        retained = list(captures)

        def retain(reference: JsonValue, original: JsonValue) -> None:
            candidate = proxy(reference)
            if all(existing is not candidate for existing, _ in retained):
                retained.append((candidate, original))

        def visit(value: JsonValue, path: list[str | int]) -> None:
            if isinstance(value, dict):
                if value.get("ctor") == "opaqueData":
                    retain(input_ref(prefix + path), self.original(value, captures, operation))
                    return
                if value.get("ctor") == "inputRef":
                    reference = proxy(value)
                    position = value["args"]
                    assert isinstance(position, list) and isinstance(position[0], list)
                    original = gateway_arguments
                    for step in position[0]:
                        if isinstance(step, str) and isinstance(original, dict):
                            original = original[step]
                        elif type(step) is int and isinstance(original, list):
                            original = original[step]
                        else:
                            raise ValueError("an input capture has no actual source position")
                    retain(reference.reference(), self.original(original, captures, operation))
                    return
                for key, item in value.items():
                    visit(item, path + [key])
            elif isinstance(value, list):
                for index, item in enumerate(value):
                    visit(item, path + [index])

        visit(arguments, [])
        return tuple(retained)

    def result(self, value: JsonValue, captures: tuple[Capture, ...]) -> JsonValue:
        if isinstance(value, dict):
            if value.get("ctor") == "opaqueData":
                native = Opaque.model_validate(value).args[0]
                alias = Alias(self, native, captures)
                packet = export(alias, [reference for reference, _ in captures])
                token = Opaque.model_validate(packet).args[0]
                self.aliases[token] = alias
                return packet
            return {key: self.result(item, captures) for key, item in value.items()}
        if isinstance(value, list):
            return [self.result(item, captures) for item in value]
        return value

    def invoke(self, operation: str, input_form: str, arguments: JsonValue,
               captures: tuple[Capture, ...], gateway_arguments: JsonValue,
               prefix: list[str | int]) -> JsonValue:
        original = self.original(arguments, captures, operation)
        retained = self.captured(arguments, gateway_arguments, prefix, captures, operation)
        request = self.next_request
        self.next_request += 1
        assert self.child.stdin is not None
        try:
            write_frame({"request_id": request, "op": operation, "input": input_form,
                         "args": original}, self.child.stdin)
        except BrokenPipeError as error:
            raise SystemExit("the original child lost its request channel") from error
        reply = reply_type.validate_python(self.read())
        if reply.request_id != request:
            raise SystemExit("the original child changed its request correlation")
        if isinstance(reply, Failure):
            raise ComputationError(reply.kind, reply.message)
        if isinstance(reply, Unsupported):
            if reply.op != operation:
                raise ValueError("the original unsupported reply changed its operation")
            raise UnsupportedOperation(operation)
        return self.result(reply.value, retained)


def terminate(signum: int, _frame: FrameType | None) -> Never:
    # Enter the existing child cleanup on connection retirement.
    # Reference: https://docs.python.org/3/library/signal.html#signal.signal.
    raise SystemExit(128 + signum)


def launch(options: Launch) -> None:
    descriptor = LaunchDescriptor.model_validate_json(options.legacy_command_json.read_bytes())
    bridge = Bridge(descriptor)
    try:
        signal.signal(signal.SIGTERM, terminate)
        ready = Ready.model_validate(bridge.read())
        if len(ready.capabilities) != len(set(ready.capabilities)):
            raise ValueError("the original child repeats a capability")
        Thread(target=bridge.watch, daemon=True).start()
        serve(ready.backend, ready.backend_version,
              {operation: bridge.handler(operation) for operation in ready.capabilities})
    finally:
        bridge.close()


app = App()


@app.default
def main(*, manifest: Path | None = None, legacy_contract: Path | None = None,
         output_manifest: Path | None = None, legacy_command_json: Path | None = None,
         execution_manifest: Path | None = None) -> None:
    """Prepare an external execution manifest or launch its exact original child."""
    values = {key: value for key, value in {
        "manifest": manifest, "legacy_contract": legacy_contract,
        "output_manifest": output_manifest, "legacy_command_json": legacy_command_json,
        "execution_manifest": execution_manifest,
    }.items() if value is not None}
    options = TypeAdapter(Preparation | Launch | Verification).validate_python(values)
    if isinstance(options, Preparation):
        prepare(options)
    elif isinstance(options, Launch):
        launch(options)
    else:
        verify_execution(options)


if __name__ == "__main__":
    app()
