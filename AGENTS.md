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
| `lean-cas-dsl` | this, `lean-categories` (its current dependency on the leaves is a defect: `gov-no-leaves-here`) | the kernel's resolution and propagation, the language, the permanent tests |

* **Authors.** Only the orchestrator writes here. Leaves are written against this contract by the
  leaf subagent, which never edits it, never reads the tests, and never edits `lean-categories`
  (`lean-cas-dsl/specs/architecture.md`, "Authors: one role per agent").
* **Relaxing the contract is almost never the fix.** A leaf that cannot meet the contract means
  one of two things:
  - the leaf is wrong, which is a finding against the leaf;
  - mathematics is missing, which is a formalization request to `lean-categories`.
  
  The contract changes only with a mathematical justification from the formalization author,
  recorded with the change. It never changes to fit a leaf's representation or programming needs.
* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl`, released, and
  re-pinned by the leaves and by `lean-cas-dsl`. A leaf never changes this contract to fit itself.
* **No partial maps (LC-14), no operation without its structure (LC-16).** A realization realizes
  a total operation on its domain object. No row here accepts an optional, undefined or default
  result.
* **No mathematics.** Every category, functor, operation and coherence a realization refers to is
  a row of `lean-categories`' catalogue. A realization row is validated against it here.
* **No tests.** The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a
  leaf can reach, contains or names it.
* **What a leaf may import:** `CasContract.Leaf`, `lean-categories` (with the catalogue), Mathlib,
  and its own root (`leafImportAllowed`). `register_leaf` and the harness both enforce it.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The Python
reference implementation of the port protocol is `python/cas_port.py`; `Backend.connect` puts it
on every adapter's `PYTHONPATH`.

Build: `lake build`, with the same Lean toolchain and `lean-categories` pin as `lean-cas-dsl`.
