# Feature Specification: Released contract, protocol 2

**Feature Branch**: `001-released-contract-v2` (work is committed on `main`)
**Created**: 2026-11-25
**Status**: Planned
**Governing text**: [constitution](../../.specify/memory/constitution.md) (RC1–RC20); the
[kernel constitution][KC] v4.0.1; the kernel's [runtime contract][KR], which is the
kernel-side design of this contract and governs where an `api/` document disagrees.

**Input**: everything that the kernel tasks T017, T018, T020, T021, T022, T023, T027, T028,
T100, T101 and T113 of lean-cas-dsl require of this repository, and what a leaf author needs
for the computational milestones (kernel T200 to T224), released as `v2.0.0` at kernel F and on
`main` as `v2.0.1` at kernel T105.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — A leaf author writes a category implementation from this repository alone (Priority: P1)

A public-only author receives this repository, the accepted catalogue and backend resources.
The author reads the category interface of `cat.sets`, writes object and morphism constructors,
operations at their actual domains and immediate functor actions as glue over an established
engine, registers them in `leaves.json`, and runs them through the SDK. The author asks the
kernel for an operation of another category and receives either its result or the
no-implementation outcome, and continues under its own control logic.

**Why this priority**: every computed answer of the programme comes from category
implementations (kernel C22, C23). The computational milestones start from this release.

**Independent Test**: from a clean checkout of a release commit, with no kernel source on the
host, the quickstart example implementation of a category starts, negotiates, answers a
request, returns a deferred program, suspends, resumes with one result slot and one
`noImplementation` slot, and exports a callable, against the protocol peer.

**Acceptance Scenarios**:

1. **Given** the generated interface, **When** the author calls
   `cas_interfaces.load_interfaces(...).category("cat.sets")`, **Then** it returns the object and
   morphism constructors, operations at their actual domains, immediate functor actions with
   their structural flags, and complete dependent signatures of `cat.sets`, without reading any
   kernel file.
2. **Given** a generator handler that suspends with two child calls, **When** the peer resumes
   it with a result for the first child and `{"ctor":"noImplementation","args":["<op>","<input>"]}`
   for the second, **Then** the generator receives a proxy and a `NoImplementation` value that
   names that operation and input, and its next reply is admitted.
3. **Given** a handler that returns a reply containing the constructor `noImplementation`,
   **When** the SDK writes the reply, **Then** the SDK raises before writing and no frame is sent.
4. **Given** a manifest with a field `priority`, a missing `registrations` array or a preferred
   route with an empty route, **When** it is decoded, **Then** decoding fails as malformed and
   names the field.
5. **Given** a registration at a category inside the route of an inherited method, **When** it
   receives a method request, **Then** the request carries the receiver, one descriptor for each
   residual action and then the method-functor descriptor.
6. **Given** a registration of a functor's map action, **When** it receives a request, **Then**
   the request carries the complete source arrow and both already computed image endpoints.

---

### User Story 2 — A kernel engineer checks the kernel against the published contract (Priority: P1)

A kernel engineer checks framing, negotiation, references, export invocation, reply admission,
deferred programs, suspension, discard and outcome mapping of the kernel (kernel T017–T023,
T027) against the published contract. The check uses the protocol peer of this repository or an
empty manifest, and no computed mathematical value (kernel C22).

**Why this priority**: kernel readiness F requires every advertised generic feature to work;
negotiation alone proves none of them (runtime contract §3).

**Independent Test**: the kernel's transport starts `peer/protocol_peer.py` with a scenario file,
and every frame that the kernel sends is compared with the frame that the scenario prescribes.

**Acceptance Scenarios**:

1. **Given** a peer whose `ready` frame lacks `suspend-resume/2`, **When** the kernel negotiates,
   **Then** the outcome is `unavailable` with reason `incompatible_protocol` and no request is sent.
2. **Given** a scenario that replies `suspended` with two children, **When** the kernel resumes,
   **Then** the `$cas.resume` frame has capture slots `0..c-1` and result slots `c..c+n-1` in
   child order, and a child with no eligible realization holds the `noImplementation` slot.
