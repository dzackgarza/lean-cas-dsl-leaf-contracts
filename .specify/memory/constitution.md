# lean-cas-dsl-leaf-contracts Constitution

This repository publishes the released computational contract: the manifest of a leaf package,
the port protocol, the failure strata, the generated catalogue under `api/` and the Python SDK
(`cas_port`, `cas_session`, `cas_interfaces`). A leaf is written against this contract and
nothing else of the kernel (`AGENTS.md`, `README.md`).

The [kernel constitution][K] (lean-cas-dsl, v4.0.0) governs the whole programme. This file
states the obligations of that constitution that bind a contract, and the rules of this
repository's own governing documents. Article identifiers `RC1` to `RC20` are stable. A kernel
article is cited as `K:C<n>`.

## Core Principles

### RC1. The contract confers no mathematical authority

The contract fixes how a computation is invoked, encoded and returned. It defines no category,
operation, law, domain, result type, membership, inheritance, mathematical identity or
correctness criterion. Which operations and input forms exist, and what they denote, is the
catalogue of lean-categories; this repository reads that catalogue and declares none
(`AGENTS.md`, "No mathematics"; K:C1, K:C2).

- A wire field MUST NOT carry a proof, certificate, checker, denotation, membership claim,
  category declaration or acceptance grant (`api/README.md`, agreement and proof-body rules).
- Control forms (`deferredData`, `inputRef`, `resultRef`, `scopeRef`, `$cas.*` operations)
  create no constructor, operation, category, equality or proof (`api/kernel-service.md`).
- An unrecognized address creates no operation or form (`api/manifest.md`).

### RC2. A registration is a claim, and a registration is a port

A registration `(operation, input, backend)` claims that a backend implements an already
accepted operation at an admitted input form. Admission checks conformance; it does not
certify correctness (`AGENTS.md`, "Registration is a computational claim"; K:C2).

A registration is an invocation port. Registering ports alone does not deliver a category
implementation. The unit of public responsibility is the category implementation: the
admitted object and morphism constructors, the operations at their actual domains and the
immediate functor actions of a category, with their complete dependent inputs and results
(K:C23). Implementations MAY share engines, sessions or private code; such reuse carries no
mathematical authority (`api/manifest.md`; K:C22).

### RC3. The category implementation interface is generated

The published category implementation interface MUST be generated from the accepted
declarations of lean-categories and the released protocol grammar. It MUST NOT be maintained
by hand. Generated files are produced by the exporter (`just export-api`) and are committed
unchanged; a generated file is documentation and a computational interface, never a semantic
registry that the kernel reads to decide meaning (`api/README.md`; K:C23; kernel FR-025).

The generated interface exposes, per category: object and morphism constructors, operations
at their actual domains, immediate functor object and morphism actions, the structural flag of
each functor, and the complete dependent parameters, choices, maps and comparisons of each
request and result. Constructors of objects stay distinct from constructors of categories. The
SDK helpers that give an author direct access to a category are derived from that generated
interface at load time. A later accepted declaration reaches authors by regeneration alone.

### RC4. The kernel computes nothing; a leaf may ask the kernel

Every operation, method and predicate is computed by a leaf. The kernel resolves each request
to a leaf or returns the no-implementation outcome, and it computes no mathematical value
(K:C22). A leaf owns all control logic of its implementation. For each operation that it uses,
a leaf MAY compute internally, call another leaf's code directly, or ask the kernel through
this contract. A leaf that asks the kernel receives the result or the no-implementation outcome
that names the missing operation. The contract MUST provide that answer in every service by
which a leaf asks: a deferred program and an adaptive suspension.

### RC5. Realization selection has no priority

At one selected operation and input form, zero eligible registrations give the
no-implementation outcome, one gives the call and several give implementation ambiguity.
Exact-form and category-wide registrations have equal standing. Manifest order, backend name,
cost, priority, installed order and retry-until-success MUST NOT select a registration
(`api/manifest.md`, "Matching and overlap"; K: realization-selection policy). A failed or
consumed occurrence is not retried (K: retry policy).

### RC6. A declared preferred route is registration data

A registration MAY declare preferred routes (K:C6). A preferred route names which surviving
binding a surface name denotes on an object of a receiver category. It asserts no agreement
between bindings and is not a mathematical claim. A route that is not a surviving route
rejects the registration. Conflicting admitted preferences are not ranked; the reading stays
ambiguous.

### RC7. Failure strata stay distinct

The strata are `invalid`, `semanticAmbiguity`, `noImplementation`, `ambiguousRealization`,
`unavailable`, `malformed` and `internal` (K:C13; kernel runtime contract §8). No retry,
fallback, restart or cache hit merges them. A leaf reply cannot declare semantic invalidity or
ambiguity. A well-shaped wrong answer is not a stratum; independent assessment judges it.

An `unknown` answer to a predicate is an inability to establish the result, not a third truth
value (K:C6). It is a procedural outcome on the wire and maps to `unavailable`.

### RC8. One exact protocol

The contract specifies one protocol, `cas-computation/2`, with exact framing, negotiation and
frame grammar (kernel runtime contract §3). Unknown control fields and unknown manifest fields
are malformed. A missing required field is malformed and is never given a default. The contract
holds no legacy wire form, no downgrade path and no compatibility shim. A breaking change is a
new major protocol version.

