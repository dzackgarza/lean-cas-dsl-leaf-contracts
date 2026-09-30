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

1. **Nothing from a leaf is trusted, in any form.** Nothing a leaf says is believed by anything
   else. That includes text, a label, a comment, a status, a trust level, a certificate, a checker,
   a Lean proof, a theorem about its own code, a denotation of its values, an identification of two
   values, evidence for a decision, its own tests and their results, and any other claim. None of it
   is consulted, recorded as evidence, or allowed to affect meaning or acceptance.
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
6. **What can be discharged in Lean is never a leaf's.** A computation that can be carried out
   entirely in Lean belongs to the formalization surface. Either `lean-categories` proves it, by its
   own standards and blind to every implementation, or the kernel discharges it automatically and
   generically, blind to every leaf. A leaf never implements a Lean-checked computation, because
   that would let a leaf certify itself.
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

9. **Quality is raised by proving more, never by trusting more.** The system never guarantees an
   implementation's correctness and never accepts a claim of it. The response to bad leaves is:
   - formalize more mathematics in `lean-categories`;
   - add more cited or proved assertions to the suite: results a correct implementation must
     recover, and a wrong one fails.

   It is never to inspect, certify, score, or review a leaf into trust.

Consequences:
- A leaf holds zero semantic authority. It never decides what a value is, which values are equal,
  what holds of them, or which operations an object has.
- A leaf is a registration (operation, input form, opaque implementation). It ships no mathematics
  and no Lean.
- The kernel and the language never read anything a leaf wrote to decide meaning, types,
  available operations or acceptance.
- The workflow runs one way: formalization, then assertions, then implementations. A leaf's
  failure never changes the mathematics, the kernel's rules or an assertion.
- Text anywhere that contradicts this is rewritten to state this model, not kept with a label.

# The leaf contract of lean-cas-dsl

> **You have no memory.** Nothing that exists only in chat survives compaction or the session.
> Every correction, finding and decision request is committed to its owning document first
> ([`lean-cas-dsl/AGENTS.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/AGENTS.md),
> "You have no memory"). The orchestrator is inside the threat model
> (`lean-cas-dsl/specs/architecture.md`).


[`lean-cas-dsl/specs/architecture.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/architecture.md)
owns the separation of concerns. This repository is one part of the `lean-cas-dsl` kernel: the
declared type a computational leaf is written against, published on its own so that a leaf depends
on nothing else of the kernel.

| Package | Depends on | Owns |
| --- | --- | --- |
| `lean-categories` | Mathlib | all mathematics, including the semantic registry (the catalogue) |
| `lean-cas-dsl-leaf-contracts` (this) | `lean-categories` | the form of a leaf registration (operation, input form, opaque implementation), the declared input and result forms of registered operations, the backend port protocol, the failure strata of a call |
| `lean-cas-dsl-leaves` | this, `lean-categories` | registrations of opaque implementations only: no mathematics, no Lean |
| `lean-cas-dsl` | all three (it consumes the leaves) | the kernel's resolution and propagation, the language, the permanent tests and notebooks, which run over the installed leaves; no leaf |

* **Authors.** Only the orchestrator writes here. Leaves are written against this contract by the
  leaf subagent, which never edits it, never reads the tests, and never edits `lean-categories`
  (`lean-cas-dsl/specs/architecture.md`, "Authors: one role per agent").
* **What a leaf is.** A leaf registration names a registered operation and an input form, and
  supplies an opaque implementation: a computation from that input form to the operation's declared
  result form. The system runs it and believes nothing about it. A leaf ships no mathematics and no
  Lean: no proof, denotation, identification of values, decision evidence, status, trust level,
  certificate or checker. Nothing in this contract gives a leaf a way to state any of these, and
  nothing that consumes this contract reads one.
* **The contract is the type at the firewall.** It fixes the type a leaf's computation must meet
  and nothing else. On the leaf side anything goes that meets it. Only answers cross, and an answer
  is checked against the formal side, the permanent acceptance suite of `lean-cas-dsl`, never
  believed. A wrong answer of the declared result form is visible to that suite and to nothing
  else.
* **Relaxing the contract is almost never the fix.** A leaf that cannot meet the contract means
  one of two things:
  - the leaf is wrong, which is a finding against the leaf;
  - mathematics is missing, which is a formalization request to `lean-categories`.
  
  The contract changes only with a mathematical justification from the formalization author,
  recorded with the change. It never changes to fit a leaf's representation or programming needs.
* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl` and merged to
  `main`, which the leaves and `lean-cas-dsl` track. A leaf never changes this contract to fit itself.
* **No partial maps (LC-14), no operation without its structure (LC-16).** A registration is for a
  total operation on its domain object. No declared result form admits an optional, undefined or
  default result.
* **No mathematics.** Every operation a registration names is a row of `lean-categories`'
  catalogue, and its input and result forms are declared from that row. A registration is checked
  only for naming a registered operation and matching its declared forms.
* **What can be discharged in Lean is not a leaf's.** A computation that can be carried out
  entirely in Lean is proved in `lean-categories` or discharged generically by the kernel, never
  registered by a leaf.
* **No tests.** The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a
  leaf can reach, contains, names or runs it.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The backend
port protocol is length-prefixed JSON frames between the kernel and a leaf's program; its Python
reference implementation is `python/cas_port.py`, which `Backend.connect` puts on every adapter's
`PYTHONPATH`. A leaf's answers cross as untrusted data: one that is not a value of the declared
result form is rejected, and one that is carries no belief with it.

Every `require` tracks `main`. `just test-ci` builds on Mathlib's prebuilt cache and runs the
kernel-axiom audit of this repository's own code (`AxiomAudit.lean`); the commit and push tiers
compile nothing.

The contract's code does not yet have this form; its replacement is tracked by the plan node
`gov-leaf-authority` in `lean-cas-dsl/specs/computational-core-plan.md`.
