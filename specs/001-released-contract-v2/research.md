# Research: Released contract, protocol 2

Each entry states a decision, its source and its reason. Source state read on 2026-11-25:
this repository `main` `ef3771d`, integration branch head `dcb9a15` and local commit `a0417b0`;
the local worktree `v1-integration-20261106/lean-cas-dsl-leaf-contracts` (14 modified paths and
the untracked `python/cas_interfaces.py`); lean-cas-dsl `main` and its feature
`001-categorical-research-language`.

## R1. Where the work lands

**Decision**: tasks T003–T018 and T021 commit on `integration/kernel-v1-20261106` (Lean `v4.33.0`); T019
releases `v2.0.0` there at kernel F; T020 merges into `main` with the kernel port of #90 and
releases `v2.0.1` from `main`.
**Source**: kernel `AGENTS.md`, "Source location"; kernel T105 (#90 port inside T105).
**Reason**: the consuming kernel tasks run on the kernel branch, which builds on Lean `v4.33.0`
and requires this package through Lake. A `main` revision on the research-image toolchain does
not build there.

## R2. One protocol

**Decision**: `cas-computation/2` exactly as in the runtime contract §3–§7. The v1 `Ready`
structure, `readyOf`, `capabilities`, `adapter_version` and the v1 `serve` signature are deleted.
**Source**: runtime contract §3 ("no automatic v1 downgrade"); constitution RC8.

## R3. Routine observations

**Decision**: keep the optional feature `routine-observations/1` of `a0417b0` unchanged.
**Source**: kernel T100 (the invoked routine as inert retained data through the SDK).

## R4. Manifest strictness

**Decision**: `backends`, `registrations`, and in each registration `preferredRoutes`, are
required arrays; every unknown field is malformed; a preferred route has a nonempty `route`.
**Source**: constitution RC8; runtime contract §3 (no field outside the grammar gains authority);
the decoder of `a0417b0` (rejects an empty route).
**Reason**: an ignored field such as `priority` hides an author's error; a default hides a
missing declaration.

## R5. The no-implementation slot in the SDK

**Decision**: `cas_session.NoImplementation` is a frozen value with `operation` and `input`. The
SDK sends it to the generator at the slot position in place of a `Proxy`. Before a reply is
written, the SDK walks its JSON and raises `ValueError` at any object whose `ctor` is
`noImplementation`. The Lean decoder admits that constructor only in the `results` of
`$cas.resume`.
**Source**: runtime contract §6; kernel T023; kernel C22.

## R6. Decision replies

**Decision**: a decision request is a property request or a request of a morphism into $\Omega$
(`obj.sets.truth_values`). The value of its reply is an `Option Bool` packet: `some true`, `some
false`, or `none` when the leaf cannot establish the answer. The kernel reports `none` as the
outcome `unknown`, distinct from every stratum; `assert P = unknown` holds on it. No `status`
value is added. In Python a handler returns `cas_session.decision(True)`, `decision(False)` or
`decision(None)`.
**Source**: kernel C6 (unknown is an inability, not a third truth value) and C13 (outcomes stay
distinct); kernel `tasks.md`, rows T113 and T027 of "Fallbacks and merged outcomes" ("A decision
with three values, for predicates and properties, with its own outcome and its source form"), the
public-path test of T113 ("`assert P = unknown` holds when the provider answers that it cannot
decide") and the note under "Upstream inputs recorded as missing" ("The three-valued reply of a
decision is a shape of the reply in the contract and the kernel"); kernel runtime contract §8
(the leaf statuses are `ok`, `suspended`, `unsupported` and `error`; an unknown status is
malformed); the kernel branch at `6808bc0` admits a property reply as the `Option Bool` packet
(`CasRuntime/Literal.lean:156-177`, `CasRuntime/PreparedRequest.lean:709-714`).
**Rejected**: a `status:"unknown"` frame mapped to `unavailable`. It adds a status that runtime
§8 does not have, and it merges the inability to establish an answer with process loss and engine
failure, which C13 keeps distinct.

## R7. Failure strata

**Decision**: seven strata: the six of `CasContract/Failure.lean` and `internal`, carried from
pull request #6 (`contract/semantic-ambiguity`). The failure table of `api/kernel-service.md`
uses the stratum names.
**Source**: runtime contract §8; constitution RC7.

## R8. Category-indexed interface

**Decision**: keep the design of the local worktree: the generated key `categoryInterfaces`
(`categoryInterfaceVersion: 1`) groups complete rows by declared owner; polymorphic families
stay in `genericEntries`; `categoryConstructors` stays separate. `cas_interfaces.load_interfaces`
derives category, constructor, call and result helpers from that JSON at load time. No second
code generator exists.
**Source**: kernel T028 and FR-025; constitution RC3; the existing unpublished work of the local
worktree (`api/README.md` diff, `python/cas_interfaces.py`).
**Reason**: a load-time view of the generated file follows every regeneration with no step
between them.

## R9. Structural flag

**Decision**: `tools/export_declared_ports.lean` writes `structural` (boolean) on each row of the
key `functors` and on each immediate functor action of a category interface, read from the
field `structural` of the lean-categories functor row.
**Source**: research record "scaffolding" (field at `LeanCategories/Catalogue/Registry/Entry.lean:519`;
exported only inside `registeredMetadata` by `tools/export_declared_ports.lean:103-115`); kernel
plan, "Computational milestones" (order by structural functors).

## R10. T101 language interface and help

**Decision**: `tools/export_api.py` also runs the kernel command `#cas_export_interface` of
`CasTools/InterfaceExport.lean` and writes its outputs to `api/language-interface.json` and
`api/language-help.md`; `api/kernel-service.md` links them.
**Source**: kernel T101 (publish the generated language interface and help through
`CasTools/InterfaceExport.lean` and `api/kernel-service.md`); the command
`#cas_export_interface JSON help HELP` (`CasTools/InterfaceExport.lean:13-18` on the kernel
branch), which writes one JSON file and one help file at the paths that its caller names;
constitution RC3 (a generated file is committed unchanged, so it is a file of its own that
`api/kernel-service.md` links, not text inside that hand-written document).

## R11. Protocol peer

**Decision**: two peers. `cas-peer` (Lean, `peer/Driver.lean`) drives a leaf process from a
scenario with the codecs of `CasContract.Port`; it tests the SDK and the example leaves.
`peer/protocol_peer.py` (SDK) answers a kernel from a scenario file named in `peer/leaves.json`;
kernel engineers use it for kernel T017–T023 and T027. Scenario values are opaque JSON.
**Source**: kernel C22 ("a protocol peer or an empty set of registrations"); constitution RC13.

## R12. Test harness, logs and timing

**Decision**: `pytest` as a dev dependency in `pyproject.toml`, run by
`uv run --frozen pytest tests/contract`. `tests/conftest.py` writes one log per run to
`tests/logs/<UTC timestamp>-<short revision>.log` and appends one JSON line per test to
`tests/timing/records.jsonl` with `run`, `revision`, `environment` (Python, Lean, host),
`input` (test and scenario), and `setup_s`, `call_s`, `teardown_s`. Both are committed.
**Source**: constitution RC17, RC18; kernel FR-043.

## R13. Release

**Decision**: `v2.0.0` is the integration-branch commit of T019 after its regeneration;
`pyproject.toml` version `2.0.0`. `v2.0.1` is the `main` commit of T020; it changes pins and
generated provenance, not the protocol.
**Source**: constitution RC10 (a release is cut on the branch whose toolchain its consumer
builds on; the delivery release is on `main`); kernel T028 ("the release that leaf work consumes
... at F") and plan, "Computational milestones" (the contract is released at F); kernel T105 (the
delivery tuple on the image toolchain, with #90); kernel `AGENTS.md`, "Source location" (the
kernel branch builds on Lean `v4.33.0` until T105); protocol major version 2 (runtime contract
§3, `cas-computation/2`). The patch number of `v2.0.1` records that the protocol is unchanged.

## R14. Where tier 1 runs

**Decision**: `just test` runs tier 1; `just test-push` runs it before a push, after the static
scans; CI runs it after `just setup`.
**Source**: constitution RC15 (commit checks fast; long runs at milestones).

## R15. `CasContract` builds without Mathlib

**Decision**: the protocol library, the peer `cas-peer` and the SDK need no Mathlib build. The
modules `CasContract/Port.lean`, `Registration.lean` and `Failure.lean` import only Lean core
(`Lean.Data.Json`, `Lean.Exception`) and each other; `AxiomAudit.lean` imports `CasContract` and
Lean core. The package's `require lean_categories` (`lakefile.lean`) serves only the exporter
adapters `tools/export_declared_ports.lean` and `tools/export_admission_addresses.lean`, which
import `LeanCategories.Catalogue` and run in a built kernel environment (R10). So `lake build
CasContract` and `lake build cas-peer` compile no Mathlib module; Lake still resolves
`lean_categories` and its Mathlib in the workspace manifest.
**Source**: the imports of those files and `lakefile.lean` on `main` and on
`integration/kernel-v1-20261106`, read on 2026-11-25.

## R16. The kernel has its own protocol peers

**Decision**: the kernel checks of kernel T017–T023 and T027 may use the kernel's own protocol
peers or `peer/protocol_peer.py` of this repository; both are protocol peers under kernel C22.
This repository's peers are the counterpart of its own contract tests and a published peer for
kernel engineers; they are not a precondition of a kernel task other than through the frames of
T003–T013.
**Source**: the kernel branch at `6808bc0` holds protocol peers in `scripts/probes/`
(`protocol_v2_peer.py`, `kernel_session_peer.py`, `kernel_predicate_peer.py`,
`kernel_suspension_peer.py` and others); kernel `tasks.md`, "Public-path tests to add" (the peers
in `scripts/probes/` have no fault mode yet) and T127 (the test peers write their own logs);
kernel C22 ("a protocol peer or an empty set of registrations").

## R17. Value forms of category data

**Decision**: FR-025 declares the forms of issue #14 from the declarations of lean-categories and
the protocol grammar. A declared object whose declaration is a native inductive type uses its
native constructor packets, as the `Option Bool` packet of R6 does. Every other value is a
registered morphism or inclusion row applied to registered points. Four kinds wait for an
upstream declaration that has its issue and its task: subsets (#191, lean-categories T013),
binders (#190, T027), product legs (#187, T031) and element operations (#193, T005). No form needs
a lean-categories declaration without an issue.
**Source**: issue #14 (evidence with the lean-categories rows at `3bc32d03`); constitution RC1,
RC3, RC8; kernel spec FR-125; lean-cas-dsl-leaves `DEFECTS.md`, last three sections.

