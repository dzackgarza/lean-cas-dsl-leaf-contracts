import Lake
open Lake DSL

/-
The leaf contract of `lean-cas-dsl`: the one interface a computational leaf is written against
(`lean-cas-dsl/specs/leaf-registration.md`). A leaf is a manifest of registrations (operation id,
input form, backend) and the programs it names (`CasContract.Registration`); the kernel talks to
a program over the port protocol (`CasContract.Port`) and reports its failures by stratum
(`CasContract.Failure`). The kernel reads `lean-categories`' semantic registry itself; nothing
here describes a catalogue row. A leaf ships no Lean and imports nothing; it contains no
mathematics (that is `lean-categories`') and can neither see nor change the acceptance suite it
is measured by (that is `lean-cas-dsl`'s). The kernel of `lean-cas-dsl` owns this contract and
releases it; see `AGENTS.md`.
-/
package «cas_leaf_contracts» where
  version := v!"0.1.0"

require lean_categories from git
  "https://github.com/dzackgarza/lean-categories" @ "main"

@[default_target]
lean_lib CasContract where
  globs := #[.andSubmodules `CasContract]
  leanOptions := #[
    ⟨`relaxedAutoImplicit, false⟩,
    ⟨`weak.linter.mathlibStandardSet, true⟩,
    ⟨`weak.linter.style.header, false⟩,
    ⟨`maxSynthPendingDepth, (3 : Nat)⟩]

lean_lib AxiomAudit
