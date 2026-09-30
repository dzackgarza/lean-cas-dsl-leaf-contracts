# The leaf contract of lean-cas-dsl

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
| `lean-cas-dsl-leaf-contracts` (this) | `lean-categories` | the shape of a leaf's manifest (`CasContract.Registration`), the backend port protocol (`CasContract.Port`), the failure strata (`CasContract.Failure`), and the kernel's reading of the semantic registry (`CasContract.Registry.Extension`) |
| `lean-cas-dsl-leaves` | nothing | a manifest `leaves.json` of registrations, and the programs it names; no Lean |
| `lean-cas-dsl` | `lean-categories`, this (it runs the leaves' manifest) | the kernel's resolution and reading of statements, the language, the acceptance suite and notebooks; no leaf |

* **Authors.** Only the orchestrator writes here. Leaves are written against this contract by the
  leaf subagent, which never edits it, never reads the tests, and never edits `lean-categories`
  (`lean-cas-dsl/specs/architecture.md`, "Authors: one role per agent").
* **A leaf is data, and nothing it says is believed.** A registration is exactly (operation id,
  input form, backend); a leaf ships no Lean and imports nothing. Its answers are decoded in the
  operation's declared result form or rejected, and are compared only with the acceptance suite's
  expected values. The forbidden forms (a denotation, a proof, an identification, evidence, a
  status, a decoder) are unrepresentable here, not rejected.
* **Relaxing the contract is almost never the fix.** A leaf that cannot meet the contract means
  one of two things:
  - the leaf is wrong, which is a finding against the leaf;
  - mathematics is missing (an operation, a form), which is a formalization request to
    `lean-categories`.

  The contract changes only with a mathematical justification from the formalization author,
  recorded with the change. It never changes to fit a leaf's representation or programming needs.
* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl` and merged to
  `main`, which `lean-cas-dsl` tracks. A leaf never changes this contract to fit itself.
* **No mathematics.** Which operations and forms exist, and what they denote, is `lean-categories`'
  catalogue. This package reads it and declares none.
* **No tests.** The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a
  leaf can reach, contains or names it.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The Python
reference implementation of the port protocol is `python/cas_port.py`; the kernel puts it on every
program's `PYTHONPATH`.

Every `require` tracks `main`. `just test-ci` builds on Mathlib's prebuilt cache and runs the
kernel-axiom audit (`AxiomAudit.lean`); the commit and push tiers compile nothing.
