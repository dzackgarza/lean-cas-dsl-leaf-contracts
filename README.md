# The leaf contract of lean-cas-dsl

[`lean-cas-dsl/specs/architecture.md`](https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/architecture.md)
owns the separation of concerns. This repository is one part of the `lean-cas-dsl` kernel: the
interface a computational leaf is written against, published on its own so that a leaf depends on
nothing else of the kernel.

| Package | Depends on | Owns |
| --- | --- | --- |
| `lean-categories` | Mathlib | all mathematics, including the semantic registry (the catalogue) |
| `lean-cas-dsl-leaf-contracts` (this) | `lean-categories` | the realization registry and its validation, realized actions, decisions and limits, the backend port protocol, `register_leaf` |
| `lean-cas-dsl-leaves` | this, `lean-categories` | realizations only |
| `lean-cas-dsl` | all three | the kernel's resolution and propagation, the language, the permanent tests, the harness |

* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl` and merged to
  `main`, which the leaves and `lean-cas-dsl` track. A leaf never changes this contract to fit itself.
* **No mathematics.** Every category, functor, operation and coherence a realization refers to is
  a row of `lean-categories`' catalogue. A realization row is validated against it here.
* **No tests.** The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a
  leaf can reach, contains or names it.
* **What a leaf may import:** `CasContract.Leaf`, `lean-categories` (with the catalogue), Mathlib,
  and its own root (`leafImportAllowed`). `register_leaf` and the harness both enforce it.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The Python
reference implementation of the port protocol is `python/cas_port.py`; `Backend.connect` puts it
on every adapter's `PYTHONPATH`.

Every `require` tracks `main`. `just test-ci` builds on Mathlib's prebuilt cache and runs the
kernel-axiom audit (`AxiomAudit.lean`); the commit and push tiers compile nothing.
