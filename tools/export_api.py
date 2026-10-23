"""Export public API documentation from an already built source combination.

The export never updates, fetches, or builds dependencies. See api/README.md for
prerequisites and use --help for explicit checkout/toolchain selection.
"""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile


def revision(path: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_revision(path: Path, target: Path) -> str:
    """A commit identifies the input only when its working source is clean."""
    source = revision(path)
    paths = ["."]
    if target.is_relative_to(path):
        paths.append(f":(exclude){target.relative_to(path)}")
    changes = subprocess.check_output(
        ["git", "-C", str(path), "status", "--porcelain=v1",
         "--untracked-files=all", "--", *paths], text=True
    )
    if changes:
        raise RuntimeError(
            f"source checkout has uncommitted changes: {path}; "
            "commit the selected sources and build them before exporting"
        )
    return source


def package_selection(kernel: Path, packages: Path | None):
    """Resolve existing directories; never ask Lake to materialize Git inputs."""
    manifest_path = kernel / "lake-manifest.json"
    configuration = {}

    def read_configuration(path: Path):
        content = path.read_bytes()
        configuration[path] = hashlib.sha256(content).hexdigest()
        return json.loads(content)

    manifest = read_configuration(manifest_path)
    entries = {entry["name"]: entry for entry in manifest["packages"]}
    implicit = kernel / manifest.get("lakeDir", ".lake") / "package-overrides.json"
    for override in [implicit, packages]:
        if override is None or (override == implicit and not override.exists()):
            continue
        entries.update({entry["name"]: entry
                        for entry in read_configuration(override)["packages"]})
    directories = {}
    local_entries = []
    for name, entry in entries.items():
        if entry["type"] == "path":
            directory = kernel / entry["dir"]
        elif entry["type"] == "git":
            packages_dir = manifest.get("packagesDir")
            if not packages_dir:
                raise RuntimeError(
                    "manifest has no packagesDir; select existing directories "
                    "with --packages"
                )
            # Lake serializes quoted names, but uses their unquoted directory name.
            git_directory = kernel / packages_dir / name.removeprefix("«").removesuffix("»")
            if revision(git_directory) != entry["rev"]:
                raise RuntimeError(
                    f"{name} is not at its manifest revision; select the built "
                    "checkout with a path entry in --packages"
                )
            directory = git_directory / (entry.get("subDir") or "")
        else:
            raise RuntimeError(f"unsupported Lake package source: {entry['type']}")
        directory = directory.resolve(strict=True)
        if not directory.is_dir():
            raise RuntimeError(f"package is not a directory: {directory}")
        directories[name] = directory
        # Path overrides prohibit Lake's implicit Git checkout/fetch behavior,
        # including for ordinary invocations using a populated packagesDir.
        local_entries.append({
            key: value for key, value in entry.items()
            if key not in {"url", "rev", "inputRev", "subDir", "dir", "type"}
        } | {"type": "path", "dir": str(directory)})
    return directories, configuration, local_entries


def executable(value: str) -> str:
    # Relative executable paths are relative to the caller, not the kernel cwd.
    return str(Path(value).resolve(strict=True)) if os.sep in value else value


def main(kernel: Path, *, mathematics: Path | None = None,
         packages: Path | None = None, lake: str = "lake", lean: str = "lean",
         additional_imports: tuple[str, ...] = (), output: Path | None = None) -> None:
    contract = Path(__file__).resolve().parent.parent
    target = output or contract / "api/declared-ports.json"
    additional_imports = tuple(dict.fromkeys(additional_imports))
    for module in additional_imports:
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_']*(?:\.[A-Za-z_][A-Za-z0-9_']*)*", module) is None:
            raise ValueError(f"invalid additional dotted module name: {module}")
    declarations = contract / "tools/export_declared_ports.lean"
    addresses = contract / "tools/export_admission_addresses.lean"
    selected, configuration, local_entries = package_selection(kernel, packages)
    selected_mathematics = selected["lean_categories"]
    if mathematics is not None and mathematics != selected_mathematics:
        raise RuntimeError(
            "--mathematics does not match lean_categories in the selected Lake "
            "packages; supply a matching --packages path entry"
        )
    mathematics = selected_mathematics
    protocol = selected["cas_leaf_contracts"]
    sources = {path: source_revision(path, target)
               for path in {kernel, contract, *selected.values()}}
    if sources[protocol] != sources[contract]:
        raise RuntimeError(
            "selected cas_leaf_contracts revision differs from this exporter "
            "checkout; supply the matching built contract with --packages"
        )
    source_digests = {
        path: digest(path) for path in
        [declarations, addresses, kernel / "CasCatalogue/Admission.lean"]
    }
    with tempfile.TemporaryDirectory(prefix="cas-declared-api-") as directory:
        scratch = Path(directory)
        declaration_probe = scratch / declarations.name
        address_probe = scratch / addresses.name
        generated_digests = {}
        for source, probe in [(declarations, declaration_probe), (addresses, address_probe)]:
            content = source.read_text(encoding="utf-8")
            if additional_imports:
                if not content.startswith("module\n"):
                    raise RuntimeError(f"exporter has no module header: {source}")
                imports = "".join(f"import {module}\n" for module in additional_imports)
                content = "module\n" + imports + content.removeprefix("module\n")
            probe.write_text(content, encoding="utf-8")
            generated_digests[probe] = digest(probe)
        local_packages = scratch / "packages.json"
        local_packages.write_text(json.dumps({"version": "1.2.0", "packages": local_entries}))
        command = [lake, f"--packages={local_packages}", "env", lean]
        subprocess.run([*command, str(address_probe)], cwd=kernel,
                       env={**os.environ, "CAS_ADMISSION_ADDRESSES_OUTPUT":
                            str(scratch / "addresses.json")}, check=True)
        provenance = {
            "mathematicsRevision": sources[mathematics],
            "protocolRevision": sources[protocol],
            "exporterSha256": source_digests[declarations],
        }
        # Docstrings are stored in Lean's server-data section. Load that public
        # metadata while keeping ordinary module visibility; default batch imports
        # otherwise silently replace every imported docstring with null.
        subprocess.run([*command, "-DElab.inServer=true", str(declaration_probe)], cwd=kernel,
                       env={**os.environ,
                            "CAS_DECLARED_PORTS_MATH_REVISION": provenance["mathematicsRevision"],
                            "CAS_DECLARED_PORTS_PROTOCOL_REVISION": provenance["protocolRevision"],
                            "CAS_DECLARED_PORTS_EXPORTER_SHA256": provenance["exporterSha256"],
                            "CAS_DECLARED_PORTS_OUTPUT": str(scratch / "declarations.json")},
                       check=True)
        result = json.loads((scratch / "declarations.json").read_text())
        if result["provenance"] != provenance:
            raise RuntimeError("declaration export did not preserve the selected provenance")
        result.update(json.loads((scratch / "addresses.json").read_text()))
        result["provenance"].update({
            "kernelRevision": sources[kernel],
            "admissionSourceSha256": source_digests[kernel / "CasCatalogue/Admission.lean"],
            "addressExporterSha256": source_digests[addresses],
        })
        if additional_imports:
            result["provenance"].update({
                "additionalImports": list(additional_imports),
                "declarationProbeSha256": generated_digests[declaration_probe],
                "addressProbeSha256": generated_digests[address_probe],
            })
        for path, expected in (configuration | source_digests).items():
            if digest(path) != expected:
                raise RuntimeError(f"input changed during export: {path}; rerun export")
        if any(digest(path) != expected for path, expected in generated_digests.items()):
            raise RuntimeError("generated exporter source changed during export; rerun export")
        for path, expected in sources.items():
            if source_revision(path, target) != expected:
                raise RuntimeError(f"source revision changed during export: {path}; rerun export")
        # Publish only complete fresh output; failures leave the prior snapshot intact.
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=target.parent,
                                         prefix=".declared-ports-", delete=False) as output:
            temporary_target = Path(output.name)
            try:
                output.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
                output.close()
                temporary_target.replace(target)
            finally:
                temporary_target.unlink(missing_ok=True)
        print(target)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kernel", type=Path, help="existing, already built kernel checkout")
    parser.add_argument("--mathematics", type=Path,
                        help="existing checkout matching the selected lean_categories package")
    parser.add_argument("--packages", type=Path, help="external Lake package override JSON file")
    parser.add_argument("--import", dest="additional_imports", action="append", default=[],
                        help="already built additional catalogue module; repeat for several modules")
    parser.add_argument("--output", type=Path,
                        help="output snapshot; defaults to this contract's api/declared-ports.json")
    parser.add_argument("--lake", default="lake", help="Lake executable (default: lake)")
    parser.add_argument("--lean", default="lean", help="Lean executable (default: lean in Lake's environment)")
    args = parser.parse_args()
    try:
        main(args.kernel.resolve(strict=True),
             mathematics=args.mathematics.resolve(strict=True) if args.mathematics else None,
             packages=args.packages.resolve(strict=True) if args.packages else None,
             lake=executable(args.lake), lean=executable(args.lean),
             additional_imports=tuple(args.additional_imports),
             output=args.output.resolve() if args.output else None)
    except (OSError, KeyError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"export_api.py: {error}\n")
