/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Adapter
public import CasContract.Leaf
public import LeanCategories.Catalogue
public meta import CasContract.Adapter
public meta import CasContract.Leaf
public meta import LeanCategories.Catalogue

@[expose] public section

/-!
# The contract's refusals

What `register_leaf` and the leaf write path refuse, tested here, where the contract lives. These
tests are the contract's own: they were in `lean-cas-dsl`'s probes, which could register leaves
before the contract refused every module outside a leaf package
(`lean-cas-dsl/specs/architecture.md`, "What must be impossible").

* A leaf is registered only from a leaf package: a permitted contribution written here (a module
  of the contract) is refused, naming the leaf repository.
* The leaf interface has exactly the realization forms (spec §5): no forbidden contribution can be
  written. A realizer of an unregistered category is refused.
* A leaf module's direct imports are its intake contract: a leaf importing core internals is
  refused.
* Semantic rows are written only in `lean-categories`, from any other module.
* A presentation identifies the denotation of the handle it returns with the object: a handle
  returned beside an isomorphism that is not about it (`∅` beside `ℕ ≅ ℕ`) is refused.
-/

open Lean Meta Elab Term Command

namespace CasCatalogue.ContractProbes

/-- Run `action` as though elaborating the module `module`; succeed iff it throws an error
containing `fragment`. -/
def rejectsAs (module : Name) (fragment : String) (action : MetaM Unit) : MetaM Bool := do
  let env ← getEnv
  try
    withEnv (env.setMainModule module) action
    return false
  catch e =>
    return ((← e.toMessageData.toString).splitOn fragment).length > 1

/-- A realizer row of an already-registered category (its denotation is irrelevant to what is
tested: every case below is refused before it is read), and a semantic row. -/
def realizerRow : RegistryEntry := .realizer
  { id := ⟨"rz.probe.contract"⟩, category := ⟨"cat.magmas"⟩, backend := "probe"
    denotation := `LeanCategories.Algebra.Magmas }
def categoryRow : RegistryEntry := .category
  { id := ⟨"cat.probe.contract"⟩, declaration := `LeanCategories.Algebra.Magmas
    expression := .atom ⟨"cat.probe.contract"⟩
    realization := `CasCatalogue.Algebra.CatalogueRegistration.magmasRealization }

/-! ### A leaf is registered only from a leaf package -/

run_cmd liftTermElabM do
  for module in [`CasContract.Probe, `CasCatalogue.Probe, `CasAcceptance.Probe, `CasDsl.Probe,
      `CasDslTests.Probe, `CasTools.Probe, `LeanCategories.Probe] do
    unless ← rejectsAs module "not of a leaf package" (addLeafRegistryEntryChecked realizerRow) do
      throwError "a leaf row was registered from {module}"

/- This module is the contract's: a permitted contribution written here is refused. -/
/--
error: leaf row rz.probe.contract_command: CasContract.Probes.LeafBoundary is a module of CasContract,
not of a leaf package; a leaf is written only in a leaf package (lean-cas-dsl-leaves, or another
package under its own root) against the contract, never in lean-cas-dsl or the core
-/
#guard_msgs (whitespace := lax) in
register_leaf
  { backend := "probe"
    contributions := [.realizer
      { id := ⟨"rz.probe.contract_command"⟩, category := ⟨"cat.magmas"⟩, backend := "probe"
        denotation := `LeanCategories.Algebra.Magmas }] }

/-! ### The leaf interface has exactly the realization forms (spec §5)

A category, method, property, subcategory, forgetful route, identification, coercion, refinement,
result class, generic semantics or natural transformation has no constructor in
`LeafContribution`, so no leaf contract can state one. -/

run_cmd liftTermElabM do
  let some (.inductInfo info) := (← getEnv).find? ``LeafContribution
    | throwError "LeafContribution is not an inductive type"
  let forms := info.ctors.map fun c => c.getString!
  let realizations := ["realizer", "action", "implementation", "decider", "isomorphism",
    "limitRealization", "equality", "backendOperation", "presentation", "observation"]
  unless forms == realizations do
    throwError "the leaf interface has forms other than realizations: {forms}"
  -- A permitted contribution must still typecheck against the semantic universe.
  let orphan : Leaf :=
    { backend := "probe-sage", contributions := [.realizer
        { id := ⟨"rz.probe.orphan"⟩, category := ⟨"cat.probe.unregistered"⟩,
          backend := "probe-sage", denotation := `LeanCategories.Algebra.Magmas }] }
  if (← try discard orphan.check; pure true catch _ => pure false) then
    throwError "a realizer of an unregistered category was accepted"
