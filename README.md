# The leaf contract of lean-cas-dsl

[`lean-cas-dsl/specs/architecture.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/architecture.md)
owns the separation of concerns. This repository is one part of the `lean-cas-dsl` kernel: the
declared type a computational leaf is written against, published on its own so that a leaf depends
on nothing else of the kernel.

| Package | Depends on | Owns |
| --- | --- | --- |
| `lean-categories` | Mathlib | all mathematics, including the semantic registry (the catalogue) |
| `lean-cas-dsl-leaf-contracts` (this) | `lean-categories` | the form of a leaf registration (operation, input form, opaque implementation), the declared input and result forms of registered operations, the backend port protocol, the failure strata of a call |
| `lean-cas-dsl-leaves` | this, `lean-categories` | registrations of opaque implementations only: no mathematics, no Lean |
| `lean-cas-dsl` | all three | the kernel's resolution and propagation, the language, the permanent tests, the harness |

* **Nothing from a leaf is trusted.** A leaf registration names a registered operation and an
  input form, and supplies an opaque implementation computing the operation's declared result
  form. The system runs it and believes nothing about it. A leaf ships no mathematics and no Lean:
  no proof, denotation, identification of values, decision evidence, status, trust level,
  certificate or checker.
* **The contract is the type at the firewall.** On the leaf side anything goes that meets the
  type this contract declares. Only answers cross, and an answer is checked against the formal
  side, the permanent acceptance suite of `lean-cas-dsl`, never believed.
* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl` and merged to
  `main`, which the leaves and `lean-cas-dsl` track. A leaf never changes this contract to fit itself.
* **No mathematics.** Every operation a registration names is a row of `lean-categories`'
  catalogue, and its input and result forms are declared from that row.
* **No tests.** The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a
  leaf can reach, contains, names or runs it.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The Python
reference implementation of the port protocol is `python/cas_port.py`; `Backend.connect` puts it
on every adapter's `PYTHONPATH`.

Every `require` tracks `main`. `just test-ci` builds on Mathlib's prebuilt cache and runs the
kernel-axiom audit of this repository's own code (`AxiomAudit.lean`); the commit and push tiers
compile nothing.

The contract's code does not yet have this form; its replacement is tracked by the plan node
`gov-leaf-authority` in `lean-cas-dsl/specs/computational-core-plan.md`.
