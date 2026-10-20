"""Generate released API documentation using the kernel's latest-main probe surface.

Usage: just export-api /absolute/path/to/lean-cas-dsl
The supplied checkout must have its current source dependencies built. Both Lean
exporters are read-only; the existing probe recipe resolves latest main first.
"""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def revision(path: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(kernel: Path) -> None:
    contract = Path(__file__).resolve().parent.parent
    declarations = contract / "tools/export_declared_ports.lean"
    addresses = contract / "tools/export_admission_addresses.lean"
    subprocess.run(["just", "focus", "CasCatalogue.Admission"], cwd=kernel, check=True)
    kernel_revision = revision(kernel)
    admission_digest = digest(kernel / "CasCatalogue/Admission.lean")
    with tempfile.TemporaryDirectory(prefix="cas-declared-api-") as directory:
        scratch = Path(directory)
        declaration_probe = scratch / declarations.name
        address_probe = scratch / addresses.name
        declaration_probe.write_bytes(declarations.read_bytes())
        address_probe.write_bytes(addresses.read_bytes())
        # The first probe refreshes own-organisation dependencies through the
        # existing kernel recipe. Read the resolved snapshot after that refresh.
        subprocess.run(["just", "probe", str(address_probe)], cwd=kernel,
                       env={**os.environ, "CAS_ADMISSION_ADDRESSES_OUTPUT":
                            str(scratch / "addresses.json")}, check=True)
        manifest = json.loads((kernel / "lake-manifest.json").read_text())
        mathematics = (kernel / manifest["packagesDir"] / "lean_categories").resolve()
        provenance = {
            "CAS_DECLARED_PORTS_MATH_REVISION": revision(mathematics),
            "CAS_DECLARED_PORTS_PROTOCOL_REVISION": revision(contract),
            "CAS_DECLARED_PORTS_EXPORTER_SHA256": digest(declaration_probe),
            "CAS_DECLARED_PORTS_OUTPUT": str(scratch / "declarations.json"),
        }
        subprocess.run(["just", "probe", str(declaration_probe)], cwd=kernel,
                       env={**os.environ, **provenance}, check=True)
        if digest(declarations) != digest(declaration_probe) or digest(addresses) != digest(address_probe):
            raise RuntimeError("exporter source changed during export; rerun export")
        if revision(kernel) != kernel_revision or digest(kernel / "CasCatalogue/Admission.lean") != admission_digest:
            raise RuntimeError("kernel admission source changed during export; rerun export")
        if revision(mathematics) != provenance["CAS_DECLARED_PORTS_MATH_REVISION"]:
            raise RuntimeError("mathematical input changed between export probes; rerun export")
        result = json.loads((scratch / "declarations.json").read_text())
        result.update(json.loads((scratch / "addresses.json").read_text()))
        result["provenance"].update({
            "kernelRevision": kernel_revision,
            "admissionSourceSha256": admission_digest,
            "addressExporterSha256": digest(address_probe),
        })
        target = contract / "api/declared-ports.json"
        target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(target)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]).resolve(strict=True))
