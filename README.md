# The leaf contract of lean-cas-dsl

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
| `lean-cas-dsl` | `lean-categories`, this | the kernel's resolution and reading of statements, the language, the acceptance suite, the harness |

* **A leaf is data.** A leaf is `leaves.json` at the root of its package: the backend programs it
  runs, and for each registration the catalogue operation it computes, the input form it accepts
  and the backend that computes it. A registration has exactly those three fields; nothing else a
  manifest says carries meaning. The kernel admits a registration against the catalogue, or reports
  why it does not.
* **Nothing a leaf says is believed.** Its answers cross the port as JSON, are decoded by the
  kernel in the operation's declared result form or rejected as malformed, and are only ever
  compared with the acceptance suite's expected values. No denotation, proof, identification,
  evidence or status comes from a leaf, and none can be written.
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