### RC9. A public-only author needs nothing else

A leaf author receives the released contract, the accepted catalogue and backend resources. A
leaf author does not receive kernel source, internal handoffs, the acceptance corpus, protected
expectations or prior outcomes (K: "Independent authorship and permitted inputs"). Every
published document, generated file and SDK interface MUST let such an author write, build and
run a category implementation without those excluded inputs. A need for kernel machinery or a
hand-rolled algorithm is a finding against the contract or the kernel, never relaxed into the
leaf (`AGENTS.md`, "A leaf is glue").

### RC10. Releases are exact source states

A release is a commit of `main` whose Lake manifest locks its dependency revisions and whose
generated files were produced from that locked state (`README.md`; `api/README.md`). A snapshot
is never relabelled as a new export. A failed export leaves the previous snapshot intact.
Delivery consumes latest-main dependencies and records the actual revisions (K: delivery-inputs
policy). A revision that a consumer pins MUST exist on GitHub.

### RC11. Independent extensions compose through this contract

A new producer's construction is usable by an existing consumer through the released contract,
without private representation knowledge (K:C12). A frozen extension trial admits no
accommodation edit to this contract. A deficiency found by a trial is repaired by a new
candidate and a repeated trial.

## Engineering Defaults

### RC12. Test tiers

Tier 1 is the smallest set of tests that establishes the specified behaviour through the happy
paths and the branches that matter. Its total run time is seconds or minutes; a slow tier 1 is a
defect to repair when found. Higher tiers add the long tail: examples, permutations, edge cases
and unusual combinations (K:C24).

This repository tests its own product: the Lean codecs and the Python SDK. The permanent
mathematical acceptance suite stays with lean-cas-dsl; nothing here contains or names it, and
no test here is acceptance evidence for a leaf's answers (`AGENTS.md`; K: independent-harness
policy).

### RC13. Test design

A test exercises externally observable, end-to-end behaviour through a real user story of the
specification. A contract test runs a real leaf process that speaks the real protocol against a
real protocol peer built from this repository's codecs. Mocks, fakes, tests of internal units
and tests that bypass the framed connection are not used. A test does not supply the behaviour
whose existence it checks (K:C19, K:C24).

### RC14. Contribution lessons

`CONTRIBUTING.md` records lessons from past mistakes as policies with stable alphanumeric
identifiers, grouped by category. Each policy covers a general class of contribution and, where
possible, shows a defective contribution beside its replacement.

### RC15. Feedback cadence

Feedback loops of ten minutes or more are minimized. Commit-time checks are the primary loop.
Long runs (the full Lean gate, export regeneration) are for milestones: a batch of work, a push
or a release.

### RC16. Platform scope

The contract supports one platform: Linux with the research container's toolchain. Another
platform is added only on explicit request.

### RC17. Logging

The SDK writes detailed logs to standard error, which is the diagnostic channel: each received
and sent frame by request ID and operation, each handler start and end, each export,
suspension, resume and disposal. Each test run writes a durable log that is kept in the
repository.

### RC18. Timing history

Every test has a timing record that includes setup, fixtures, construction and nested work.
Each record carries its run, revision, environment and input. The records are durable and are
kept in the repository.

### RC19. Timing triage

Optimization is selected from a triage table of measured costs: operation, cost per call,
multiplying factors, aggregate cost, priority, proposed remedy and remaining measured cost.
Optimization follows functionality (K:C21).

### RC20. Construction cost

Constructing an SDK object (a proxy, a session, a loaded category interface) is close to
instant. Expensive work, such as indexing the generated catalogue, is deferred until it is
queried. Internal setup does not dominate a leaf's computational cost.

## Ownership and Inputs

| Owner | Owns |
| --- | --- |
| lean-categories | All mathematics and the catalogue |
| This repository | Manifest shape (`CasContract.Registration`), port protocol (`CasContract.Port`), failure strata (`CasContract.Failure`), Python SDK, generated `api/` files, protocol peer |
| lean-cas-dsl | Selection, preparation, execution, admission, retention; the exporter source (`CasTools/InterfaceExport.lean`); the acceptance suite |
| Leaf packages | Category implementations against this contract |

Changes here are kernel/contract construction work (K: authorship roles). A leaf never changes
this contract to fit itself (`AGENTS.md`, "Kernel-owned").

## Governance

This constitution governs the documents of this repository. Where `AGENTS.md`, `README.md`,
`INTENT.md` or an `api/` document conflicts with it, the subordinate document is corrected.
Where this constitution conflicts with the kernel constitution, the kernel constitution
governs and this file is corrected.

An amendment identifies the article, the old and the new obligation and its source; it updates
this file, its version and its amendment date in the same change, and it reconciles the
affected documents. Versions are major for incompatible changes to an obligation, minor for
additions, patch for editorial corrections. Article identifiers are never renumbered.

Work order is the task list of the active feature under `specs/`. Its unchecked tasks are
executed in document order. Work records and evidence stay in the owning GitHub issues.

**Version**: 1.0.0 | **Ratified**: 2026-11-25 | **Last Amended**: 2026-11-25

[K]: https://github.com/dzackgarza/lean-cas-dsl/blob/main/.specify/memory/constitution.md
