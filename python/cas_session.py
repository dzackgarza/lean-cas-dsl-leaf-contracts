"""Native cas-computation/2 process, exports and explicitly captured generators.

Framing reuses cas_port. Generator advancement and disposal use Python's native
send/close contract: https://docs.python.org/3/reference/expressions.html#generator-iterator-methods
The public control shapes are fixed by the kernel's computation contract; these
records establish transport structure, never a mathematical result type or law.
"""

from __future__ import annotations

from collections.abc import Callable, Generator
from contextvars import ContextVar
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, JsonValue, TypeAdapter, model_validator

from cas_port import point_invocation, read_frame, write_frame

__all__ = ["JsonValue", "Proxy", "Suspension", "export", "proxy", "serve", "suspend"]

_json = TypeAdapter(JsonValue, config=ConfigDict(allow_inf_nan=False))
type Natural = Annotated[int, Field(strict=True, ge=0)]
type Text = Annotated[str, Field(strict=True, min_length=1)]


class _Control(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", frozen=True, allow_inf_nan=False)


class _Hello(_Control):
    op: Literal["hello"]
    protocol: Annotated[int, Field(strict=True, ge=2, le=2)]
    contract: Literal["cas-computation/2"]


class _Request(_Control):
    protocol: Annotated[int, Field(strict=True, ge=2, le=2)]
    request_id: Natural
    op: Text


class _Invoke(_Request):
    input: Text
    scope_id: Text
    args: JsonValue


class _Published(_Control):
    kind: Literal["published"]
    operation: Text
    input: Text
    args: dict[str, JsonValue]

    @model_validator(mode="after")
    def complete_invocation(self) -> _Published:
        point_invocation(self.args, self.operation)
        return self


class _Binding(_Control):
    slot: Natural
    value: JsonValue


class _Dependent(_Control):
    kind: Literal["dependent"]
    prepared_role: Text
    parameters: list[JsonValue]
    bindings: list[_Binding]
    arguments: list[JsonValue]
    argument_layouts: list[dict[str, JsonValue]]
    result_layout: dict[str, JsonValue]

    @model_validator(mode="after")
    def ordered_arguments(self) -> _Dependent:
        slots = [binding.slot for binding in self.bindings]
        if slots != sorted(set(slots)):
            raise ValueError("dependent bindings require unique ordered slots")
        if len(self.arguments) != len(self.argument_layouts):
            raise ValueError("dependent arguments and prepared layouts have different arities")
        return self


class _InvokeExport(_Request):
    op: Literal["$cas.invoke_export"]
    scope_id: Text
    token: Text
    context: Annotated[_Published | _Dependent, Field(discriminator="kind")]


class _Resume(_Request):
    op: Literal["$cas.resume"]
    scope_id: Text
    continuation: Text
    captures: list[JsonValue]
    results: list[JsonValue]


class _Discard(_Request):
    op: Literal["$cas.discard"]
    discard_request_id: Natural


class _Call(_Control):
    op: Text
    input: Text
    args: JsonValue

    @model_validator(mode="after")
    def published_operation(self) -> _Call:
        if self.op.startswith("$cas."):
            raise ValueError("a graph control has no mathematical input address")
        return self


class _Project(_Control):
    value: JsonValue
    field: Natural


class _Apply(_Control):
    value: JsonValue
    arguments: list[JsonValue]


class _GraphCall(_Control):
    op: Literal["$cas.project", "$cas.apply"]
    args: dict[str, JsonValue]

    @model_validator(mode="after")
    def graph_arguments(self) -> _GraphCall:
        if self.op == "$cas.project":
            reference = _Project.model_validate(self.args).value
        else:
            reference = _Apply.model_validate(self.args).value
        if _reference(reference) is None:
            raise ValueError("a graph control requires a public value reference")
        return self


def _scope(slot: int) -> dict[str, JsonValue]:
    return {"ctor": "scopeRef", "args": [slot]}


def _reference(value: JsonValue) -> tuple[str, tuple[str | int, ...]] | None:
    if not isinstance(value, dict) or value.get("ctor") not in ("scopeRef", "inputRef", "resultRef"):
        return None
    if set(value) != {"ctor", "args"}:
        raise ValueError("a public reference has unexpected or missing fields")
    arguments = value["args"]
    if not isinstance(arguments, list) or len(arguments) != 1:
        raise ValueError("a public reference requires exactly one address")
    kind = value["ctor"]
    assert isinstance(kind, str)
    if kind == "inputRef":
        path = arguments[0]
        if not isinstance(path, list) or any(
            not (isinstance(step, str) or type(step) is int and step >= 0) for step in path
        ):
            raise ValueError("an input reference requires field names or natural indices")
        return kind, tuple(path)
    slot = arguments[0]
    if type(slot) is not int or slot < 0:
        raise ValueError("a public reference requires a natural slot")
    return kind, (slot,)


def _references(value: JsonValue) -> list[dict[str, JsonValue]]:
    if _reference(value) is not None:
        assert isinstance(value, dict)
        return [value]
    if isinstance(value, list):
        return [reference for item in value for reference in _references(item)]
    if isinstance(value, dict):
        return [reference for item in value.values() for reference in _references(item)]
    return []


def _call(value: dict[str, JsonValue]) -> dict[str, JsonValue]:
    parsed = (_GraphCall if value.get("op") in ("$cas.project", "$cas.apply") else _Call)
    return _json.validate_python(parsed.model_validate(value).model_dump(mode="json"))


class Proxy:
    """One public reference occurrence; access requires the currently active gateway."""

    def reference(self) -> dict[str, JsonValue]:
        return _current().reference(self)

    def project(self, field: int) -> dict[str, JsonValue]:
        return _call({"op": "$cas.project", "args": {"value": self.reference(), "field": field}})

    def apply(self, arguments: list[JsonValue]) -> dict[str, JsonValue]:
        return _call({"op": "$cas.apply", "args": {
            "value": self.reference(), "arguments": arguments}})


class Suspension(BaseModel):
    """A finite call group and the exact proxy occurrences retained after it."""

    model_config = ConfigDict(frozen=True, arbitrary_types_allowed=True)
    calls: tuple[dict[str, JsonValue], ...]
    captures: tuple[Proxy, ...]


type Handler = Callable[[JsonValue], JsonValue | Generator[Suspension, list[Proxy], JsonValue]]


class _Export:
    def __init__(self, request: int, handler: Handler, captures: list[JsonValue]):
        self.request = request
        self.handler = handler
        self.captures = captures


class _Continuation:
    def __init__(self, request: int, generator: Generator[Suspension, list[Proxy], JsonValue],
                 captures: tuple[Proxy, ...], result_count: int):
        self.request = request
        self.generator = generator
        self.captures = captures
        self.result_count = result_count


class _Gateway:
    def __init__(self, session: _Session, request: int, scope: str, arguments: JsonValue):
        self.session = session
        self.request = request
        self.scope = scope
        self.bindings: dict[Proxy, dict[str, JsonValue]] = {}
        self.arguments = _json.validate_json(_json.dump_json(arguments))
        self.allowed = _references(self.arguments)
        self.exports: list[dict[str, JsonValue]] = []

    def admits(self, reference: JsonValue) -> bool:
        address = _reference(reference)
        if address is None:
            return False
        if address[0] != "inputRef":
            return reference in self.allowed
        # The kernel additionally checks that this is a complete prepared typed position.
        value = self.arguments
        for step in address[1]:
            if isinstance(step, str) and isinstance(value, dict) and step in value:
                value = value[step]
            elif type(step) is int and isinstance(value, list) and step < len(value):
                value = value[step]
            else:
                return False
        return True

    def reference(self, value: Proxy) -> dict[str, JsonValue]:
        if _active.get() is not self or value not in self.bindings:
            raise ValueError("the proxy is expired or was not retained by this continuation")
        # Return a copy: mutating caller data cannot rewrite the retained correspondence.
        return _json.validate_json(_json.dump_json(self.bindings[value]))

    def proxy(self, reference: JsonValue) -> Proxy:
        address = _reference(reference)
        if address is None or not self.admits(reference):
            raise ValueError("the proxy address was not supplied in this request scope")
        for value, existing in self.bindings.items():
            if _reference(existing) == address:
                return value
        assert isinstance(reference, dict)
        value = Proxy()
        self.bindings[value] = _json.validate_json(_json.dump_json(reference))
        return value


_active: ContextVar[_Gateway | None] = ContextVar("cas_computation_gateway", default=None)


def _current() -> _Gateway:
    gateway = _active.get()
    if gateway is None:
        raise ValueError("no computational request gateway is active")
    return gateway


def proxy(reference: JsonValue) -> Proxy:
    """Retain an explicitly supplied public reference, with no foreign-token decoding."""
    return _current().proxy(reference)


def export(handler: Handler, captures: list[Proxy]) -> dict[str, JsonValue]:
    """Lease this actual callable on this process, declaring its public dependencies."""
    gateway = _current()
    references = [value.reference() for value in captures]
    _unique(references)
    token = gateway.session.token("export")
    gateway.session.exports[token] = _Export(gateway.request, handler, references)
    gateway.exports.append({"token": token, "captures": references})
    return {"ctor": "opaqueData", "args": [token]}


def suspend(calls: list[dict[str, JsonValue]], captures: list[Proxy]) -> Suspension:
    """Yield this group; only the declared proxies can be rebound on resume."""
    if not calls:
        raise ValueError("a suspension requires a nonempty finite call group")
    return Suspension(calls=tuple(_call(call) for call in calls), captures=tuple(captures))


def _unique(references: list[JsonValue]) -> None:
    addresses = [_reference(value) for value in references]
    if len(set(addresses)) != len(addresses):
        raise ValueError("a capture address is repeated")


def _check_value(value: JsonValue, gateway: _Gateway, result_bound: int) -> None:
    if (address := _reference(value)) is not None:
        if address[0] == "resultRef":
            index = address[1][0]
            assert isinstance(index, int)
            if index >= result_bound:
                raise ValueError("a result reference is self, forward or outside its group")
        elif not gateway.admits(value):
            raise ValueError("a reply used a reference outside its active scope")
        return
    if isinstance(value, dict):
        if value.get("ctor") == "deferredData":
            raise ValueError("a deferred program is not a nested data constructor")
        if value.get("ctor") == "opaqueData":
            arguments = value.get("args")
            if set(value) != {"ctor", "args"} or not isinstance(arguments, list) or \
                    len(arguments) != 1 or not isinstance(arguments[0], str) or \
                    not any(entry["token"] == arguments[0] for entry in gateway.exports):
                raise ValueError("an opaque result has no export declaration in this reply")
            return
        for item in value.values():
            _check_value(item, gateway, result_bound)
    elif isinstance(value, list):
        for item in value:
            _check_value(item, gateway, result_bound)


class _Session:
    def __init__(self, operations: dict[str, Handler]):
        if any(not name or name.startswith("$cas.") for name in operations):
            raise ValueError("ordinary handlers require published operation addresses")
        self.operations = dict(operations)
        self.exports: dict[str, _Export] = {}
        self.continuations: dict[str, _Continuation] = {}
        self.next_token = 0
        self.last_request = -1

    def token(self, kind: str) -> str:
        token = f"{kind}-{self.next_token}"
        self.next_token += 1
        return token

    def dispose(self, request: int) -> None:
        for token, retained in list(self.continuations.items()):
            if retained.request == request:
                del self.continuations[token]
                retained.generator.close()
        for token, retained in list(self.exports.items()):
            if retained.request == request:
                del self.exports[token]

    def reply(self, gateway: _Gateway, result: JsonValue) -> dict[str, JsonValue]:
        if isinstance(result, dict) and result.get("ctor") == "deferredData":
            if set(result) != {"ctor", "args"} or not isinstance(result["args"], list) or \
                    len(result["args"]) != 2 or not isinstance(result["args"][0], list):
                raise ValueError("a deferred reply requires its calls and final template")
            calls, template = result["args"]
            for index, call in enumerate(calls):
                if not isinstance(call, dict):
                    raise ValueError("a deferred call requires a control record")
                _check_value(_call(call)["args"], gateway, index)
            _check_value(template, gateway, len(calls))
        else:
            _check_value(result, gateway, 0)
        return {"request_id": gateway.request, "status": "ok", "value": result,
                "exports": gateway.exports}

    def advance(self, gateway: _Gateway, generator: Generator[Suspension, list[Proxy], JsonValue],
                results: list[Proxy] | None) -> dict[str, JsonValue]:
        try:
            try:
                suspension = next(generator) if results is None else generator.send(results)
            except StopIteration as stopped:
                return self.reply(gateway, _json.validate_python(stopped.value))
            if not isinstance(suspension, Suspension) or not suspension.calls:
                raise ValueError("a generator must yield a nonempty suspension")
            references = [value.reference() for value in suspension.captures]
            _unique(references)
            calls = [_call(call) for call in suspension.calls]
            for index, call in enumerate(calls):
                _check_value(call["args"], gateway, index)
            token = self.token("continuation")
            self.continuations[token] = _Continuation(
                gateway.request, generator, suspension.captures, len(calls))
            return {"request_id": gateway.request, "status": "suspended", "continuation": token,
                    "captures": references, "calls": calls, "exports": gateway.exports}
        except Exception:
            generator.close()
            raise

    def run_handler(self, gateway: _Gateway, handler: Handler, arguments: JsonValue) -> dict[str, JsonValue]:
        entered = _active.set(gateway)
        try:
            result = handler(arguments)
            if isinstance(result, Generator):
                return self.advance(gateway, result, None)
            return self.reply(gateway, _json.validate_python(result))
        finally:
            _active.reset(entered)

    def resume(self, request: _Resume) -> dict[str, JsonValue]:
        retained = self.continuations.pop(request.continuation, None)
        if retained is None:
            raise ValueError("the continuation is absent or already consumed")
        try:
            count = len(retained.captures)
            if request.captures != [_scope(index) for index in range(count)] or \
                    request.results != [_scope(count + index) for index in range(retained.result_count)]:
                raise ValueError("resume changed the exact capture/result arrays")
            gateway = _Gateway(self, request.request_id, request.scope_id,
                               request.captures + request.results)
            for value, reference in zip(retained.captures, request.captures, strict=True):
                assert isinstance(reference, dict)
                gateway.bindings[value] = reference
            results = [gateway.proxy(reference) for reference in request.results]
            entered = _active.set(gateway)
            try:
                return self.advance(gateway, retained.generator, results)
            finally:
                _active.reset(entered)
        except Exception:
            retained.generator.close()
            raise

    def dispatch(self, frame: JsonValue) -> dict[str, JsonValue]:
        if not isinstance(frame, dict):
            raise ValueError("a request requires an object frame")
        request_id = frame.get("request_id")
        if type(request_id) is not int or request_id < 0:
            raise ValueError("a request requires a natural request_id")
        if request_id <= self.last_request:
            return {"request_id": request_id, "status": "error", "kind": "ValueError",
                    "message": "request IDs must increase on this connection"}
        self.last_request = request_id
        try:
            operation = frame.get("op")
            if operation == "$cas.discard":
                request = _Discard.model_validate(frame)
                if request.discard_request_id >= request_id:
                    raise ValueError("cleanup must name a preceding request")
                self.dispose(request.discard_request_id)
                return {"request_id": request_id, "status": "ok", "disposed": True}
            if operation == "$cas.resume":
                return self.resume(_Resume.model_validate(frame))
            if operation == "$cas.invoke_export":
                request = _InvokeExport.model_validate(frame)
                retained = self.exports.get(request.token)
                if retained is None:
                    raise ValueError("the native export is absent or was discarded")
                arguments = _json.validate_python(request.context.model_dump(mode="json"))
                return self.run_handler(
                    _Gateway(self, request_id, request.scope_id, arguments), retained.handler, arguments)
            request = _Invoke.model_validate(frame)
            handler = self.operations.get(request.op)
            if handler is None:
                return {"request_id": request_id, "status": "unsupported", "op": request.op}
            return self.run_handler(
                _Gateway(self, request_id, request.scope_id, request.args), handler, request.args)
        except Exception as error:
            self.dispose(request_id)
            return {"request_id": request_id, "status": "error", "kind": type(error).__name__,
                    "message": str(error)}


def serve(backend: str, backend_version: str, operations: dict[str, Handler]) -> None:
    """Negotiate v2, then serve framed computation and one-use continuation requests."""
    if not backend or not backend_version:
        raise ValueError("ready requires backend and version diagnostics")
    session = _Session(operations)
    write_frame({"op": "ready", "protocol": 2, "contract": "cas-computation/2",
                 "features": ["scoped-values/2", "deferred/2", "suspend-resume/2"],
                 "backend": backend, "backend_version": backend_version})
    _Hello.model_validate(read_frame())
    write_frame({"op": "hello", "status": "ok", "protocol": 2, "contract": "cas-computation/2"})
    try:
        while (frame := read_frame()) is not None:
            write_frame(session.dispatch(_json.validate_python(frame)))
    finally:
        for retained in list(session.continuations.values()):
            retained.generator.close()
        session.continuations.clear()
        session.exports.clear()
