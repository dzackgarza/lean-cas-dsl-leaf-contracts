/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Registry.Extension

@[expose] public section

/-!
# The leaf contract (CC-ADAPTER, spec §5)

A backend leaf contributes through one Lean command, `register_leaf`, and only:

1. realizations of already-registered categories (`realizer`);
2. actions of already-registered functors on those realizations (`action`);
3. realizations of already-registered operations and decision procedures (`implementation`,
   `decider`), and registered isomorphisms between realized objects (`isomorphism`);
4. codecs — which live in the realizer's denotation and the decoders that produce its handles.

Each is checked by the registry's own validators, so it must typecheck against the semantic
universe. Everything else a backend might want to say is a *forbidden contribution*: it can be
written down (so that the attempt is visible) but `register_leaf` rejects it, naming the §5 rule,
and registers nothing from that leaf. New semantics come from `lean-categories` and the semantic
registry, never from a backend package (rule 5).
-/

open Lean Meta Elab Command

namespace CasCatalogue

/-- One contribution a backend leaf may attempt. -/
inductive LeafContribution
  -- Permitted.
  | realizer (entry : RealizerEntry)
  | action (entry : FunctorActionEntry)
  | implementation (entry : ImplementationEntry)
  | decider (entry : DeciderEntry)
  | isomorphism (entry : HandleIsoEntry)
  /-- The presentation of the apex of a registered limit on a realization. -/
  | limitRealization (entry : LimitRealizationEntry)
  /-- A category's equality of morphisms, decided on a realization. -/
  | equality (entry : EqualityEntry)
  /-- A backend's answer to a registered semantic operation, with its decoder. -/
  | backendOperation (entry : BackendOperationEntry)
  /-- Handles presenting the values of a registered object, with their identifications. -/
  | presentation (entry : PresentationEntry)
  /-- The reading of handles as literals, with proofs. -/
  | observation (entry : ObservationEntry)
  -- Forbidden (spec §5).
  /-- A public category because the backend library has a class. -/
  | category (entry : NamedCategoryEntry)
  /-- A method attached to a mathematical object. -/
  | method (entry : MethodEntry)
  /-- A property presentation, i.e. a method-like predicate. -/
  | property (entry : PropertyEntry)
  /-- A superclass or subcategory relation. -/
  | subcategory (entry : ClassifierEntry)
  /-- A forgetful route: a structural functor. -/
  | forgetfulRoute (entry : FunctorEntry)
  /-- An identification of two presentations (a coherence between routes). -/
  | identification (entry : CellEntry)
  /-- A public coercion between two categories. -/
  | coercion (source target : CategoryExpr)
  /-- A refinement of an object's semantic type after construction. -/
  | refineObject (handle : Name) (classifier : ClassifierId)
  /-- A backend-specific result class. -/
  | resultClass (name : String)
  /-- Generic subobject, kernel or image semantics. -/
  | genericSemantics (entry : LiftEntry)
  /-- A natural transformation between registered functors: new semantics. -/
  | naturalTransformation (entry : CellEntry)

/-- The §5 rule a forbidden contribution violates, or `none` if it is permitted. -/
def LeafContribution.violation : LeafContribution → Option String
  | .realizer _ | .action _ | .implementation _ | .decider _ | .isomorphism _
  | .limitRealization _ | .equality _ | .backendOperation _ | .presentation _ | .observation _ => none
  | .category e => some s!"§5: a backend leaf cannot invent a public category ({e.id.raw}); \
      categories are registered from lean-categories"
  | .method e => some s!"§5: a backend leaf cannot attach a method to a mathematical object \
      ({e.id.raw}); methods name registered functors"
  | .property e => some s!"§5: a backend leaf cannot attach a method to a mathematical object \
      ({e.id.raw}); properties are owned by classifiers"
  | .subcategory e => some s!"§5: a backend leaf cannot declare a superclass or subcategory \
      relation ({e.id.raw})"
  | .forgetfulRoute e => some s!"§5: a backend leaf cannot create an implicit forgetful route \
      ({e.id.raw})"
  | .identification e => some s!"§5: a backend leaf cannot decide that two presentations are the \
      same ({e.id.raw}); coherence is registered mathematics"
  | .coercion _ _ => some "§5: a backend leaf cannot add public coercions"
  | .refineObject handle classifier => some s!"§5: a backend leaf cannot refine an object's \
      semantic type after construction ({handle} into {classifier.raw}); properties are \
      decided, not assigned"
  | .resultClass name => some s!"§5: a backend leaf cannot expose backend-specific result \
      classes ({name}); results decode into the operation's semantic result type"
  | .genericSemantics e => some s!"§5: a backend leaf cannot define generic subgroup, kernel or \
      image semantics ({e.id.raw})"
  | .naturalTransformation e => some s!"§5: a backend leaf cannot declare a natural \
      transformation ({e.id.raw}); cells are registered from lean-categories"

/-- The registry row of a permitted contribution. -/
def LeafContribution.entry? : LeafContribution → Option RegistryEntry
  | .realizer e => some (.realizer e)
  | .action e => some (.action e)
  | .implementation e => some (.implementation e)
  | .decider e => some (.decider e)
  | .isomorphism e => some (.handleIso e)
  | .limitRealization e => some (.limitRealization e)
  | .equality e => some (.equality e)
  | .backendOperation e => some (.backendOperation e)
  | .presentation e => some (.presentation e)
  | .observation e => some (.observation e)
  | _ => none

/-- A backend leaf's contract. -/
structure LeafContract where
  backend : String
  contributions : List LeafContribution

/-- Check a leaf contract: every contribution permitted, and each permitted row valid against the
semantic universe. Throws on the first violation, before anything is registered. -/
def LeafContract.check (contract : LeafContract) : MetaM (Array RegistryEntry) := do
  let mut entries := #[]
  for contribution in contract.contributions do
    if let some rule := contribution.violation then
      throwError "leaf {contract.backend}: {rule}"
    let some entry := contribution.entry? | unreachable!
    validateRegistryEntryDeclaration entry
    entries := entries.push entry
  return entries

/-- Check a leaf contract, then register its rows: all of them or none. The rows are first
registered in a discarded environment, so a row may depend on an earlier one of the same contract
(an isomorphism of a realizer's handles), and a failure registers nothing. -/
def registerLeaf (contract : LeafContract) : MetaM Unit := do
  for contribution in contract.contributions do
    if let some rule := contribution.violation then
      throwError "leaf {contract.backend}: {rule}"
  let entries := contract.contributions.filterMap (·.entry?)
  withoutModifyingEnv do
    for entry in entries do addLeafRegistryEntryChecked entry
  for entry in entries do addLeafRegistryEntryChecked entry

/--
`register_leaf { backend := "sage", contributions := [ … ] }` registers a backend leaf's
contributions, rejecting any forbidden one with the §5 rule it violates.
-/
syntax (name := registerLeafCommand) "register_leaf " term : command

elab_rules : command
  | `(register_leaf $contract) => do
      let command ← `(run_cmd liftTermElabM do registerLeaf $contract)
      elabCommand command

end CasCatalogue
