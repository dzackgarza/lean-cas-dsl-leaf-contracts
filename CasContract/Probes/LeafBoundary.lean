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
before the contract refused every module outside a leaf package (`lean-cas-dsl/specs/architecture.md`,
"What must be impossible").

* A leaf is registered only from a leaf package: a permitted contribution written here (a module
  of the contract) is refused, naming the leaf repository.
* Each forbidden contribution (spec §5) is refused, naming its rule; a contract with one forbidden
  contribution registers nothing; a realizer of an unregistered category is refused.
* A leaf cannot register a natural transformation (cells are `lean-categories`').
* A leaf module's direct imports are its intake contract: a leaf importing core internals is refused.
* Semantic rows are written only in `lean-categories`, from any other module.
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

/-! ### Forbidden contributions (spec §5) -/

run_cmd liftTermElabM do
  let expectRule (contribution : LeafContribution) (rule : String) : MetaM Unit := do
    let contract : LeafContract := { backend := "probe-sage", contributions := [contribution] }
    try
      discard <| contract.check
      throwError "a forbidden contribution was accepted: {rule}"
    catch err =>
      let message ← err.toMessageData.toString
      unless (message.splitOn rule).length > 1 do
        throwError "the rejection does not name the rule '{rule}': {message}"
  let state ← registryState
  let some groups := state.categories.find? (·.id.raw == "cat.groups")
    | throwError "cat.groups is not registered"
  expectRule (.category { groups with id := ⟨"cat.probe.sage_group_class"⟩ })
    "cannot invent a public category"
  let order : MethodEntry :=
    { id := ⟨"meth.probe.order"⟩, name := "order", owner := groups.expression,
      functor := FunctorId.groupsMonoid, shape := .object }
  expectRule (.method order) "cannot attach a method"
  let isAbelian : PropertyEntry :=
    { id := ⟨"prop.probe.is_abelian"⟩, name := "IsAbelian",
      classifier := ClassifierId.magmasCommutative }
  expectRule (.property isAbelian) "cannot attach a method"
  let abelian : ClassifierEntry :=
    { id := ⟨"clf.probe.abelian"⟩, declaration := `x, host := groups.expression,
      realization := `x }
  expectRule (.subcategory abelian) "cannot declare a superclass or subcategory relation"
  let some groupsMonoid := state.functor? FunctorId.groupsMonoid
    | throwError "fun.groups.monoid is not registered"
  expectRule (.forgetfulRoute { groupsMonoid with id := ⟨"fun.probe.groups_to_sets"⟩ })
    "cannot create an implicit forgetful route"
  let some comparison := state.cells.find? (·.invertible)
    | throwError "no comparison is registered"
  expectRule (.identification comparison) "cannot decide that two presentations are the same"
  expectRule (.coercion groups.expression Foundation.Sets) "cannot add public coercions"
  expectRule (.resultClass "SageKernelSubgroup") "cannot expose backend-specific result classes"
  let some lift := state.lifts[0]? | throwError "no lift is registered"
  expectRule (.genericSemantics lift) "cannot define generic subgroup, kernel or image"
  -- A permitted contribution must still typecheck against the semantic universe.
  let orphan : LeafContract :=
    { backend := "probe-sage", contributions := [.realizer
        { id := ⟨"rz.probe.orphan"⟩, category := ⟨"cat.probe.unregistered"⟩,
          backend := "probe-sage", denotation := `LeanCategories.Algebra.Magmas }] }
  if (← try discard orphan.check; pure true catch _ => pure false) then
    throwError "a realizer of an unregistered category was accepted"
  -- A contract with one forbidden contribution registers nothing.
  let before := (← registryState).realizers.size
  let mixed : LeafContract :=
    { backend := "probe-sage", contributions := [.realizer
        { id := ⟨"rz.probe.mixed"⟩, category := ⟨"cat.magmas"⟩, backend := "probe-sage",
          denotation := `LeanCategories.Algebra.Magmas }, .resultClass "SageRing"] }
  unless ← rejectsAs `CasLeaves.Probe "backend-specific result classes" (registerLeaf mixed) do
    throwError "a contract with a forbidden contribution was accepted"
  unless (← registryState).realizers.size == before do
    throwError "a rejected contract registered part of itself"

/- The command fails to elaborate on a forbidden contribution, naming the rule. -/
/--
error: leaf probe-sage: §5: a backend leaf cannot expose backend-specific result classes
(SageKernelSubgroup); results decode into the operation's semantic result type
-/
#guard_msgs (whitespace := lax) in
register_leaf { backend := "probe-sage", contributions := [.resultClass "SageKernelSubgroup"] }

/-! ### A leaf cannot register a natural transformation -/

run_cmd liftTermElabM do
  let leafCell : LeafContract :=
    { backend := "probe", contributions := [.naturalTransformation
        { id := ⟨"cell.probe.leaf"⟩, source := Foundation.Sets, target := Foundation.Sets
          left := #[], right := #[.functor FunctorId.setsList]
          declaration := `LeanCategories.Foundation.listUnit }] }
  unless ← rejectsAs `CasLeaves.Probe "natural transformation" (registerLeaf leafCell) do
    throwError "a leaf registered a cell"

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

end CasCatalogue.ContractProbes