3. **Given** a scenario reply that omits a mandatory field, **When** the kernel admits it,
   **Then** the outcome is `malformed` and nothing of the reply is staged.
4. **Given** a decision request (a predicate or a property), **When** the peer replies with the
   value `some true`, `some false` or `none` of an `Option Bool` packet, **Then** the kernel
   retains a truth value for the first two and the outcome `unknown` for the third, and no stratum
   for any of the three.

---

### User Story 3 — An independent assessor replaces a provider (Priority: P2)

An assessor removes one registration of an operation and installs another provider for the same
operation and input form, on an unchanged question and consumer. The assessor needs the
contract to keep each outcome distinct and to give no route or priority to either provider.

**Why this priority**: provider replacement trials follow functionality (kernel C21), but they
consume this contract unchanged (kernel C12).

**Independent Test**: two manifests that differ only in the backend of one registration are
both admitted; a manifest with both registrations is admitted and the selection outcome is
`ambiguousRealization`.

**Acceptance Scenarios**:

1. **Given** two registrations of one operation at one input form, **When** both are admitted,
   **Then** the contract defines no order, priority or retry between them.
2. **Given** a provider that answers well-framed wrong data, **When** the reply is admitted,
   **Then** no stratum names it wrong; the data is retained for independent assessment.

### Edge Cases

| Situation | Required behaviour | Source |
| --- | --- | --- |
| A frame with extra control field | `malformed` | Runtime contract §3, §8 |
| A `ready` frame with an extra feature string | Accepted; the string is ignored | Runtime contract §3 |
| A second resume of one continuation | `malformed`; the token is one-use | Runtime contract §6 |
| An empty child group in a suspension | `malformed` | Runtime contract §6 |
| A `resultRef` to itself or a later node | `malformed` | `api/kernel-service.md` |
| A child of a `deferredData` program with no realization | The parent request has `noImplementation` naming the child operation | Runtime contract §6; kernel T022 |
| A child failure other than no implementation, or child loss | The suspension chain retires; no substitute result | Runtime contract §6 |
| A decision request answered by a value that is not an `Option Bool` packet | `malformed` | FR-012 |
| A `status` other than `ok`, `suspended`, `unsupported` or `error` | `malformed` | Runtime contract §8 |
| A lost reply after a resume is sent | The resume right is consumed; no resend | Runtime contract §6, §7 |

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 — Framing.** A frame MUST be the ASCII decimal UTF-8 byte length of its payload, a
  newline, and one JSON value. Standard output of a leaf carries frames only; standard error is
  diagnostic. *Kernel consumer: T017.*
- **FR-002 — Negotiation.** A leaf MUST first write exactly
  `{"op":"ready","protocol":2,"contract":"cas-computation/2","features":[...],"backend":...,"backend_version":...}`
  with the features `scoped-values/2`, `deferred/2`, `suspend-resume/2` and
  `export-capture-frames/2`. Extra feature strings are ignored; extra fields are malformed. The
  kernel sends `{"op":"hello","protocol":2,"contract":"cas-computation/2"}` and the leaf
  acknowledges with the same fields and `"status":"ok"`. Before the acknowledgement only
  negotiation and shutdown occur. A missing or incompatible negotiation is `unavailable` with
  reason `incompatible_protocol`. No v1 frame, field or downgrade exists. *T017.*
- **FR-003 — Requests.** An ordinary request MUST have exactly `protocol`, `request_id`, `op`,
  `input`, `args` and `scope_id`. Request IDs are nonnegative, increase on a connection and are
  never reused. `op` and `input` are admitted published addresses; `args` keeps the complete
  operation-specific grammar. *T017.*
- **FR-004 — Manifest.** `leaves.json` MUST have exactly the root arrays `backends` and
  `registrations`. A backend has `name`, `command` and `args`; a registration has `operation`,
  `input`, `backend` and `preferredRoutes`. Every field is required; an unknown field is
  malformed. A preferred route has `name`, `receiver` and a nonempty `route` of structural edge
  labels; a route that is not a surviving route rejects the registration; conflicting admitted
  preferences are not ranked (constitution RC6). *T017, T028.*
