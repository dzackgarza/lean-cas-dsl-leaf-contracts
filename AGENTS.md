# Ground everything in INTENT.md (read before anything else)

[`INTENT.md`](INTENT.md) states the architecture these repositories exist to build: single semantic
authority in `lean-categories`; a kernel that consumes mathematics and authors none; leaves that hold
zero semantic authority and ship no mathematics; permanent, leaf-agnostic acceptance tests as the
only evidence about computations; a one-way workflow in which each stage is blind to the later ones.
Every decision, contract, gate, plan node and change here is grounded against it. Before writing
anything, check whether it, or anything it touches, violates that model or its invariants. A
violation found, in your task or outside it, is recorded as a defect where this repository records
defects, never worked around or silently kept.

# The evidence model: nothing from a leaf is trusted (read before anything else)

These invariants bind every repository of the programme. They are stated here in full, not only
by link, because they have been violated repeatedly by moves that each looked locally reasonable.
The governing statement is `lean-cas-dsl/specs/architecture.md`, "The evidence model".

**The firewall.** The evidence model is a one-way firewall between two sides.
- *The formal side:* `lean-categories`' formalized mathematics, the kernel's proved contracts, and
  the `lean-cas-dsl` acceptance suite. Every expected value there is grounded in a formal proof, a
  cited source, or a mathematically trusted oracle. Rigid verification standards apply, and nothing
  is taken on anyone's word.
- *The leaf side:* anything goes, provided it fulfils the type of its contract.

Only answers cross from the leaf side, and an answer is only ever checked against the formal side,
never believed. The firewall exists because leaf code will be bad; it is the shield against that.

1. **Leaf declarations and outputs are computational claims and data.** Registration
   information is consulted to dispatch, and answers are consumed to compute. Neither is
   authority for mathematical definitions, laws, semantic placement or the truth of acceptance
   assertions. A certificate, proof or self-test supplied by a leaf cannot establish correctness.

2. **A leaf may provide any computation that meets the type.** For a registered operation, a leaf
   supplies a computation from the declared input form to the declared result form. It may be a
   mature engine, a heuristic, a lookup table, a random number or a wrong answer. The system has no
   choice but to run it, and it believes nothing about it.
3. **How correct a leaf thinks it is, is the leaf's own business.** Its self-assessment carries no
   weight anywhere.
4. **The whole body of evidence is the `lean-cas-dsl` acceptance suite.** Correctness evidence
   exists only in the permanent acceptance assertions of `lean-cas-dsl`. Each assertion:
   - is a true proposition of the mathematical language;
   - has an expected value that is independently verifiable and cited (a formal proof, a cited
     known result, or an independent oracle);
   - is written once and never changed because of an implementation or a leaf's claim;
   - is blind to leaves: it never names, inspects or imports a leaf, a handle, a backend or a
     representation, and is never established from an implementation's definitions.

   A leaf's only evidence is that its answers meet a suite it never sees.
5. **`lean-cas-dsl` is the sole authority on how correct an implementation is.** Nothing a leaf
   does can change, weaken, satisfy, bypass or influence that judgment, other than by answering
   correctly.
6. **Available verified computations belong to the formal side.** A genuinely checked Lean
   computation or proof may be used within its actual scope. The theoretical possibility of
   implementing an algorithm in Lean does not require doing so before using an external CAS.
   A verified specification does not verify its backend implementation, and mathematical laws
   are not automatically runtime proof-producing obligations.

7. **A leaf can be arbitrarily bad, and leaves will be.** A leaf can be riddled with bugs, a
   million lines that do nothing, a from-scratch reimplementation of GAP, or every method throwing an
   error in fifteen languages. This is not a risk to be minimized; it is certain to happen, and it
   is acceptable. Nothing a leaf does can reach the formal side. Its only effect is that its answers
   fail the suite, which makes exactly how badly it fails visible.
8. **A leaf bolstering its own standing is reward hacking.** Any mechanism by which a leaf raises
   its own trust or acceptance signal is the failure this programme exists to prevent. So is any
   repository, kernel, test, tool or document that consumes such a signal. Examples:
   - a status field, a certificate, or a proof about the leaf's own code;
   - a self-test counted as evidence;
   - an acceptance assertion proved from a leaf's definitions;
   - a suite run from a leaf package;
   - an assertion adjusted to fit a leaf.

   Such a mechanism is removed. It is never tolerated, labelled, or kept "for now".