/-! ### A leaf's imports, and semantic rows -/

#guard leafImportViolations #[`CasContract.Leaf, `CasLeaves.Algebra.Actions,
  `Mathlib.Algebra.Group.Defs, `LeanCategories.Foundation.Mathlib] == #[]
-- A leaf of another package (root `Ext`) has only its intake contract: not another package's
-- leaves, not the acceptance suite.
#guard leafImportViolations #[`CasContract.Leaf, `Ext.Engine, `LeanCategories.Catalogue.Syntax,
  `CasLeaves.Foundation.FiniteSets, `CasAcceptance.Standard] `Ext ==
    #[`CasLeaves.Foundation.FiniteSets, `CasAcceptance.Standard]
#guard leafImportViolations #[`CasContract.Leaf, `CasContract.Registry.Extension,
  `CasCatalogue.Resolve] == #[`CasContract.Registry.Extension, `CasCatalogue.Resolve]

run_cmd liftTermElabM do
  -- This module's imports include the contract's internals: as a leaf module, it is refused.
  unless ← rejectsAs `CasLeaves.Probe "imports core-internal modules"
      (addLeafRegistryEntryChecked realizerRow) do
    throwError "a leaf importing core internals registered a row"
  -- Semantic rows are written only in `lean-categories`.
  for module in [`CasLeaves.Probe, `Notebook.Session, `CasCatalogue.Probe, `CasAcceptance.Probe] do
    unless ← rejectsAs module "is not a `lean-categories` module"
        (addRegistryEntryChecked categoryRow) do
      throwError "a semantic row was written in {module}"
  unless ← rejectsAs `CasLeaves.Probe "contributes only realizers"
      (addLeafRegistryEntryChecked categoryRow) do
    throwError "the leaf write path accepted a semantic row"

/-! ### A presentation identifies its own handle -/

/-- Two handles, denoting `ℕ` and `∅`. -/
def probeDenotation : CategoryTheory.Functor (CategoryTheory.Discrete Bool)
    LeanCategories.Foundation.Mathlib.Sets.{0} :=
  CategoryTheory.Discrete.functor fun b => if b then (ℕ : Type) else PEmpty

/-- The handle denoting `∅`, returned with the identity `ℕ ≅ ℕ`: not a presentation of `ℕ`. -/
def presentDisconnected :
    Σ _h : CategoryTheory.Discrete Bool,
      CasCatalogue.Foundation.Objects.naturals ≅ CasCatalogue.Foundation.Objects.naturals :=
  ⟨⟨false⟩, CategoryTheory.Iso.refl _⟩

/-- The handle denoting `ℕ`, with the identification of its denotation. -/
def presentConnected :
    Σ h : CategoryTheory.Discrete Bool,
      probeDenotation.obj h ≅ CasCatalogue.Foundation.Objects.naturals :=
  ⟨⟨true⟩, CategoryTheory.Iso.refl _⟩

run_cmd liftTermElabM do
  let state ← registryState
  let realizer : RealizerEntry :=
    { id := ⟨"rz.probe.presented"⟩, category := ⟨"cat.sets"⟩, backend := "probe"
      denotation := `CasCatalogue.ContractProbes.probeDenotation }
  let state := { state with realizers := state.realizers.push realizer }
  let row (name : Name) : PresentationEntry :=
    { id := ⟨"pres.probe.naturals"⟩, object := ⟨"obj.sets.naturals"⟩
      realizer := realizer.id, presentation := name }
  let refused ← try
      validatePresentation state (row `CasCatalogue.ContractProbes.presentDisconnected)
      pure false
    catch e =>
      pure (((← e.toMessageData.toString).splitOn "does not identify the denotation").length > 1)
  unless refused do
    throwError "a presentation whose isomorphism is not about its handle was accepted"
  validatePresentation state (row `CasCatalogue.ContractProbes.presentConnected)

end CasCatalogue.ContractProbes