- **FR-005 — Exact references.** `inputRef(path)` addresses the original request at a complete
  prepared role by string fields and nonnegative indices. `resultRef(index)` addresses an earlier
  completed node of the same deferred group, never itself, a later node or an out-of-range node.
  `scopeRef(slot)` addresses a kernel-issued slot of the current invocation or resume scope. The
  graph controls are `$cas.project` with `value`, `field` and `$cas.apply` with `value`,
  `arguments`. No raw foreign token crosses a scope. *T018.*
- **FR-006 — Replies and whole-response admission.** A successful immediate reply MUST have
  exactly `request_id`, `status:"ok"`, `value` and `exports`. Each newly introduced token occurs
  once in `exports` with its ordered captures. The kernel validates the entire joint result,
  scopes, exports and owners before it stages any field; an omitted mandatory field is
  `malformed`, never a default or an inferred choice. Structural admission establishes no law
  and no correctness. *T021.*
- **FR-007 — Export invocation.** `$cas.invoke_export` MUST have exactly `protocol`,
  `request_id`, `op`, `scope_id`, `token`, `captures` and `context`. `captures` is
  `scopeRef(0)…scopeRef(c−1)` in declared capture order. A `published` context has `operation`,
  `input` and the seven-field `apply` packet with the token at its callable position; a
  `dependent` context has `prepared_role`, `parameters`, `bindings`, `arguments`,
  `argument_layouts` and `result_layout`. The SDK binds captures in an invocation-local frame that
  expires on return, error or suspension. *T020.*
- **FR-008 — Discard.** `$cas.discard` MUST have exactly `protocol`, `request_id`, `op` and
  `discard_request_id`; the acknowledgement is `{"request_id":…,"status":"ok","disposed":true}`.
  It revokes only the leases and continuations that the discarded request introduced. *T021.*
- **FR-009 — Deferred programs.** A leaf MAY return `{"ctor":"deferredData","args":[calls,template]}`
  as the `value` of an ordinary reply. Each call has exactly `op`, `input`, `args`, or is a graph
  control. References are backward only. A literal nested `deferredData` is malformed. A child
  whose operation has no eligible realization gives the parent request the `noImplementation`
  outcome that names the child operation. *T022.*
- **FR-010 — Adaptive suspension and resume.** A suspended reply MUST have exactly `request_id`,
  `status:"suspended"`, `continuation`, `captures`, `calls` (finite, nonempty) and `exports`. The
  resume has exactly `protocol`, `request_id`, `op:"$cas.resume"`, `continuation`, `scope_id`,
  `captures` and `results`; capture `i` is slot `i`, child `j` is slot `c+j`. A child with no
  eligible realization holds `{"ctor":"noImplementation","args":["<op>","<input>"]}` with the
  child's `op` and `input`; the chain continues. `noImplementation` is reserved: only the kernel
  writes it, and a leaf reply that contains it is `malformed`. The SDK sends the generator a
  `cas_session.NoImplementation(operation, input)` value at that position. A continuation token
  is one-use. *T023.*
- **FR-011 — Failure strata.** `CasContract.Failure` MUST have exactly the strata `invalid`,
  `semanticAmbiguity`, `noImplementation`, `ambiguousRealization`, `unavailable`, `malformed` and
  `internal`. A leaf `status:"error"` with `kind` and `message` maps to `unavailable`;
  `status:"unsupported"` with the exact `op` maps to `noImplementation` for that operation; an
  untagged defect of an implementation is `internal`; unknown or mismatched statuses, fields,
  scopes or captures are `malformed`. *T027.*
- **FR-012 — Decision replies.** A decision request is a property request, or a request of a
  morphism whose target is the truth-value object $\Omega$ (`obj.sets.truth_values`). The value
  that its reply supplies (directly, or through a deferred program or a resumed suspension) MUST
  be an `Option Bool` packet:
  `{"ctor":"some","args":[{"ctor":"true","args":[]}]}`,
  `{"ctor":"some","args":[{"ctor":"false","args":[]}]}`, or `{"ctor":"none","args":[]}` when the
  leaf cannot establish the answer. The kernel maps `none` to the outcome `unknown`, which is not a
  third truth value (kernel C6) and is distinct from every stratum (kernel C13), so that
  `assert P = unknown` holds on it. No `status` value is added. Any other value of a decision
  reply is `malformed`. *T113, T027.*