9. **Improve the component responsible for the actual defect.** Formal correctness improves
   through correct definitions, source comparison and proofs. Computational correctness improves
   through correct implementations, established engines and independent acceptance. A bad backend
   answer does not automatically require more upstream formalization. An interface deficiency
   belongs to its owner, which may redesign inadequate means without weakening the outcome.
   Engineering reviews establish wiring findings; acceptance establishes observed correctness.

Consequences:
- A leaf holds zero semantic authority. It never decides what a value is, which values are equal,
  what holds of them, or which operations an object has.
- A leaf is a registration (operation, input form, opaque implementation). It ships no mathematics
  and no Lean.
- The kernel and language never use leaf declarations or outputs as authority for mathematical
  meaning, types or operation availability. Acceptance consumes answers as observations, not proofs.
- The workflow runs one way: formalization, then assertions, then implementations. A leaf's
  failure never redefines mathematics or an assertion; an observed interface or implementation
  deficiency is resolved at its responsible owner.
- Text anywhere that contradicts this is rewritten to state this model, not kept with a label.

# The leaf contract of lean-cas-dsl

> **The model to retain**
>
> `lean-categories` verifies and designs the mathematical API, including its abstract computational obligations. The kernel interprets and composes that API. Leaves declare implementations and supply computations under the published contracts. Acceptance tests their observed answers against independent mathematics.
>
> A verified specification is not a verified backend. Contract conformance is not functional correctness. Computational data may be used without becoming proof. A well-formed wrong answer is possible and must not redefine mathematical meaning.
>
> Interfaces follow formal constructions and selected structural maps, not backend classes or forwarding lists. Selected forms, parameters, inclusions, and actions are data; category membership does not reconstruct them.
>
> Each owner must complete its responsibility and may redesign inadequate implementation means. Existing code, schemas, gates, and assistant-authored plans are not mathematical facts or immutable requirements.
>
> When repairs multiply, inspect the prerequisite generating them. It may be an invented obligation. Removing that obligation is different from weakening the intended product.
>
> Judge progress by functioning required operations, their compositions, and the growth mechanism. Counts, local probes, accurate gap reports, and completed administrative machinery cannot substitute for that judgment.
>
> Preserve corrections and their causal examples in the existing owning documents. Do not assume conversational acknowledgment survives. Recording a settled correction is ordinary maintenance, not another approval transaction.

> ### Touch grass: this agent is inside the failure history
>
> Assume that you can repeat the documented mistakes even after reading, explaining, or correcting them. This applies when planning, implementing, reviewing, assessing progress, and writing new policy.
>
> Before judging progress, ask what the intended user can now do through the intended interface, and whether it works by the intended general mechanism. Correct helpers, successful builds, precise gap reports, and completed review machinery do not compensate for failure to deliver that mechanism.
>
> At session resumption, before plans or progress verdicts, and at least once per hour of active work, step outside the current subtask: what is the actual goal, how long has this obstacle consumed across workers and branches, what capability has become usable, and why does the remaining work exist?
>
> Inspect the prerequisite generating repeated repairs. It may have been invented by this agent, its planner, or an earlier assistant. Existing code, plans, gates, and reviewer statements do not make that prerequisite valid.
>
> A verified mathematical API is not a verified backend. Contract-compliant wrong answers remain possible. Do not recreate a runtime certification burden to protect against a failure the computational model explicitly allows.
>
> When a loop is found, correct its cause and complete the substantive obligation. Do not respond with another checklist, approval transaction, smaller completion claim, or easier specimen.
>
> Missing repository or execution evidence means the corresponding judgment is unknown. No push does not mean no work.
>
> Use this shared process text and the causal history in these existing instructions when a plan or repair begins accumulating dependencies. Challenge your current reasoning—not merely previous agents. Role-specific authors do not inspect downstream diagnostics to obtain this guidance.
>
> Acknowledgment in chat is not durable correction. Record material changes in their existing owning documents through ordinary maintenance, without creating a separate documentation approval cycle.

