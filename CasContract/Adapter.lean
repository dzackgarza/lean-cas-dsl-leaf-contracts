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
universe. Nothing else can be said. The contribution type has exactly the realization forms, so a
category, method, property, subcategory, forgetful route, identification, coercion, refinement,
result class, generic semantics or natural transformation cannot be written in a leaf contract at
all. A rejection list could be shortened; an absent constructor cannot be used. New semantics come
from `lean-categories` and the semantic registry, never from a backend package (rule 5).
-/

open Lean Meta Elab Command

namespace CasCatalogue

/-- One contribution of a backend leaf: a realization of already registered mathematics, and
nothing else (spec §5). -/
inductive LeafContribution
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

/-- The registry row of a contribution. -/
def LeafContribution.entry : LeafContribution → RegistryEntry
  | .realizer e => .realizer e
  | .action e => .action e
  | .implementation e => .implementation e
  | .decider e => .decider e
  | .isomorphism e => .handleIso e
  | .limitRealization e => .limitRealization e
  | .equality e => .equality e
  | .backendOperation e => .backendOperation e
  | .presentation e => .presentation e
  | .observation e => .observation e

/-- A backend leaf's contract. -/
structure LeafContract where
  backend : String
  contributions : List LeafContribution

/-- Check a leaf contract: each row valid against the semantic universe. Throws on the first
invalid row, before anything is registered. -/
def LeafContract.check (contract : LeafContract) : MetaM (Array RegistryEntry) := do
  let mut entries := #[]
  for contribution in contract.contributions do
    validateRegistryEntryDeclaration contribution.entry
    entries := entries.push contribution.entry
  return entries

/-- Check a leaf contract, then register its rows: all of them or none. The rows are first
registered in a discarded environment, so a row may depend on an earlier one of the same contract
(an isomorphism of a realizer's handles), and a failure registers nothing. -/
def registerLeaf (contract : LeafContract) : MetaM Unit := do
  let entries := contract.contributions.map (·.entry)
  withoutModifyingEnv do
    for entry in entries do addLeafRegistryEntryChecked entry
  for entry in entries do addLeafRegistryEntryChecked entry

/--
`register_leaf { backend := "sage", contributions := [ … ] }` registers a backend leaf's
realizations: all of them, or none if one is invalid.
-/
syntax (name := registerLeafCommand) "register_leaf " term : command

elab_rules : command
  | `(register_leaf $contract) => do
      let command ← `(run_cmd liftTermElabM do registerLeaf $contract)
      elabCommand command

end CasCatalogue
