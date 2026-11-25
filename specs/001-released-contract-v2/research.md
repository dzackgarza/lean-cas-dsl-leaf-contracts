# Research: Released contract, protocol 2

Each entry states a decision, its source and its reason. Source state read on 2026-11-25:
this repository `main` `ef3771d`, integration branch head `dcb9a15` and local commit `a0417b0`;
the local worktree `v1-integration-20261106/lean-cas-dsl-leaf-contracts` (14 modified paths and
the untracked `python/cas_interfaces.py`); lean-cas-dsl `main` and its feature
`001-categorical-research-language`.

## R1. Where the work lands

**Decision**: tasks T003–T018 commit on `integration/kernel-v1-20261106` (Lean `v4.33.0`); T019
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

**Decision**: an operation whose result role is $\Omega$ (`obj.sets.truth_values`) answers
`status:"ok"` with a JSON boolean `value`. Inability to establish the answer is
`{"request_id":n,"status":"unknown","op":"<op>","reason":"<text>"}`; the kernel maps it to
`unavailable` with reason `unknown`. `unknown` on another result role is malformed. In Python a
handler raises `cas_session.Unknown(reason)`.
**Source**: kernel C6 (unknown is an inability, not a truth value); kernel T113; research record
"7e. A three-valued decision" ($\Omega=\mathrm{Prop}$, no upstream input); the JSON boolean
convention of `api/wire-examples.md:272`.
**Reason**: the stratum list of runtime §8 is closed; `unknown` is an unavailable result, not a
new stratum.

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
**Source**: kernel T101; the command `#cas_export_interface JSON help HELP` on the kernel branch.

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
**Source**: constitution RC10; kernel T028 ("the release that leaf work consumes ... at F");
kernel T105; protocol major version 2.

## R14. Where tier 1 runs

**Decision**: `just test` runs tier 1; `just test-push` runs it before a push, after the static
scans; CI runs it after `just setup`.
**Source**: constitution RC15 (commit checks fast; long runs at milestones).