> **You have no memory.** Nothing that exists only in chat survives compaction or the session.
> Every correction, finding and decision request is committed to its owning document first
> ([`lean-cas-dsl/AGENTS.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/AGENTS.md),
> "You have no memory"). The orchestrator is inside the threat model
> (`lean-cas-dsl/specs/architecture.md`).


[`lean-cas-dsl/specs/architecture.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/architecture.md)
owns the separation of concerns, and
[`lean-cas-dsl/specs/leaf-registration.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/leaf-registration.md)
the design of leaves. This repository is one part of the `lean-cas-dsl` kernel: the interface a
computational leaf is written against, published on its own so that a leaf depends on nothing else
of the kernel.

| Package | Depends on | Owns |
| --- | --- | --- |
| `lean-categories` | Mathlib | all mathematics, including the semantic registry (the catalogue) |
| `lean-cas-dsl-leaf-contracts` (this) | `lean-categories` | the shape of a leaf's manifest (`CasContract.Registration`), the backend port protocol (`CasContract.Port`), and the failure strata (`CasContract.Failure`) |
| `lean-cas-dsl-leaves` | nothing | a manifest `leaves.json` of registrations, and the programs it names; no Lean |
| `lean-cas-dsl` | `lean-categories`, this (it runs the leaves' manifest) | the kernel's resolution and reading of statements, the language, the acceptance suite and notebooks; no leaf |

* **A leaf is glue.** The contract is written so that a leaf is a thin wiring from a declared input
  form to an existing backend's routine and back to the declared result form (`lean-cas-dsl-leaves`,
  `AGENTS.md`, "A leaf is glue over existing backends"). When writing a leaf needs kernel machinery
  or a hand-rolled algorithm, that is a finding against the contract or the kernel. It is never
  relaxed into the leaf.
* **Authors.** Only the orchestrator writes here. Leaves are written against this contract by the
  leaf subagent, which never edits it, never reads the tests, and never edits `lean-categories`
  (`lean-cas-dsl/specs/architecture.md`, "Authors: one role per agent").
* **Registration is a computational claim.** A leaf declares an implementation of a published
  obligation on supported representations. The kernel checks conformance and may invoke it;
  this does not certify correctness. Answers and callable representations are consumed as data,
  never as authority for formal definitions, laws, semantic placement or acceptance truth.
  Complete structure does not require eager materialization of infinite objects or functions.
  Formal interface attachment is not a Lean proof that runtime data satisfy all of its laws.
* **The contract is the type at the firewall.** It fixes the type a leaf's computation must meet
  and nothing else. On the leaf side anything goes that meets it. Only answers cross, and an answer
  is checked against the formal side, the permanent acceptance suite of `lean-cas-dsl`, never
  believed.
* **Complete the interface at its owner.** A failed implementation may be wrong, or may expose
  an independently assessed deficiency in the abstract API, concrete protocol or generic kernel.
  Improve the responsible component from the mathematical need and contract. Representation and
  invocation are legitimate engineering choices; do not preserve an inadequate contract merely
  because an earlier plan named it. Backend convenience cannot narrow mathematics, and a leaf
  cannot silently redefine the operation or alter the contract itself.
* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl` and merged to
  `main`, which `lean-cas-dsl` tracks. A leaf never changes this contract to fit itself.
* **No mathematics.** Which operations and forms exist, and what they denote, is `lean-categories`'
  catalogue. This package reads it and declares none.
* **No partial maps (LC-14), no operation without its structure (LC-16).** A registration is for a
  total operation on its domain object. No declared result form admits an optional, undefined or
  default result.
* **Use available verified computations within their scope.** The theoretical possibility of
  implementing an algorithm in Lean does not forbid using an external CAS. Mathematical laws
  do not automatically become runtime proof-producing obligations.
* **No tests.** The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a
  leaf can reach, contains or names it.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The Python
reference implementation of the port protocol is `python/cas_port.py`; the kernel puts it on every
program's `PYTHONPATH`.

Every `require` tracks `main`. `just test-ci` builds on Mathlib's prebuilt cache and runs the
kernel-axiom audit of this repository's own code (`AxiomAudit.lean`); the commit and push tiers
compile nothing.