- **FR-013 — Routine observations.** The optional feature `routine-observations/1` MUST keep the
  exact grammar of `api/python-sdk.md`: the kernel requests it in `hello` only when advertised,
  and each successful, deferred or suspended reply then carries `routines`. Observations are
  inert data with no authority. *T100.*
- **FR-014 — Generated category-indexed interface.** The exporter MUST publish, for each
  category: object constructors, morphism constructors, operations at their actual domains,
  immediate functor object and morphism actions, and for each the complete ordered dependent
  parameters, permitted choices, selected structures, comparisons, callable and lazy fields,
  result layout and subsequent uses. Constructors of categories stay in a separate list. The
  generated files are never edited by hand. *T028, T101.*
- **FR-015 — Structural flag.** Each functor row of the generated catalogue MUST carry
  `structural` as a first-class boolean field, read from the lean-categories row, beside its
  source and target. The flag is not only inside `registeredMetadata`. *T028; computational
  milestone order (kernel plan, "Computational milestones").*
- **FR-016 — SDK category helpers.** `cas_interfaces.load_interfaces(path)` MUST give direct
  access to a category's signatures and build its constructor, call and result packets from the
  generated interface, with explicit dependent descriptors where Python types cannot express a
  dependency. It defines no wire codec and chooses no realization. *T028.*
