# Tasks: Released contract, protocol 2

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/protocol-2.md](contracts/protocol-2.md),
[quickstart.md](quickstart.md).

## Execution order

The unchecked tasks are executed in the order of this file. The first unchecked task is the
active task. `After` names the inputs that a task needs. `Consumer` names the lean-cas-dsl task
that uses the result ("kernel T0nn"). A wait on an unavailable input blocks only its task; work
continues with the next task whose inputs are present, and the waiting task keeps its position.

Tasks T003–T018 are committed on `integration/kernel-v1-20261106` ([plan, source
location](plan.md#source-location)). Each frame task changes the Lean codec, the SDK, the public
document, both protocol peers and the contract test of that frame in one change; a codec without
its test is not complete (constitution RC13).

Format: `- [ ] ID [P?] [Story] description`. **Files**, **Acceptance**, **Consumer** and
**After** follow each task.

## Phase 1: Setup

- [ ] T001 Publish the protocol-2 state that the kernel branch locks. In the checkout
  `/home/dzack/.local/share/docker/volumes/sage-repos/_data/v1-integration-20261106/lean-cas-dsl-leaf-contracts`
  (head `a0417b0`), read the diff of its 14 modified paths and the untracked
  `python/cas_interfaces.py` against this plan; commit them on `integration/kernel-v1-20261106`
  with a body that names what each path does; trash `.tmp/` (copies of the same paths and
  bytecode) after its files are compared with the committed paths; push the branch.
  **Files**: the 14 paths listed by `git status` there, `python/cas_interfaces.py`.
  **Acceptance**: `git ls-remote` shows the branch at a descendant of `a0417b0`; GitHub resolves
  `a0417b0`; the checkout has a clean tree. **Consumer**: kernel T017 (its lock exists).
  **After**: none.
- [ ] T002 Carry the governing documents and this feature to the integration branch: apply the
  commits of `main` that add `.specify/`, `.claude/skills/speckit-*`, the constitution,
  `CONTRIBUTING.md`, the edits of `AGENTS.md` and `README.md`, and `specs/001-released-contract-v2/`.
  **Files**: those paths. **Acceptance**: `git diff main integration/kernel-v1-20261106 --
  .specify/memory AGENTS.md CONTRIBUTING.md specs` shows only lines that the branch's protocol-2
  material requires in `AGENTS.md` and `README.md`. **Consumer**: every later task.
  **After**: T001.

## Phase 2: Foundational

- [ ] T003 Build the tier 1 harness and both protocol peers at negotiation. Add `pytest` as a dev
  dependency (`uv add --dev pytest`); add recipes `setup` (`uv sync --frozen`, `lake build
  cas-peer`) and `test` (`uv run --frozen pytest tests/contract`) to `justfile`, and run `test`
  in `test-push` and in CI after `setup`. Write `peer/Driver.lean` (executable `cas-peer` in
  `lakefile.lean`, importing only `CasContract.Port` and `CasContract.Failure`): `cas-peer run
  SCENARIO -- LEAF_COMMAND` starts the leaf, runs `negotiateV2`, sends each scenario frame and
  compares each reply or outcome, exiting nonzero at the first difference; `cas-peer manifest
  PATH` decodes a manifest. Write `peer/protocol_peer.py` and `peer/leaves.json`: an SDK leaf
  whose replies come from the scenario file given as its argument. Write `tests/conftest.py`,
  which writes `tests/logs/<UTC>-<rev>.log` and appends one record per test to
  `tests/timing/records.jsonl` (research R12).
  **Files**: `pyproject.toml`, `uv.lock`, `justfile`, `.github/workflows/ci.yml`,
  `lakefile.lean`, `peer/Driver.lean`, `peer/protocol_peer.py`, `peer/leaves.json`,
  `peer/README.md`, `tests/conftest.py`, `tests/contract/test_peer.py`, `tests/logs/`,
  `tests/timing/records.jsonl`.
  **Acceptance**: `just setup && just test` runs a test that negotiates between `cas-peer` and
  `tests/leaves/immediate.py` and a test in which `cas-peer` drives `peer/protocol_peer.py`
  through its scenario, writes one log and one timing record per test, and finishes in under five
  minutes (SC-001, SC-002). **Consumer**: kernel T017 (protocol peer for its checks).
  **After**: T002.

## Phase 3: User Story 2 and User Story 1 — the protocol frames

- [ ] T004 [US2] Framing and negotiation (FR-001, FR-002, FR-003; disagreement D1). Delete
  `Ready`, `readyOf`, the `capabilities` field and every v1 frame and argument from
  `CasContract/Port.lean`, `python/cas_port.py` and the documents; keep `ReadyV2`,
  `negotiateV2`, `checkHelloV2Ack`; state the request grammar and monotone request IDs.
  **Files**: `CasContract/Port.lean`, `python/cas_port.py`, `python/cas_session.py`,
  `api/python-sdk.md`, `api/manifest.md`, `api/wire-examples.md`, `tests/contract/test_negotiation.py`,
  `tests/leaves/immediate.py`, `tests/scenarios/negotiation-*.json`.
  **Acceptance**: tests show a complete negotiation; a `ready` frame without `suspend-resume/2`
  gives `unavailable` with `incompatible_protocol` and no request; an extra feature string is
  accepted; an extra field is malformed; `git grep -n "readyOf\|adapter_version\|capabilities"`
  over `CasContract python api` returns nothing. **Consumer**: kernel T017. **After**: T003.
- [ ] T005 [US1] Manifest (FR-004; D2; issue #1). Make `backends`, `registrations`, `args` and
  `preferredRoutes` required, reject every unknown field, keep the nonempty-route rule, and keep
  all-or-none admission of a manifest.
  **Files**: `CasContract/Registration.lean`, `api/manifest.md`, `api/manifest.schema.json`,
  `tests/contract/test_manifest.py`, `tests/scenarios/manifest-*.json`.
  **Acceptance**: `cas-peer manifest` accepts the example of `api/manifest.md`; it rejects a
  field `priority`, a missing `registrations`, an empty `route`, and a manifest whose second
  registration is invalid, naming the field or row. **Consumer**: kernel T017, kernel T028.
  **After**: T004.
- [ ] T006 [US2] Exact references and graph controls (FR-005). Complete the decoders of
  `inputRef`, `resultRef`, `scopeRef`, `$cas.project` and `$cas.apply` and the SDK `Proxy` and
  gateway checks.
  **Files**: `CasContract/Port.lean`, `python/cas_session.py`, `api/kernel-service.md`,
  `api/python-sdk.md`, `tests/contract/test_references.py`, `tests/leaves/references.py`,
  `tests/scenarios/references-*.json`.
  **Acceptance**: tests show that a self, forward or out-of-range `resultRef`, a negative
  `inputRef` index and a `scopeRef` of an expired frame are rejected, and that valid references
  pass unchanged. **Consumer**: kernel T018. **After**: T004.
- [ ] T007 [US2] Replies, exports, export invocation and discard (FR-006, FR-007, FR-008). Fix the
  exact `ok` reply with `exports`; one export entry per new token; the `$cas.invoke_export`
  grammar with the capture prefix and the `published` and `dependent` contexts; invocation-local
  frames; `$cas.discard` and its acknowledgement.
  **Files**: `CasContract/Port.lean`, `python/cas_session.py`, `api/kernel-service.md`,
  `api/python-sdk.md`, `tests/contract/test_replies_exports.py`, `tests/leaves/exports.py`,
  `tests/scenarios/exports-*.json`.
  **Acceptance**: tests show an export with two captures invoked twice with fresh frames; a
  duplicate token entry is malformed; a reply without `exports` is malformed; discard revokes only
  the tokens of its request and a later invocation of a revoked token fails as `unavailable`.
  **Consumer**: kernel T021, kernel T020. **After**: T006.
- [ ] T008 [US2] Failure strata (FR-011; D4; pull request #6). Add `internal` to
  `CasContract/Failure.lean`; map `error`, `unsupported` and malformed replies; rewrite the
  failure table of `api/kernel-service.md` with stratum names; close pull request #6 with a
  comment that names the commit that carries its stratum.
  **Files**: `CasContract/Failure.lean`, `CasContract/Port.lean`, `api/kernel-service.md`,
  `tests/contract/test_failures.py`, `tests/leaves/failing.py`, `tests/scenarios/failures-*.json`.
  **Acceptance**: tests show each of the seven strata reached from a real frame or an empty
  registration set, and `unsupported` naming a different `op` is malformed.
  **Consumer**: kernel T027. **After**: T007.
- [ ] T009 [US1] Deferred programs (FR-009; D5). State and decode `deferredData` with backward
  references, reject a nested literal `deferredData`, and state that a child with no eligible
  realization gives the parent the `noImplementation` outcome naming the child operation.
  **Files**: `CasContract/Port.lean`, `python/cas_port.py`, `api/deferred.schema.json`,
  `api/kernel-service.md`, `tests/contract/test_deferred.py`, `tests/leaves/deferred.py`,
  `tests/scenarios/deferred-*.json`.
  **Acceptance**: tests show a two-node program with `resultRef(0)` in the second call accepted,
  and a nested `deferredData` and a forward reference rejected. **Consumer**: kernel T022.
  **After**: T008.
- [ ] T010 [US1] Adaptive suspension and the `noImplementation` slot (FR-010; D6; research R5).
  Add `cas_session.NoImplementation`, send it to the generator at its slot, reject a leaf reply
  that contains the constructor `noImplementation` before it is written, admit the constructor in
  the Lean decoder only in `$cas.resume` `results`, and keep one-use tokens and repeated
  suspension.
  **Files**: `CasContract/Port.lean`, `python/cas_session.py`, `api/python-sdk.md`,
  `api/kernel-service.md`, `tests/contract/test_suspension.py`, `tests/leaves/suspending.py`,
  `tests/scenarios/suspension-*.json`.
  **Acceptance**: tests show a generator that suspends with two children and receives a proxy and
  a `NoImplementation("op.x","in.x")`, then suspends again with a new token and returns; a second
  resume of a consumed token is malformed; an empty child group is malformed; a reply containing
  `noImplementation` raises in the SDK and no frame is written. **Consumer**: kernel T023.
  **After**: T009.
- [ ] T011 [US2] Decision replies (FR-012; D14; research R6). Add the `unknown` status, the
  `cas_session.Unknown` exception and its mapping to `unavailable` with reason `unknown`; state that
  a predicate's value at $\Omega$ is a JSON boolean.
  **Files**: `CasContract/Port.lean`, `python/cas_session.py`, `api/python-sdk.md`,
  `api/kernel-service.md`, `tests/contract/test_decision.py`, `tests/leaves/predicate.py`,
  `tests/scenarios/decision-*.json`.
  **Acceptance**: tests show `true`, `false` and `unknown` replies decoded to two values and one
  `unavailable`; `unknown` on a request whose scenario result role is not $\Omega$ is malformed.
  **Consumer**: kernel T113. **After**: T010.
- [ ] T012 [US1] Routine observations and SDK logging (FR-013, FR-023). Keep
  `routine-observations/1` and `invoke_routine`; add the standard-error logger of every frame,
  handler, export, suspension, resume and disposal.
  **Files**: `python/cas_session.py`, `api/python-sdk.md`, `tests/contract/test_routines.py`.
  **Acceptance**: tests show a negotiated reply with one `entrypoint` and one `delegated` record,
  a base hello with no `routines` field, and one log line per frame in the run log.
  **Consumer**: kernel T100. **After**: T011.
- [ ] T013 [US1] Public documents (FR-017, FR-018, FR-019; D3, D7–D11). Delete the legacy recipe
  framing, the raw-receiver permission and the three legacy wire forms; add `exports` to every
  example reply; delete the nearest-binding rule and link C6 and FR-004; remove the greatest
  common divisor condition from the scalar-literal admission rule; replace "producer receipt" by
  the kernel's retained occurrence of the executed action; replace restated catalogue mathematics
  by links to generated rows; state FR-017 and FR-018 with one example each.
  **Files**: `api/kernel-service.md`, `api/README.md`, `api/wire-examples.md`, `api/manifest.md`.
  **Acceptance**: SC-004 holds; each example frame in these documents is accepted by `cas-peer`
  when a scenario replays it (`tests/contract/test_document_examples.py`).
  **Consumer**: kernel T028, kernel T061, kernel T042. **After**: T012.

## Phase 4: User Story 1 — the generated category interface

- [ ] T014 [US1] Exporter: category view and structural flag (FR-014, FR-015; D12, D13; research
  R8, R9). Complete `categoryInterfaces` with object and morphism constructors, operations at
  their domains, immediate functor actions and dependencies; write `structural` on each functor
  row and functor action; regenerate with `just export-api` against the built kernel branch and
  commit the unchanged output.
  **Files**: `tools/export_declared_ports.lean`, `tools/export_admission_addresses.lean`,
  `tools/export_api.py`, `api/README.md`; generated `api/declared-ports.json`,
  `api/extension-ports.json`.
  **Acceptance**: SC-005; `categoryInterfaces` has an entry for `cat.sets` with
  `obj.sets.fin`, `mor.sets.fin_rev` and `mor.sets.equality`; the provenance names the locked
  revisions. **Consumer**: kernel T028; computational milestone order (kernel plan).
  **After**: T013.
- [ ] T015 [US1] SDK category helpers (FR-016, FR-024; D12). Complete `cas_interfaces.load_interfaces`
  with category, constructor, call and result access, explicit dependent descriptors and a
  category index built on first query; write `tests/leaves/sets_category.py`, an implementation of
  `cat.sets` operations that builds every request and reply with these helpers and returns opaque
  scenario data.
  **Files**: `python/cas_interfaces.py`, `api/python-sdk.md`, `tests/contract/test_interfaces.py`,
  `tests/leaves/sets_category.py`, `tests/scenarios/sets-category.json`.
  **Acceptance**: the quickstart User Story 1 command passes; a method request at a category
  inside a route carries the receiver, the residual descriptors and the method functor (FR-017);
  a map request carries both image endpoints (FR-018); loading the interface takes under 0.5 s
  and builds no category entry before the first query (timing record). **Consumer**: kernel T028,
  kernel T104. **After**: T014.
- [ ] T016 [US1] Author guidance (FR-021; D16). Index in `api/README.md` every document, generated
  file, SDK module and setup command that a leaf author needs; state in `README.md` and
  `AGENTS.md` the category implementation as the unit, registrations as ports, the leaf's control
  logic (kernel C22), permitted private reuse, and the absence of leaf mathematical, proof and
  acceptance authority; set the ownership row of `lean-cas-dsl-leaves` to depend on this contract.
  **Files**: `api/README.md`, `README.md`, `AGENTS.md`. **Acceptance**: every file that a test
  leaf imports or reads is linked from `api/README.md`. **Consumer**: kernel T028, kernel T104.
  **After**: T015.
- [ ] T017 [US1] Language interface and help (research R10). Extend `tools/export_api.py` to run
  `#cas_export_interface` of the kernel and write `api/language-interface.json` and
  `api/language-help.md`, including data-only and preferred-route interfaces; link them from
  `api/kernel-service.md` and `api/README.md`.
  **Files**: `tools/export_api.py`, `api/kernel-service.md`, `api/README.md`; generated
  `api/language-interface.json`, `api/language-help.md`. **Acceptance**: the two files are produced
  by one `just export-api` run and contain no path outside the public catalogue and contract.
  **Consumer**: kernel T101. **After**: T016; kernel T097–T100.
- [ ] T018 [US1] Public-only run (SC-003). In a fresh clone of the integration branch at the T017
  commit, on a host path with no lean-cas-dsl checkout, run the quickstart.
  **Files**: `specs/001-released-contract-v2/quickstart.md` when a command differs.
  **Acceptance**: every quickstart command passes; the run log and timing records are committed.
  **Consumer**: kernel T104. **After**: T017.

## Phase 5: Releases

- [ ] T019 Release `v2.0.0` at kernel F (FR-022; research R13). Run `just export-api` against the
  built kernel branch at F, commit the unchanged output, set `pyproject.toml` version `2.0.0`, run
  tier 1, tag `v2.0.0` and push the branch and tag.
  **Files**: generated `api/*.json`, `api/language-help.md`, `pyproject.toml`, `uv.lock`.
  **Acceptance**: the kernel branch's lake manifest names the tagged commit (SC-006, first part).
  **Consumer**: kernel T028 (closure at F), kernel T104. **After**: T018; kernel T100, T101.
- [ ] T020 Merge into `main` and release `v2.0.1` at kernel T105 (FR-022). Merge the integration
  branch into `main`; keep `lean-toolchain` and the lean-categories requirement of `main`; run
  `lake update`; build every module and `cas-peer`; run tier 1; run `just export-api` against the
  kernel ported by #90 and commit the unchanged output; tag `v2.0.1`; push; close pull request #11
  with a comment that names the merge commit.
  **Files**: `lean-toolchain`, `lakefile.lean`, `lake-manifest.json`, generated `api/*.json`,
  `api/language-help.md`. **Acceptance**: SC-006 second part; tier 1 passes on `main`.
  **Consumer**: kernel T105. **After**: T019; kernel #90 port.

## Dependencies

| Task | After |
| --- | --- |
| T001 | — |
| T002 | T001 |
| T003 | T002 |
| T004–T013 | each the previous task |
| T014 | T013 |
| T015 | T014 |
| T016 | T015 |
| T017 | T016; kernel T097–T100 |
| T018 | T017 |
| T019 | T018; kernel T100, T101 |
| T020 | T019; kernel #90 port in kernel T105 |

## Kernel consumers

| Kernel task | Tasks here |
| --- | --- |
| T017 | T001, T003, T004, T005 |
| T018 | T006 |
| T020 | T007 |
| T021 | T007 |
| T022 | T009 |
| T023 | T010 |
| T027 | T008 |
| T028 | T005, T013, T014, T015, T016, T019 |
| T042, T061 | T013, T015 |
| T100 | T012 |
| T101 | T017 |
| T104 | T015, T016, T018, T019 |
| T105 | T020 |
| T113 | T011 |
