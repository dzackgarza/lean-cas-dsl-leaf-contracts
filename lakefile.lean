import Lake
open Lake DSL

/-
The leaf contract of `lean-cas-dsl`: the one interface a computational leaf is written against.
It owns the realization registry (the schema and validation of realization rows against the
semantic rows of `lean-categories`' catalogue), the realized actions, decisions and limits a leaf
supplies, the backend port protocol, and `register_leaf`. It contains no mathematics (that is
`lean-categories`') and no acceptance test (those are `lean-cas-dsl`'s): a leaf package depends on
this package and `lean-categories` only, so it can neither see nor change the tests it is measured
by. The kernel of `lean-cas-dsl` owns this contract and releases it; see `AGENTS.md`.
-/
package «cas_leaf_contracts» where
  version := v!"0.1.0"

require lean_categories from git
  "https://github.com/dzackgarza/lean-categories" @ "c73ebffcc2103b518c1daa0625ccf08a2637513a"

@[default_target]
lean_lib CasContract where
  globs := #[.andSubmodules `CasContract]
  leanOptions := #[
    ⟨`relaxedAutoImplicit, false⟩,
    ⟨`weak.linter.mathlibStandardSet, true⟩,
    ⟨`weak.linter.style.header, false⟩,
    ⟨`maxSynthPendingDepth, (3 : Nat)⟩]