- **FR-017 — Inherited methods along a route.** A registration at the source category of an
  inherited method, or at a category inside its route, MUST receive the receiver with one
  descriptor for each residual action and then the method-functor descriptor
  (`CasContract/Port.lean`, method invocation). *Kernel consumers: T061, T026 ("Released contract
  rules with no implementation").*
- **FR-018 — Functor map requests.** The request of a functor's map action MUST carry the complete
  source arrow, every ordered functor parameter and both already computed image endpoints; the
  reply is admitted at those images (`api/manifest.md`). *Kernel consumers: T042, T061.*
- **FR-019 — Public documents without legacy or route rules.** The `api/` documents MUST state
  only the protocol-2 forms; they MUST hold no legacy recipe framing, no raw-receiver permission,
  no nearest-binding or route-length rule, no admission condition that needs a computation, no
  undefined "producer receipt" and no restated catalogue mathematics. *T028.*
- **FR-020 — Protocol peer.** The repository MUST publish a protocol peer: a kernel-side driver
  (`lake exe cas-peer`) that runs a scenario of prescribed frames against a leaf process, and a
  leaf-side peer (`peer/protocol_peer.py`, `peer/leaves.json`) that replies from a scenario file.
  Neither computes a mathematical value. *Kernel checks of T017–T023, T027.*
- **FR-021 — Public-only completeness.** `api/README.md` MUST index every document, generated
  file and SDK module that a leaf author needs, with the setup command of the SDK environment.
  No published file names kernel internals, the acceptance corpus or expected answers. *T028,
  T200–T224.*
- **FR-022 — Releases.** At kernel F the integration branch commit with regenerated catalogue
  MUST be tagged `v2.0.0`, which the kernel branch pins and leaf work consumes. At kernel T105 the
  protocol-2 material MUST be merged into `main`, build on the toolchain and Mathlib of `main`,
  have its catalogue regenerated from that locked state, and be tagged `v2.0.1`, which kernel
  `main` pins. *T028 (at F), T200–T224, T105.*
- **FR-023 — SDK logging.** The SDK MUST log to standard error each received and sent frame (by
  request ID, `op` and status), each handler start and end, and each export, suspension, resume and
  disposal (constitution RC17).
- **FR-024 — Construction cost.** Creating a session, a proxy or a loaded interface MUST do no
  per-row work; the category index is built on first query (constitution RC20).
- **FR-025 — Value forms of category data.** The contract MUST declare, in the `api/` documents
  and the generated interface, the complete form, the validators (layout, dependent roles, scope
  and owner, and no condition that needs a computation), one worked example and one malformed
  example of each data kind of issue #14, generated from the accepted declarations of
  lean-categories and the protocol grammar (constitution RC3):
  - a value of a declared object whose declaration is a native inductive type uses the native
    constructor packets of its layout: $\mathbb{N} \cup \{-\infty\}$ (`obj.sets.degrees`,
    `WithBot ℕ`) is `{"ctor":"some","args":[k]}` or `{"ctor":"none","args":[]}`;
  - a value with no native constructor layout is a registered morphism or inclusion row applied to
    registered points: $p/q$ through `mor.sets.divide` with $q$ admitted to the units, $\sqrt{a}$
    through `mor.sets.real_sqrt`, $\pi$ and $i$ as the points `mor.sets.real_pi` and
    `mor.sets.complex_i`, a real at $\mathbb{C}$ through `incl.sets.reals_complexes`, a Kähler
    differential through `mor.sets.kaehler_from_coordinate`, a matrix through
    `mor.sets.matrix_rows` at the rows built by `mor.sets.tuple_cons` and `mor.sets.tuple_empty`;
  - an infinite subset uses the power-object rows of lean-categories #191; a binder request and
    its bound map use the binder operation of lean-categories #190; the apex and the legs of a
    product with an infinite factor are the registered limit `lim.sets.product` at its parameters,
    with legs named by the shape objects of lean-categories #187; an element operation in the
    arrow position of `apply` uses the operation owners of lean-categories #193;
  - a closed point $1 \to X$ in a morphism position is a morphism packet, and the `compose`
    envelope carries the selected intermediate object of the composite.
  No form is a leaf-chosen encoding (constitution RC1, RC8). *T028, T185; leaves T034.*

### Key Entities

- **Manifest**: backends and registrations of one leaf package, with preferred routes.
- **Registration**: the triple `(operation, input, backend)`; an invocation port.
- **Category interface**: the generated view of one category (FR-014).
- **Frame**: one length-prefixed JSON value on the leaf's standard streams.
- **Scope**: the kernel-issued slots of one invocation or resume.
- **Export**: a provider-local callable with its token and ordered captures.
- **Continuation**: a one-use token of a suspended generator.
- **No-implementation slot**: the reserved resume entry that names a child without realization.
- **Stratum**: one of the seven failure outcomes.
- **Decision packet**: the `Option Bool` value of a decision reply; `none` is the outcome
  `unknown`.
- **Protocol peer**: the scenario-driven counterpart of a leaf or kernel in a contract test.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tier 1 contract tests run in under five minutes on the research container after the
  explicit setup step, and cover every frame kind of FR-002 to FR-013.
- **SC-002**: Every tier 1 run writes one log under `tests/logs/` and one timing record per test
  to `tests/timing/records.jsonl`, with run, revision, environment and input.
- **SC-003**: The quickstart category implementation of User Story 1 runs end to end from a
  checkout of the release commit with no lean-cas-dsl checkout on the host.
- **SC-004**: `git grep -n -i "legacy"` over `api/` and `python/` returns no protocol form, and no
  `api/` document contains a rule of FR-019.
- **SC-005**: For each functor row of `api/declared-ports.json`, the field `structural` exists and
  equals the lean-categories row at the pinned revision.
- **SC-006**: The kernel branch's lake manifest names the `v2.0.0` commit, kernel `main` names the
  `v2.0.1` commit, and both commits exist on GitHub.

## Assumptions

- The kernel's runtime contract and tasks are the source of the kernel-side behaviour; this
  repository does not implement kernel selection, admission or execution.
- The catalogue exporter is `tools/export_api.py` with the adapters
  `tools/export_declared_ports.lean` and `tools/export_admission_addresses.lean` of this
  repository; the language interface comes from the kernel's `CasTools/InterfaceExport.lean`
  (research R10). Both run in a built kernel environment; their output is committed here.
- The SDK language is Python; no other language SDK is part of this release (kernel T028).

[KC]: https://github.com/dzackgarza/lean-cas-dsl/blob/main/.specify/memory/constitution.md
[KR]: https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/001-categorical-research-language/contracts/computational-runtime.md
