# lean-cas-dsl-leaf-contracts Constitution

This repository publishes the one typed, language-neutral computational contract
between the generic Lean kernel and independent category implementations. A leaf
implements a category or parameterized category family; each registration is a
port of that interface, and one engine may realize several categories.

The [cas-dsl kernel constitution][K] governs the programme, including every
feature and replacement implementation of this contract. The mathematical
authority is lean-categories, the kernel is cas-dsl, and category implementations
are supplied by the leaves. The contract owner releases the manifest, invocation
and data protocol, failure strata, generated interfaces and typed language
bindings. A leaf is written against that public contract and the accepted
mathematical declarations, not kernel source or independent acceptance tests.
Article identifiers RC1–RC20 remain stable. References to the archived kernel's
C-numbered articles record historical source requirements; the current kernel
constitution governs their interpretation.

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

The generated interface gives a leaf author the category version, its
constructors, maps, operations at their declared domains, structural functor
actions, exact registration addresses, and complete dependent input and result
signatures. A new accepted declaration reaches authors through regeneration.

The public binding makes these interfaces implementable directly in existing
CAS software. It supplies reusable codecs, dispatch to registered handlers,
scoped native-value handles, invocation and release, and error replies. The
leaf author imports the engine and binding, associates each declared port
with the corresponding engine routine, and registers the category version.
Handlers adapt the declared inputs to native engine values, invoke existing
computations and return the actual declared data and maps. A native result
may remain in the leaf and be supplied to subsequent calls by its handle.
Use the engine's natural language and the same published protocol.

The contract is typed independently of the implementation languages of
providers. Reuse language bindings in their natural languages, including the
existing Python binding for Sage. Where ordinary CAS calls require extensive
new glue, simplify the reusable interface and binding so that every category
implementation benefits. A Sage finite-set leaf should essentially connect
the declared extent and cardinality to Sage's own set constructor and
cardinality operation. This is the intended author experience.

### RC4. The kernel resolves; leaves compute

Every declared computational obligation is computed by a leaf. The common Lean
kernel selects the exact mathematical question and realization, or reports the
declared missing-implementation outcome. Authorized formal discharge of a
proposition is not a leaf computation. A leaf owns the control logic of its
implementation and may compute internally, reuse another leaf's code directly,
or ask the kernel through the released contract. Deferred and adaptive requests
preserve the same authority boundary and report the actual result or missing
operation.

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

An `unknown` answer to a decision (a predicate or a property) is an inability to establish the
result, not a third truth value (K:C6). On the wire it is the value `none` of the decision reply,
whose value is an `Option Bool` packet. The kernel reports it as the outcome `unknown`, which is
distinct from every stratum and from every other outcome (K:C13; kernel T302, T113).

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
run a category implementation without those excluded inputs. A need for private kernel machinery is a finding against the contract or kernel. A leaf
composes existing CAS routines and uses established algorithms for missing
computations; the binding makes this work local to the mathematical adapter.

### RC10. Freeze the typed interface first; release exact source states

Establish the common kernel–leaf interface at the beginning of development
with an actual first category implementation. Before dependent category versions
rely on it, publish and pin the tested protocol, typed invocation and data
interfaces, failure/lifetime behavior, compatible mathematical declarations and
dependency tuple. Use real typed Lean calls to the real leaf; surface elaboration
is not a prerequisite. A category version names its actual mathematical interface
and required inputs. New categories use the existing contract, not a new wire
dialect. The normative contract is typed; language bindings expose it in the native
languages of their users. A language-specific SDK implements that same
protocol and supplies its reusable mechanics.

A release is a tagged commit whose manifest locks the dependency revisions and
whose generated interfaces were produced from that locked state. Consumers pin
an actual published compatible release. An incompatible correction requires an
explicit new protocol version, not parallel private forms or a legacy fallback.
No permanent freeze of the category catalogue, seal, or approval service is
required. A failed export leaves the previous valid snapshot intact.

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

This repository tests its own product: the actual released typed codecs and language bindings. The permanent
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

Diagnostics use standard error, never the protocol channel. Keep useful logs
outside Git and compact durable measurements where they support actual fixes.
Do not build telemetry, archival integrity or logging machinery in place of
contract delivery.

### RC18. Timing

Measure actual setup, computation and nested work when diagnosing performance.
Use the measured environment, input and revision; keep compact comparable
results. Raw run logs and timing JSONL do not belong in the repository.

### RC19. Timing triage

Optimize the actual dominant cost; preserve fast focused feedback and the
independent mathematical acceptance. Measurements do not become a prerequisite
to unrelated implementation work.

### RC20. Construction cost

Constructing an SDK object (a proxy, a session, a loaded category interface) is close to
instant. Expensive work, such as indexing the generated catalogue, is deferred until it is
queried. Internal setup does not dominate a leaf's computational cost.

## Ownership and Inputs

| Owner | Owns |
| --- | --- |
| lean-categories | All mathematics and the catalogue |
| This repository | Manifest shape (`CasContract.Registration`), port protocol (`CasContract.Port`), failure strata (`CasContract.Failure`), typed bindings, generated `api/` interfaces, protocol peer |
| cas-dsl | The common Lean kernel: selection, preparation, execution, admission, retention, independent acceptance; typed catalogue export as required by the public interface |
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

The active feature under `specs/` specifies concrete work within these durable
invariants. Contract development and the first real category versions proceed
together; subsequent work follows actual categorical and contract dependencies,
not a serial kernel-first task order.

**Version**: 3.0.0 | **Ratified**: 2026-11-25 | **Last Amended**: 2026-11-28

[K]: https://github.com/dzackgarza/cas-dsl/blob/main/.specify/memory/constitution.md
