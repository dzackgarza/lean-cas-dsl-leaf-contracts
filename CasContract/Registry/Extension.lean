/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import LeanCategories.Catalogue.Registry.Semantic
public import CasContract.Registry.Entry
public import CasContract.Action
public import CasContract.Decide
public import Lean.Data.Json
public import Lean

@[expose] public section

set_option backward.privateInPublic true

/-!
# The registry: `lean-categories`' semantic registry and the realization registry

The semantic rows are `lean-categories`' (`LeanCategories.Catalogue.Registry.Semantic`), read here
from the pinned release; this repository writes none (`specs/architecture.md`). This module adds
the realization registry: realizers, actions, implementations, deciders, isomorphisms of realized
objects, limit realizations, equalities and backend operations, each validated against the
semantics it realizes, and written only through `register_leaf`. `RegistryState` is the two
together.
-/

namespace CasCatalogue
open LeanCategories

open Lean
open Lean Meta
open Lean Elab Command

inductive RegistryEntry
  | category (e : NamedCategoryEntry)
  | categoryFamily (e : CategoryFamilyEntry)
  | classifier (e : ClassifierEntry)
  | functor (e : FunctorEntry)
  | opaque (e : OpaqueCategoryEntry)
  | fibration (e : FibrationEntry)
  | constructor (e : ConstructorEntry)
  | action (e : FunctorActionEntry)
  | method (e : MethodEntry)
  | property (e : PropertyEntry)
  | decider (e : DeciderEntry)
  | lift (e : LiftEntry)
  | realizer (e : RealizerEntry)
  | implementation (e : ImplementationEntry)
  | handleIso (e : HandleIsoEntry)
  | cell (e : CellEntry)
  | limit (e : LimitEntry)
  | limitRealization (e : LimitRealizationEntry)
  | adjunction (e : AdjunctionEntry)
  | equality (e : EqualityEntry)
  | backendOperation (e : BackendOperationEntry)
  | object (e : ObjectEntry)
  | presentation (e : PresentationEntry)
  | literal (e : LiteralEntry)
  | numeral (e : NumeralEntry)
  | graphLiteral (e : GraphLiteralEntry)
  | morphism (e : MorphismEntry)
  | operation (e : OperationEntry)
  | inclusion (e : InclusionEntry)
  | powerObject (e : PowerObjectEntry)
  | observation (e : ObservationEntry)
  deriving Repr

/-- Stable identifier represented by a heterogeneous registry entry. -/
def RegistryEntry.stableId : RegistryEntry → String
  | .category e => e.id.raw
  | .categoryFamily e => e.id.raw
  | .classifier e => e.id.raw
  | .functor e => e.id.raw
  | .opaque e => e.id.raw
  | .fibration e => e.id.raw
  | .constructor e => e.id.raw
  | .action e => e.id.raw
  | .method e => e.id.raw
  | .property e => e.id.raw
  | .decider e => e.id.raw
  | .lift e => e.id.raw
  | .realizer e => e.id.raw
  | .implementation e => e.id.raw
  | .handleIso e => e.id.raw
  | .cell e => e.id.raw
  | .limit e => e.id.raw
  | .limitRealization e => e.id.raw
  | .adjunction e => e.id.raw
  | .equality e => e.id.raw
  | .backendOperation e => e.id.raw
  | .object e => e.id.raw
  | .presentation e => e.id.raw
  | .literal e => e.id.raw
  | .numeral e => e.id.raw
  | .graphLiteral e => e.id.raw
  | .morphism e => e.id.raw
  | .operation e => e.id.raw
  | .inclusion e => e.id.raw
  | .powerObject e => e.id.raw
  | .observation e => e.id.raw

/-- Lean declarations that must resolve before this row can be persisted. -/
def RegistryEntry.declarations : RegistryEntry → Array Name
  | .category e => #[e.declaration, e.realization] ++ match e.refinementRealization with
      | some realization => #[realization]
      | none => #[]
  | .categoryFamily e => #[e.realization, e.transport]
  | .classifier e => #[e.declaration, e.realization]
  | .functor e => #[e.declaration, e.realization]
  | .opaque e => #[e.declaration, e.realization] ++
      e.ports.flatMap fun p => #[p.declaration, p.realization]
  | .fibration e => #[e.evidence]
  | .constructor e => #[e.semantics] ++ e.functorialAction.toArray
  | .action e => #[e.realization]
  | .method _ => #[]
  | .property _ => #[]
  | .decider e => #[e.realization]
  | .lift e => #[e.evidence]
  | .realizer e => #[e.denotation] ++ e.fullyFaithful.toArray
  | .implementation e => #[e.realization]
  | .handleIso e => #[e.source, e.target, e.evidence]
  | .cell e => #[e.declaration]
  | .limit e => #[e.declaration]
  | .limitRealization e => #[e.realization]
  | .adjunction e => #[e.declaration]
  | .equality e => #[e.realization]
  | .backendOperation e => #[e.decoder]
  | .object e => #[e.declaration]
  | .presentation e => #[e.presentation]
  | .literal e => #[e.type, e.denotation]
  | .numeral e => #[e.declaration]
  | .graphLiteral e => #[e.denotation]
  | .morphism e => #[e.declaration]
  | .operation e => #[e.declaration]
  | .inclusion e => #[e.declaration, e.mono]
  | .powerObject e =>
      #[e.truth, e.member, e.transpose, e.extent, e.empty, e.singleton, e.terminal, e.image]
  | .observation e => #[e.observe]


/-- A semantic row, as a registry row. -/
def RegistryEntry.ofSemantic : SemanticEntry → RegistryEntry
  | .category e => .category e
  | .categoryFamily e => .categoryFamily e
  | .classifier e => .classifier e
  | .functor e => .functor e
  | .opaque e => .opaque e
  | .fibration e => .fibration e
  | .constructor e => .constructor e
  | .method e => .method e
  | .property e => .property e
  | .lift e => .lift e
  | .cell e => .cell e
  | .limit e => .limit e
  | .adjunction e => .adjunction e
  | .object e => .object e
  | .literal e => .literal e
  | .numeral e => .numeral e
  | .graphLiteral e => .graphLiteral e
  | .morphism e => .morphism e
  | .operation e => .operation e
  | .inclusion e => .inclusion e
  | .powerObject e => .powerObject e

/-- The semantic row a registry row is, if it is one. -/
def RegistryEntry.toSemantic? : RegistryEntry → Option SemanticEntry
  | .category e => some (.category e)
  | .categoryFamily e => some (.categoryFamily e)
  | .classifier e => some (.classifier e)
  | .functor e => some (.functor e)
  | .opaque e => some (.opaque e)
  | .fibration e => some (.fibration e)
  | .constructor e => some (.constructor e)
  | .method e => some (.method e)
  | .property e => some (.property e)
  | .lift e => some (.lift e)
  | .cell e => some (.cell e)
  | .limit e => some (.limit e)
  | .adjunction e => some (.adjunction e)
  | .object e => some (.object e)
  | .literal e => some (.literal e)
  | .numeral e => some (.numeral e)
  | .graphLiteral e => some (.graphLiteral e)
  | .morphism e => some (.morphism e)
  | .operation e => some (.operation e)
  | .inclusion e => some (.inclusion e)
  | .powerObject e => some (.powerObject e)
  | _ => none

/-- The realization rows. -/
structure RealizationState where
  actions : Array FunctorActionEntry := #[]
  deciders : Array DeciderEntry := #[]
  realizers : Array RealizerEntry := #[]
  implementations : Array ImplementationEntry := #[]
  handleIsos : Array HandleIsoEntry := #[]
  limitRealizations : Array LimitRealizationEntry := #[]
  equalities : Array EqualityEntry := #[]
  backendOperations : Array BackendOperationEntry := #[]
  presentations : Array PresentationEntry := #[]
  observations : Array ObservationEntry := #[]
  deriving Inhabited

/-- The registry: the imported semantic registry and the realization rows. -/
structure RegistryState extends SemanticState, RealizationState
  deriving Inhabited

instance : Coe RegistryState SemanticState := ⟨RegistryState.toSemanticState⟩

private def RealizationState.apply : RealizationState → RegistryEntry → RealizationState
  | s, .action e => { s with actions := s.actions.push e }
  | s, .decider e => { s with deciders := s.deciders.push e }
  | s, .realizer e => { s with realizers := s.realizers.push e }
  | s, .implementation e => { s with implementations := s.implementations.push e }
  | s, .handleIso e => { s with handleIsos := s.handleIsos.push e }
  | s, .limitRealization e => { s with limitRealizations := s.limitRealizations.push e }
  | s, .equality e => { s with equalities := s.equalities.push e }
  | s, .backendOperation e => { s with backendOperations := s.backendOperations.push e }
  | s, .presentation e => { s with presentations := s.presentations.push e }
  | s, .observation e => { s with observations := s.observations.push e }
  | s, _ => s

/-- Every row: the semantic rows, then the realization rows. -/
def RegistryState.registryEntries (state : RegistryState) : List RegistryEntry :=
  state.toSemanticState.entries.map RegistryEntry.ofSemantic ++
    state.actions.toList.map RegistryEntry.action ++
    state.deciders.toList.map RegistryEntry.decider ++
    state.realizers.toList.map RegistryEntry.realizer ++
    state.implementations.toList.map RegistryEntry.implementation ++
    state.handleIsos.toList.map RegistryEntry.handleIso ++
    state.limitRealizations.toList.map RegistryEntry.limitRealization ++
    state.equalities.toList.map RegistryEntry.equality ++
    state.backendOperations.toList.map RegistryEntry.backendOperation ++
    state.presentations.toList.map RegistryEntry.presentation ++
    state.observations.toList.map RegistryEntry.observation

/-- Whether this row's stable ID conflicts with a registered row. -/
def RegistryState.hasEntryId (state : RegistryState) (entry : RegistryEntry) : Bool :=
  match entry.toSemantic? with
  | some e => state.toSemanticState.hasEntryId e
  | none => state.registryEntries.any (·.stableId == entry.stableId)

private initialize realizationExt : SimplePersistentEnvExtension RegistryEntry RealizationState ←
  registerSimplePersistentEnvExtension {
    addEntryFn := RealizationState.apply
    addImportedFn := fun as => mkStateFromImportedEntries RealizationState.apply {} as
}

/-- Every realization row names registered semantics. -/
def validateRealizationReferences (state : RegistryState) : Except String Unit := do
  for action in state.actions do
    unless action.edge.isRegisteredIn state do
      throw s!"action entry {action.id.raw} realizes an unregistered functor"
  for realization in state.limitRealizations do
    unless state.limits.any (·.id == realization.limit) do
      throw s!"limit realization {realization.id.raw} names an unregistered limit"
  for operation in state.backendOperations do
    unless state.limits.any (·.id.raw == operation.operation) ||
        state.methods.any (·.id.raw == operation.operation) do
      throw s!"backend operation {operation.id.raw} names an unregistered operation"
  for equality in state.equalities do
    unless state.realizers.any (·.id == equality.realizer) do
      throw s!"equality entry {equality.id.raw} names an unregistered realizer"
  for presentation in state.presentations do
    unless state.objects.any (·.id == presentation.object) do
      throw s!"presentation {presentation.id.raw} names an unregistered object"
  for decider in state.deciders do
    unless (state.classifier? decider.classifier).isSome do
      throw s!"decider entry {decider.id.raw} names an unregistered classifier"

/-- The registry of the current environment, read-only: `lean-categories`' semantic rows and the
realization rows. The only write path of this repository is `register_leaf`. -/
def registryState : CoreM RegistryState := do
  return { toSemanticState := ← semanticState, toRealizationState := realizationExt.getState (← getEnv) }

/-- An action row's realization must be a `RealizedAction F dC dD` whose functor `F` is an
instance of its edge's Mathlib functor (CC-ACTION). -/
def validateActionRealization (state : RegistryState) (e : FunctorActionEntry) : MetaM Unit := do
  let registered ← state.edgeFunctor e.edge
  let realizationConstant ← mkConstWithFreshMVarLevels e.realization
  let (_, _, realizationType) ← forallMetaTelescopeReducing (← inferType realizationConstant)
  let realizationType ← whnfR realizationType
  unless realizationType.isAppOfArity ``CasCatalogue.RealizedAction 11 do
    throwError "action {e.id.raw} realization {e.realization} is not a RealizedAction"
  let realizedFunctor := realizationType.getAppArgs[8]!
  unless ← withTransparency .all <| isDefEq realizedFunctor registered do
    throwError
      "action {e.id.raw} realization {e.realization} does not realize {e.edge.label}"

/-- A decider row's realization must be a `Decider c d` for exactly its registered classifier. -/
def validateDecider (state : RegistryState) (e : DeciderEntry) : MetaM Unit := do
  let some classifier := state.classifier? e.classifier
    | throwError "decider {e.id.raw} names an unregistered classifier {e.classifier.raw}"
  let expected ← classifierInstance classifier
  let realization ← mkConstWithFreshMVarLevels e.realization
  let (_, _, type) ← forallMetaTelescopeReducing (← inferType realization)
  let type ← whnfR type
  unless type.isAppOfArity ``CasCatalogue.Decider 5 do
    throwError "decider {e.id.raw}: {e.realization} is not a Decider"
  unless ← withTransparency .all <| isDefEq type.getAppArgs[1]! expected do
    throwError "decider {e.id.raw}: {e.realization} decides a different property than \
      {e.classifier.raw}"

/-- A realizer row's denotation must land in its registered category (CC-SEP). -/
def validateRealizer (state : RegistryState) (e : RealizerEntry) : MetaM Unit := do
  let some category := state.categories.find? (·.id == e.category)
    | throwError "realizer {e.id.raw} names an unregistered category {e.category.raw}"
  let denotation ← mkConstWithFreshMVarLevels e.denotation
  let (_, _, type) ← forallMetaTelescopeReducing (← inferType denotation)
  let type ← whnfR type
  unless type.isAppOfArity ``CategoryTheory.Functor 4 do
    throwError "realizer {e.id.raw}: {e.denotation} is not a denotation functor (handles ⥤ C)"
  unless ← withTransparency .all <| isDefEq type.getAppArgs[2]! (← categoryCarrierInstance category) do
    throwError "realizer {e.id.raw}: {e.denotation} does not denote into {e.category.raw}"
  if let some witness := e.fullyFaithful then
    let witnessType ← whnfR (← inferType (← mkConstWithFreshMVarLevels witness))
    unless witnessType.isAppOf ``CategoryTheory.Functor.FullyFaithful do
      throwError "realizer {e.id.raw}: {witness} is not a FullyFaithful witness"
    unless ← withTransparency .all <| isDefEq witnessType.appArg! (mkAppN denotation #[]) do
      throwError "realizer {e.id.raw}: {witness} is not about its denotation"

/-- A limit realization row names a registered limit and a registered realizer, and its
realization returns an apex handle with an identification (a dependent pair). -/
def validateLimitRealization (state : RegistryState) (e : LimitRealizationEntry) :
    MetaM Unit := do
  unless state.limits.any (·.id == e.limit) do
    throwError "limit realization {e.id.raw} names an unregistered limit {e.limit.raw}"
  unless state.realizers.any (·.id == e.realizer) do
    throwError "limit realization {e.id.raw} names an unregistered realizer {e.realizer.raw}"
  if let some liftId := e.lift then
    let some lift := state.lifts.find? (·.id == liftId)
      | throwError "limit realization {e.id.raw} names an unregistered lift {liftId.raw}"
    let some limit := state.limits.find? (·.id == e.limit) | unreachable!
    unless lift.kind == .createsLimits limit.shape do
      throwError "limit realization {e.id.raw}: {liftId.raw} does not create {limit.shape} limits"
    let some edge := state.structuralEdge? lift.edge
      | throwError "limit realization {e.id.raw}: {liftId.raw} is not along a structural step"
    unless (state.category? edge.target).any (·.id == limit.category) do
      throwError "limit realization {e.id.raw}: {liftId.raw} does not land in {limit.category.raw}"
    let some realizer := state.realizers.find? (·.id == e.realizer) | unreachable!
    unless (state.category? edge.source).any (·.id == realizer.category) do
      throwError "limit realization {e.id.raw}: {e.realizer.raw} does not realize the source of \
        {liftId.raw}"
  let realization ← mkConstWithFreshMVarLevels e.realization
  let (_, _, type) ← forallMetaTelescopeReducing (← inferType realization)
  unless (← whnfR type).isAppOf ``Sigma do
    throwError "limit realization {e.id.raw}: {e.realization} does not return an apex handle \
      with its identification"

/-- A presentation row's `presentation` returns, for parameters, a handle of its realizer with an
identification of its denotation with the registered object's value at the same parameters. -/
def validatePresentation (state : RegistryState) (e : PresentationEntry) : MetaM Unit := do
  let some object := state.objects.find? (·.id == e.object)
    | throwError "presentation {e.id.raw} names an unregistered object {e.object.raw}"
  let some realizer := state.realizers.find? (·.id == e.realizer)
    | throwError "presentation {e.id.raw} names an unregistered realizer {e.realizer.raw}"
  unless realizer.category == object.category do
    throwError "presentation {e.id.raw}: {e.realizer.raw} does not realize {object.category.raw}"
  let presentation ← mkConstWithFreshMVarLevels e.presentation
  let (args, _, type) ← forallMetaTelescopeReducing (← inferType presentation)
  let type ← whnfR type
  unless type.isAppOfArity ``Sigma 2 do
    throwError "presentation {e.id.raw}: {e.presentation} does not return a handle with its \
      identification"
  let identification ← whnfR (← inferType (← mkAppM ``Sigma.snd #[mkAppN presentation args]))
  unless identification.isAppOfArity ``CategoryTheory.Iso 4 do
    throwError "presentation {e.id.raw}: {e.presentation} does not identify its handle"
  let declared ← mkConstWithFreshMVarLevels object.declaration
  let (objectArgs, _, _) ← forallMetaTelescopeReducing (← inferType declared)
  unless objectArgs.size == args.size do
    throwError "presentation {e.id.raw}: {e.presentation} does not take {object.id.raw}'s \
      parameters"
  for (a, b) in args.zip objectArgs do
    discard <| isDefEq a b
  unless ← withTransparency .all <|
      isDefEq identification.getAppArgs[3]! (mkAppN declared objectArgs) do
    throwError "presentation {e.id.raw}: {e.presentation} does not present {object.id.raw}"
  -- The identification is of the returned handle's own denotation: the type is exactly
  -- `Σ h : H, d.obj h ≅ X`, so an isomorphism `X ≅ X` beside an unrelated handle is refused.
  let denotation ← mkConstWithFreshMVarLevels realizer.denotation
  let (denotationArgs, _, _) ← forallMetaTelescopeReducing (← inferType denotation)
  let denotation := mkAppN denotation denotationArgs
  let handles := (← whnfR (← inferType denotation)).getAppArgs[0]!
  let expected ← withLocalDeclD `h handles fun h => do
    let denoted ← mkAppM ``Prefunctor.obj
      #[← mkAppM ``CategoryTheory.Functor.toPrefunctor #[denotation], h]
    mkLambdaFVars #[h] (← mkAppM ``CategoryTheory.Iso #[denoted, mkAppN declared objectArgs])
  unless ← withTransparency .all <| isDefEq type.getAppArgs[1]! expected do
    throwError "presentation {e.id.raw}: {e.presentation} does not identify the denotation of \
      the handle it returns with {object.id.raw}: its type must be `Σ h, d.obj h ≅ X`"

/-- An observation row's `observe` reads each handle of its realizer as a literal of the registered
literal form of the realizer's category, with the proof that the handle denotes it. -/
def validateObservation (state : RegistryState) (e : ObservationEntry) : MetaM Unit := do
  let some realizer := state.realizers.find? (·.id == e.realizer)
    | throwError "observation {e.id.raw} names an unregistered realizer {e.realizer.raw}"
  let some literal := state.literals.find? (·.id == e.literal)
    | throwError "observation {e.id.raw} names an unregistered literal form {e.literal.raw}"
  unless literal.category == realizer.category do
    throwError "observation {e.id.raw}: {e.literal.raw} is not a literal form of \
      {realizer.category.raw}"
  let denotation ← mkConstWithFreshMVarLevels realizer.denotation
  let (args, _, _) ← forallMetaTelescopeReducing (← inferType denotation)
  let denotation := mkAppN denotation args
  let handles := (← whnfR (← inferType denotation)).getAppArgs[0]!
  let expected ← withLocalDeclD `h handles fun h => do
    let denoted ← mkAppM ``Prefunctor.obj
      #[← mkAppM ``CategoryTheory.Functor.toPrefunctor #[denotation], h]
    let body ← withLocalDeclD `l (mkConst literal.type) fun l => do
      mkLambdaFVars #[l] (← mkEq denoted (mkApp (← mkConstWithFreshMVarLevels literal.denotation) l))
    mkForallFVars #[h] (← mkAppM ``Subtype #[body])
  let observe ← mkConstWithFreshMVarLevels e.observe
  unless ← withTransparency .all <| isDefEq (← inferType observe) expected do
    throwError "observation {e.id.raw}: {e.observe} is not `(h : handles) → \
      \{ l : {literal.type} // d.obj h = {literal.denotation} l }`"

/-- A backend operation row keys a registered limit or method, and its decoder returns an
`Except String` of the decoded result. -/
def validateBackendOperation (state : RegistryState) (e : BackendOperationEntry) :
    MetaM Unit := do
  unless state.limits.any (·.id.raw == e.operation) || state.methods.any (·.id.raw == e.operation) do
    throwError "backend operation {e.id.raw}: {e.operation} is not a registered semantic operation"
  let decoder ← mkConstWithFreshMVarLevels e.decoder
  let (_, _, type) ← forallMetaTelescopeReducing (← inferType decoder)
  let type ← whnfR type
  let isDecoder ← if type.isAppOfArity ``Except 2 then isDefEq type.appFn!.appArg! (mkConst ``String)
    else pure false
  unless isDecoder do
    throwError "backend operation {e.id.raw}: {e.decoder} is not a decoder (… → Except String τ)"

/-- An equality row names a `HomEquality` for exactly its realizer's denotation. -/
def validateEquality (state : RegistryState) (e : EqualityEntry) : MetaM Unit := do
  let some realizer := state.realizers.find? (·.id == e.realizer)
    | throwError "equality {e.id.raw} names an unregistered realizer {e.realizer.raw}"
  let realization ← mkConstWithFreshMVarLevels e.realization
  let (_, _, type) ← forallMetaTelescopeReducing (← inferType realization)
  let type ← whnfR type
  unless type.isAppOf ``CasCatalogue.HomEquality do
    throwError "equality {e.id.raw}: {e.realization} is not a HomEquality"
  let denotation ← mkConstWithFreshMVarLevels realizer.denotation
  let (args, _, _) ← forallMetaTelescopeReducing (← inferType denotation)
  unless ← withTransparency .all <| isDefEq type.appArg! (mkAppN denotation args) do
    throwError "equality {e.id.raw}: {e.realization} decides equality on another realization \
      than {e.realizer.raw}"

/-- A fused implementation must be typed by exactly the semantic composite it claims: its route
functor is the route's composite and its method functor the method's (CC-ROUTE). With no proof it
can only be a trusted assertion (CC-TRUST). -/
def validateImplementation (state : RegistryState) (e : ImplementationEntry) : MetaM Unit := do
  let some method := state.methods.find? (·.id == e.method)
    | throwError "implementation {e.id.raw} names an unregistered method {e.method.raw}"
  let some methodFunctor := state.functor? method.functor
    | throwError "implementation {e.id.raw}: its method has no registered functor"
  unless method.shape == .isoInvariant do
    throwError "implementation {e.id.raw}: fused implementations are typed for iso-invariant \
      methods"
  let realization ← mkConstWithFreshMVarLevels e.realization
  let (_, _, type) ← forallMetaTelescopeReducing (← inferType realization)
  let type ← whnfR type
  -- The status is fixed by the evidence: no proof is a trusted assertion, a checker proved sound
  -- is certificate-checked; nothing else may be claimed.
  if type.isAppOfArity ``CasCatalogue.TrustedImplementation 14 then
    unless e.trust == .trustedAssertion do
      throwError "implementation {e.id.raw}: an unproved implementation is a trusted assertion"
  else if type.isAppOfArity ``CasCatalogue.CertifiedImplementation 14 then
    unless e.trust == .certificateChecked do
      throwError "implementation {e.id.raw}: a certified implementation is certificate-checked"
  else
    throwError "implementation {e.id.raw}: {e.realization} is neither a TrustedImplementation \
      nor a CertifiedImplementation"
  let args := type.getAppArgs
  unless ← withTransparency .all <| isDefEq args[10]! (← state.routeFunctor e.route) do
    throwError "implementation {e.id.raw} does not realize its route"
  unless ← withTransparency .all <|
      isDefEq args[11]! (← registeredFunctorInstance methodFunctor) do
    throwError "implementation {e.id.raw} does not realize its method"

/-- A registered isomorphism must be an isomorphism `source ≅ target` in the handle category of
its realizer, between exactly its source and target handles (CC-CARRIER). -/
def validateHandleIso (state : RegistryState) (e : HandleIsoEntry) : MetaM Unit := do
  let some realizer := state.realizers.find? (·.id == e.realizer)
    | throwError "isomorphism {e.id.raw} names an unregistered realizer {e.realizer.raw}"
  let evidence ← mkConstWithFreshMVarLevels e.evidence
  let type ← whnfR (← inferType evidence)
  unless type.isAppOfArity ``CategoryTheory.Iso 4 do
    throwError "isomorphism {e.id.raw}: {e.evidence} is not an isomorphism of handles"
  let denotationType ← whnfR (← inferType (← mkConstWithFreshMVarLevels realizer.denotation))
  let args := type.getAppArgs
  let checks := #[(args[0]!, denotationType.getAppArgs[0]!, "realizer"),
    (args[2]!, ← mkConstWithFreshMVarLevels e.source, "source"),
    (args[3]!, ← mkConstWithFreshMVarLevels e.target, "target")]
  for (actual, expected, what) in checks do
    unless ← withTransparency .all <| isDefEq actual expected do
      throwError "isomorphism {e.id.raw}: its evidence is not about its {what}"


/-- Inspect declaration types before atomically persisting a row: a semantic row by
`lean-categories`' validators, a realization row against the registry it realizes. -/
def validateRegistryEntryDeclaration (entry : RegistryEntry) : MetaM Unit := do
  let state ← registryState
  match entry with
  | .action e => validateActionRealization state e
  | .decider e => validateDecider state e
  | .realizer e => validateRealizer state e
  | .implementation e => validateImplementation state e
  | .handleIso e => validateHandleIso state e
  | .limitRealization e => validateLimitRealization state e
  | .equality e => validateEquality state e
  | .backendOperation e => validateBackendOperation state e
  | .presentation e => validatePresentation state e
  | .observation e => validateObservation state e
  | entry => match entry.toSemantic? with
    | some e => validateSemanticEntryDeclaration e
    | none => pure ()

/-! ### Who may write the registry (CC-ADAPTER, CC-SEP)

Semantics — categories, functors, classifiers, methods, properties, comparisons, lifts, families,
fibrations, constructors — are registered only in `lean-categories` (`addSemanticEntryChecked`);
this repository writes none. A backend leaf (`CasLeaves`) contributes only realizers,
actions, implementations, deciders and isomorphisms of realized objects, only through
`register_leaf`, and imports only the leaf API `CasContract.Leaf`, the registered semantics
(`LeanCategories.Catalogue.Semantics.*`), other leaves, Mathlib and `lean-categories`. The module a row is written in is read from the environment, so the rule
holds whatever path the row takes. -/

/-- The library roots that write realization rows besides the leaves: the leaf contract, and
`lean-cas-dsl`'s kernel and acceptance probes. -/
def realizationAuthorRoots : List Name := [`CasContract, `CasCatalogue, `CasAcceptance]

/-- The library root of the backend leaves (`lean-cas-dsl-leaves`). -/
def leafRoot : Name := `CasLeaves

/-- The leaf API: the one core module a leaf imports. -/
def leafApiModule : Name := `CasContract.Leaf

/-- The row kinds a backend leaf may contribute (spec §5, permitted contributions 1–4). -/
def RegistryEntry.isLeafContribution : RegistryEntry → Bool
  | .realizer _ | .action _ | .implementation _ | .decider _ | .handleIso _
  | .limitRealization _ | .equality _ | .backendOperation _ | .presentation _ | .observation _ => true
  | _ => false

/-- The registered semantics a leaf realizes; public to leaves. -/
def semanticsRoot : Name := `LeanCategories.Catalogue.Semantics

/-- A direct import a leaf module may have: its intake contract, i.e. the leaf API and the pinned
catalogue with the mathematics (Mathlib, `lean-categories`), and its own package (`own`, its root).
A leaf never imports the acceptance suite, the kernel, or another package's leaves; none of them is
even a dependency of a leaf package (`lean-cas-dsl-leaves` depends on this contract and
`lean-categories` only). -/
def leafImportAllowed (module : Name) (own : Name := leafRoot) : Bool :=
  module == leafApiModule ||
    [semanticsRoot, own, `Mathlib, `LeanCategories, `Init].any (·.isPrefixOf module)

/-- The direct imports of a leaf module that it may not have. -/
def leafImportViolations (imports : Array Name) (own : Name := leafRoot) : Array Name :=
  imports.filter (!leafImportAllowed · own)

/-- The notebook's roots: it registers nothing (`CasDslTests.Boundary`). -/
def notebookRoots : List Name := [`CasDsl, `CasDslTests]

/-- The roots of `lean-cas-dsl` and of this contract: the kernel, the language, the tests, the
notebook and the tools. No leaf is written under any of them: a leaf is written in a leaf package,
under its own root, against this contract (`lean-cas-dsl/specs/architecture.md`). -/
def nonLeafRoots : List Name :=
  realizationAuthorRoots ++ notebookRoots ++ [`CasTools] ++ semanticAuthorRoots

/-- Whether a module is a leaf: any module outside the core, its probes, the notebook and
`lean-categories`. Leaves may live in other packages (`research`), under their own root. -/
def isLeafModule (module : Name) : Bool :=
  !nonLeafRoots.contains module.getRoot

/- Validate the elaborated declaration and persist exactly one realization row. -/
private def persistRealizationEntry (entry : RegistryEntry) : MetaM Unit := do
  validateRegistryEntryDeclaration entry
  let env ← getEnv
  let state ← registryState
  if state.hasEntryId entry then
    throwError "duplicate registry ID: {entry.stableId}"
  for declaration in entry.declarations do
    if declaration.isAnonymous then
      throwError "registry entry {entry.stableId} has no declaration name"
    if (env.find? declaration).isNone then
      throwError "registry entry {entry.stableId} refers to unknown declaration {declaration}"
  modifyEnv (realizationExt.addEntry · entry)

/-- A semantic row cannot be written here: it is `lean-categories`' (`addSemanticEntryChecked`),
which refuses every module outside `lean-categories`. -/
def addRegistryEntryChecked (entry : RegistryEntry) : MetaM Unit := do
  match entry.toSemantic? with
  | some e => addSemanticEntryChecked e
  | none => throwError "registry row {entry.stableId}: a realization row is contributed by a leaf, \
      through `register_leaf`"

/-- Register one row of a backend leaf: a permitted contribution, written in a leaf module whose
direct imports are the leaf API, other leaves and the mathematics. A module of the kernel, the
language, the tests, the notebook, the tools or `lean-categories` cannot register one: a leaf is
never written there. -/
def addLeafRegistryEntryChecked (entry : RegistryEntry) : MetaM Unit := do
  let env ← getEnv
  let module := env.mainModule
  let root := module.getRoot
  unless isLeafModule module do
    throwError "leaf row {entry.stableId}: {module} is a module of {root}, not of a leaf package; \
      a leaf is written only in a leaf package (lean-cas-dsl-leaves, or another package under its \
      own root) against the contract, never in lean-cas-dsl or the core"
  unless entry.isLeafContribution do
    throwError "leaf row {entry.stableId}: a backend leaf contributes only realizers, actions, \
      implementations, deciders and isomorphisms (spec §5)"
  let bad := leafImportViolations (env.header.imports.map (·.module)) root
  unless bad.isEmpty do
    throwError "leaf module {module} imports core-internal modules {bad.toList}; a leaf \
      imports only {leafApiModule}, {semanticsRoot}.*, other leaves, Mathlib and lean-categories"
  persistRealizationEntry entry

/-- Every registry row, grouped by the imported module that wrote it. -/
def registryRowsByModule (env : Environment) : Array (Name × Array RegistryEntry) :=
  env.header.moduleNames.mapIdx fun index module =>
    (module, realizationExt.getModuleEntries env index ++
      (semanticRowsByModule env)[index]!.2.map RegistryEntry.ofSemantic)

/-- Violations of the leaf boundary among the imported modules: a leaf module with a forbidden
direct import or a non-leaf row, and a row written outside the core, its probes and the leaves. -/
def leafBoundaryViolations (env : Environment) : Array String := Id.run do
  let mut violations := #[]
  for (module, rows) in registryRowsByModule env do
    let root := module.getRoot
    -- A leaf: every module of this repository's leaves, and any other module writing rows.
    if leafRoot.isPrefixOf module || (isLeafModule module && !rows.isEmpty) then
      if let some index := env.getModuleIdx? module then
        let imports := env.header.moduleData[index.toNat]!.imports.map (·.module)
        for bad in leafImportViolations imports root do
          violations := violations.push s!"{module} imports {bad}"
      for row in rows do
        unless row.isLeafContribution do
          violations := violations.push s!"{module} registers the semantic row {row.stableId}"
    else if notebookRoots.contains root then
      for row in rows do
        violations := violations.push s!"{module} (the notebook) registers {row.stableId}"
  return violations

private def registryObject (fields : List (String × Json)) : Json := Json.mkObj fields

structure RegistryManifestParameter where
  ids : Array String
  name : String
  kind : String
  dependency : Option Nat
  deriving DecidableEq, Repr, ToJson, FromJson

inductive RegistryManifestParameterExpr
  | variable (id : String)
  | apply (operation : String) (argument : RegistryManifestParameterExpr)
  | apply2 (operation : String) (left right : RegistryManifestParameterExpr)
  | apply3 (operation : String)
      (first second third : RegistryManifestParameterExpr)
  deriving DecidableEq, Repr

private def registryManifestParameterExprJson : RegistryManifestParameterExpr → Json
  | .variable id => registryObject [("tag", "variable"), ("id", id)]
  | .apply operation argument => registryObject [
      ("tag", "apply"), ("operation", operation),
      ("argument", registryManifestParameterExprJson argument)]
  | .apply2 operation left right => registryObject [
      ("tag", "apply2"), ("operation", operation),
      ("left", registryManifestParameterExprJson left),
      ("right", registryManifestParameterExprJson right)]
  | .apply3 operation first second third => registryObject [
      ("tag", "apply3"), ("operation", operation),
      ("first", registryManifestParameterExprJson first),
      ("second", registryManifestParameterExprJson second),
      ("third", registryManifestParameterExprJson third)]

instance : ToJson RegistryManifestParameterExpr where
  toJson := registryManifestParameterExprJson

private partial def registryManifestParameterExprOfJson : Json → Except String RegistryManifestParameterExpr :=
  fun j => do
    let tag ← j.getObjValAs? String "tag"
    match tag with
    | "variable" => .variable <$> j.getObjValAs? String "id"
    | "apply" => .apply <$> j.getObjValAs? String "operation" <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "argument")
    | "apply2" => .apply2 <$> j.getObjValAs? String "operation" <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "left") <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "right")
    | "apply3" => .apply3 <$> j.getObjValAs? String "operation" <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "first") <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "second") <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "third")
    | _ => throw s!"unknown parameter expression tag: {tag}"

instance : FromJson RegistryManifestParameterExpr where
  fromJson? := registryManifestParameterExprOfJson

mutual

inductive RegistryManifestConstructorArg
  | category (category : RegistryManifestCategoryExpr)
  | object (id : String)
  | functor (id : String)

inductive RegistryManifestCategoryExpr
  | atom (id : String)
  | familyApp (family : String) (args : Array RegistryManifestParameterExpr)
  | classifierTotal (classifier : String)
  | refine (base : RegistryManifestCategoryExpr) (classifier : String)
  | opaque (id : String)
  | familyTotal (family : String)
  | construct (constructor : String) (args : Array RegistryManifestConstructorArg)

end

deriving instance BEq, Repr for RegistryManifestConstructorArg, RegistryManifestCategoryExpr

private partial def registryManifestCategoryExprJson : RegistryManifestCategoryExpr → Json
  | .atom id => registryObject [("tag", "atom"), ("id", id)]
  | .familyApp family args => registryObject [
      ("tag", "familyApp"), ("family", family), ("args", toJson args)]
  | .classifierTotal classifier => registryObject [
      ("tag", "classifierTotal"), ("classifier", classifier)]
  | .refine base classifier => registryObject [
      ("tag", "refine"), ("base", registryManifestCategoryExprJson base),
      ("classifier", classifier)]
  | .opaque id => registryObject [("tag", "opaque"), ("id", id)]
  | .familyTotal family => registryObject [("tag", "familyTotal"), ("family", family)]
  | .construct constructor args => registryObject [
      ("tag", "construct"), ("constructor", constructor),
      ("args", Json.arr (args.map fun
        | .category category => registryObject [
            ("tag", "category"), ("category", registryManifestCategoryExprJson category)]
        | .object id => registryObject [("tag", "object"), ("id", id)]
        | .functor id => registryObject [("tag", "functor"), ("id", id)]))]

instance : ToJson RegistryManifestCategoryExpr where
  toJson := registryManifestCategoryExprJson

instance : Inhabited RegistryManifestCategoryExpr := ⟨.atom ""⟩

/-- Decode a constructor argument, given the category-expression decoder. -/
private def constructorArgOfJson
    (category : Json → Except String RegistryManifestCategoryExpr) (arg : Json) :
    Except String RegistryManifestConstructorArg := do
  match ← arg.getObjValAs? String "tag" with
  | "category" => .category <$> category (← arg.getObjValAs? Json "category")
  | "object" => .object <$> arg.getObjValAs? String "id"
  | "functor" => .functor <$> arg.getObjValAs? String "id"
  | tag => throw s!"unknown constructor argument tag: {tag}"

private partial def registryManifestCategoryExprOfJson : Json → Except String RegistryManifestCategoryExpr :=
  fun j => do
    let tag ← j.getObjValAs? String "tag"
    match tag with
    | "atom" => .atom <$> j.getObjValAs? String "id"
    | "familyApp" => .familyApp <$> j.getObjValAs? String "family" <*> j.getObjValAs? _ "args"
    | "classifierTotal" => .classifierTotal <$> j.getObjValAs? String "classifier"
    | "refine" => .refine <$> registryManifestCategoryExprOfJson (← j.getObjValAs? Json "base") <*> j.getObjValAs? String "classifier"
    | "opaque" => .opaque <$> j.getObjValAs? String "id"
    | "familyTotal" => .familyTotal <$> j.getObjValAs? String "family"
    | "construct" => do
        let constructor ← j.getObjValAs? String "constructor"
        let args ← j.getObjValAs? (Array Json) "args"
        let args ← args.mapM (constructorArgOfJson registryManifestCategoryExprOfJson)
        pure (.construct constructor args)
    | _ => throw s!"unknown category expression tag: {tag}"

instance : FromJson RegistryManifestCategoryExpr where
  fromJson? := registryManifestCategoryExprOfJson

inductive RegistryManifestFunctorExpr
  | identity (category : RegistryManifestCategoryExpr)
  | atomic (id : String)
  | classifierForget (classifier : String) (host : RegistryManifestCategoryExpr)
  | opaquePort (id : String)
  | familyFibreInclusion (family : String) (args : Array RegistryManifestParameterExpr)
  | familyReindex (family morphism : String)
      (source target : Array RegistryManifestParameterExpr)
  | comp (left right : RegistryManifestFunctorExpr)
  | constructMap (constructor : String) (functor : RegistryManifestFunctorExpr)
  deriving BEq, Repr

private partial def registryManifestFunctorExprJson : RegistryManifestFunctorExpr → Json
  | .identity category => registryObject [("tag", "identity"), ("category", toJson category)]
  | .atomic id => registryObject [("tag", "atomic"), ("id", id)]
  | .classifierForget classifier host => registryObject [
      ("tag", "classifierForget"), ("classifier", classifier), ("host", toJson host)]
  | .opaquePort id => registryObject [("tag", "opaquePort"), ("id", id)]
  | .familyFibreInclusion family args => registryObject [
      ("tag", "familyFibreInclusion"), ("family", family), ("args", toJson args)]
  | .familyReindex family morphism source target => registryObject [
      ("tag", "familyReindex"), ("family", family), ("morphism", morphism),
      ("source", toJson source), ("target", toJson target)]
  | .comp left right => registryObject [
      ("tag", "comp"), ("left", registryManifestFunctorExprJson left),
      ("right", registryManifestFunctorExprJson right)]
  | .constructMap constructor functor => registryObject [
      ("tag", "constructMap"), ("constructor", constructor),
      ("functor", registryManifestFunctorExprJson functor)]

instance : ToJson RegistryManifestFunctorExpr where
  toJson := registryManifestFunctorExprJson

private partial def registryManifestFunctorExprOfJson : Json → Except String RegistryManifestFunctorExpr
  | j => do
    let tag ← j.getObjValAs? String "tag"
    match tag with
    | "identity" => .identity <$> j.getObjValAs? _ "category"
    | "atomic" => .atomic <$> j.getObjValAs? String "id"
    | "classifierForget" =>
        .classifierForget <$> j.getObjValAs? String "classifier" <*> j.getObjValAs? _ "host"
    | "opaquePort" => .opaquePort <$> j.getObjValAs? String "id"
    | "familyFibreInclusion" =>
        .familyFibreInclusion <$> j.getObjValAs? String "family" <*> j.getObjValAs? _ "args"
    | "familyReindex" =>
        .familyReindex <$> j.getObjValAs? String "family" <*> j.getObjValAs? String "morphism"
          <*> j.getObjValAs? _ "source" <*> j.getObjValAs? _ "target"
    | "comp" => .comp <$> (registryManifestFunctorExprOfJson (← j.getObjValAs? _ "left")) <*>
        (registryManifestFunctorExprOfJson (← j.getObjValAs? _ "right"))
    | "constructMap" => .constructMap <$> j.getObjValAs? String "constructor" <*>
        (registryManifestFunctorExprOfJson (← j.getObjValAs? _ "functor"))
    | _ => throw s!"unknown functor expression tag: {tag}"

instance : FromJson RegistryManifestFunctorExpr where
  fromJson? := registryManifestFunctorExprOfJson

structure RegistryManifestCategory where
  id : String
  declaration : String
  realization : String
  refinementRealization : String
  expression : RegistryManifestCategoryExpr
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestFamily where
  id : String
  schema : String
  realization : String
  transport : String
  parameters : Array RegistryManifestParameter
  variance : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestClassifier where
  id : String
  host : RegistryManifestCategoryExpr
  declaration : String
  realization : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestFunctor where
  id : String
  source : RegistryManifestCategoryExpr
  target : RegistryManifestCategoryExpr
  declaration : String
  realization : String
  expression : RegistryManifestFunctorExpr
  structural : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestPort where
  id : String
  source : RegistryManifestCategoryExpr
  target : RegistryManifestCategoryExpr
  declaration : String
  realization : String
  provenance : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestOpaque where
  id : String
  declaration : String
  realization : String
  reason : String
  ports : Array RegistryManifestPort
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestFibration where
  id : String
  projection : String
  variance : String
  evidence : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestConstructor where
  id : String
  signature : Array String
  semantics : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestAction where
  id : String
  functor : String
  realization : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestMethod where
  id : String
  name : String
  owner : RegistryManifestCategoryExpr
  functor : String
  shape : String
  returnsToSource : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestCell where
  id : String
  source : RegistryManifestCategoryExpr
  target : RegistryManifestCategoryExpr
  left : Array String
  right : Array String
  declaration : String
  invertible : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestLimit where
  id : String
  category : String
  shape : String
  declaration : String
  colimit : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestLimitRealization where
  id : String
  limit : String
  realizer : String
  realization : String
  lift : Option String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestBackendOperation where
  id : String
  backend : String
  operation : String
  decoder : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestObject where
  id : String
  category : String
  declaration : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestPresentation where
  id : String
  object : String
  realizer : String
  presentation : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestEquality where
  id : String
  realizer : String
  realization : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestAdjunction where
  id : String
  left : String
  right : String
  declaration : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestProperty where
  id : String
  name : String
  classifier : String
  receiver : Option RegistryManifestCategoryExpr
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestDecider where
  id : String
  classifier : String
  realization : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestLift where
  id : String
  edge : String
  evidence : String
  kind : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestRealizer where
  id : String
  category : String
  denotation : String
  backend : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestImplementation where
  id : String
  method : String
  route : Array String
  realization : String
  backend : String
  trust : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestHandleIso where
  id : String
  realizer : String
  source : String
  target : String
  evidence : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifest where
  schemaVersion : String
  categories : Array RegistryManifestCategory
  classifiers : Array RegistryManifestClassifier
  functors : Array RegistryManifestFunctor
  opaqueCategories : Array RegistryManifestOpaque
  categoryFamilies : Array RegistryManifestFamily
  fibrations : Array RegistryManifestFibration
  constructors : Array RegistryManifestConstructor
  actions : Array RegistryManifestAction
  methods : Array RegistryManifestMethod
  properties : Array RegistryManifestProperty
  deciders : Array RegistryManifestDecider
  lifts : Array RegistryManifestLift
  realizers : Array RegistryManifestRealizer
  implementations : Array RegistryManifestImplementation
  handleIsos : Array RegistryManifestHandleIso
  cells : Array RegistryManifestCell
  limits : Array RegistryManifestLimit
  limitRealizations : Array RegistryManifestLimitRealization
  adjunctions : Array RegistryManifestAdjunction
  equalities : Array RegistryManifestEquality
  backendOperations : Array RegistryManifestBackendOperation
  objects : Array RegistryManifestObject
  presentations : Array RegistryManifestPresentation
  source : String
  deriving BEq, Repr, ToJson, FromJson

private def registryManifestParameterExpr : ParameterExpr → RegistryManifestParameterExpr
  | .variable id => .variable id.raw
  | .apply operation argument => .apply operation.raw (registryManifestParameterExpr argument)
  | .apply2 operation left right =>
      .apply2 operation.raw (registryManifestParameterExpr left) (registryManifestParameterExpr right)
  | .apply3 operation first second third =>
      .apply3 operation.raw (registryManifestParameterExpr first)
        (registryManifestParameterExpr second) (registryManifestParameterExpr third)

private partial def registryManifestCategoryExpr : CategoryExpr → RegistryManifestCategoryExpr
  | .atom id => .atom id.raw
  | .familyApp family args => .familyApp family.raw (args.map registryManifestParameterExpr)
  | .classifierTotal classifier => .classifierTotal classifier.raw
  | .refine base classifier => .refine (registryManifestCategoryExpr base) classifier.raw
  | .opaque id => .opaque id.raw
  | .familyTotal family => .familyTotal family.raw
  | .construct constructor args => .construct constructor.raw (args.map fun
      | .category category => .category (registryManifestCategoryExpr category)
      | .object id => .object id.raw
      | .functor id => .functor id.raw)

private def registryManifestFunctorExpr {source target : CategoryExpr} :
    FunctorExpr source target → RegistryManifestFunctorExpr
  | .identity category => .identity (registryManifestCategoryExpr category)
  | .atomic id => .atomic id.raw
  | .classifierForget classifier host =>
      .classifierForget classifier.raw (registryManifestCategoryExpr host)
  | .opaquePort id => .opaquePort id.raw
  | .familyFibreInclusion family args =>
      .familyFibreInclusion family.raw (args.map registryManifestParameterExpr)
  | .familyReindex family morphism source target =>
      .familyReindex family.raw morphism.raw (source.map registryManifestParameterExpr)
        (target.map registryManifestParameterExpr)
  | .comp left right => .comp (registryManifestFunctorExpr left) (registryManifestFunctorExpr right)
  | .constructMap constructor functor =>
      .constructMap constructor.raw (registryManifestFunctorExpr functor)

private def registryManifestSchema : CategoryFamilySchema → String
  | .ring => "ring"
  | .commRing => "commRing"
  | .commRingModule => "commRingModule"
  | .commRingNat => "commRingNat"
  | .commRingIndexType => "commRingIndexType"
  | .domain => "domain"

private def registryManifest (state : RegistryState) : RegistryManifest :=
  let cats := state.categories.qsort (fun a b => a.id.raw < b.id.raw)
  let families := state.categoryFamilies.qsort (fun a b => a.id.raw < b.id.raw)
  let clfs := state.classifiers.qsort (fun a b => a.id.raw < b.id.raw)
  let functors := state.functors.qsort (fun a b => a.id.raw < b.id.raw)
  let opaqueEntries := state.opaqueCategories.qsort (fun a b => a.id.raw < b.id.raw)
  { schemaVersion := "0.2.0-ids"
    categories := cats.map fun e => {
      id := e.id.raw, declaration := e.declaration.toString,
      realization := e.realization.toString,
      refinementRealization := e.refinementRealization.map Lean.Name.toString |>.getD "",
      expression := registryManifestCategoryExpr e.expression }
    classifiers := clfs.map fun e => {
      id := e.id.raw,
      host := registryManifestCategoryExpr e.host, declaration := e.declaration.toString,
      realization := e.realization.toString }
    functors := functors.map fun e => {
      id := e.id.raw,
      source := registryManifestCategoryExpr e.source, target := registryManifestCategoryExpr e.target,
      declaration := e.declaration.toString, realization := e.realization.toString,
      expression := registryManifestFunctorExpr e.expression, structural := e.structural }
    opaqueCategories := opaqueEntries.map fun e => {
      id := e.id.raw, declaration := e.declaration.toString, realization := e.realization.toString,
      reason := e.reason,
      ports := e.ports.map fun p => {
        id := p.id.raw, source := registryManifestCategoryExpr p.source,
        target := registryManifestCategoryExpr p.target, declaration := p.declaration.toString,
        realization := p.realization.toString, provenance := p.provenance } }
    categoryFamilies := families.map fun e => {
      id := e.id.raw,
      schema := registryManifestSchema e.schema,
      realization := e.realization.toString, transport := e.transport.toString,
      parameters := e.schema.parameterMetadata.map fun parameter => {
        ids := parameter.ids.toArray.map (·.raw), name := parameter.name,
        kind := parameter.kind.raw, dependency := parameter.dependency },
      variance := e.transportSemantics.variance.raw }
    fibrations := (state.fibrations.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, projection := e.projection.raw,
      variance := match e.variance with
        | .cartesian => "cartesian"
        | .cocartesian => "cocartesian",
      evidence := e.evidence.toString }
    constructors := (state.constructors.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, semantics := e.semantics.toString,
      signature := e.signature.map fun
        | .category => "category"
        | .object => "object"
        | .functor => "functor" }
    actions := (state.actions.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, functor := e.edge.label, realization := e.realization.toString }
    methods := (state.methods.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, name := e.name, owner := registryManifestCategoryExpr e.owner,
      functor := e.functor.raw,
      shape := match e.shape with
        | .object => "object"
        | .isoInvariant => "isoInvariant",
      returnsToSource := e.returnsToSource }
    properties := (state.properties.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, name := e.name, classifier := e.classifier.raw,
      receiver := e.receiver.map registryManifestCategoryExpr }
    deciders := (state.deciders.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, classifier := e.classifier.raw, realization := e.realization.toString }
    lifts := (state.lifts.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, edge := e.edge.label, evidence := e.evidence.toString
      kind := match e.kind with
        | .subobjects => "subobjects"
        | .createsLimits shape => s!"creates_limits:{shape}" }
    realizers := (state.realizers.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, category := e.category.raw, denotation := e.denotation.toString,
      backend := e.backend }
    implementations := (state.implementations.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, method := e.method.raw, route := e.route.map (·.label),
      realization := e.realization.toString, backend := e.backend, trust := e.trust.label }
    handleIsos := (state.handleIsos.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, realizer := e.realizer.raw, source := e.source.toString,
      target := e.target.toString, evidence := e.evidence.toString }
    cells := (state.cells.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, source := registryManifestCategoryExpr e.source,
      target := registryManifestCategoryExpr e.target, left := e.left.map (·.label),
      right := e.right.map (·.label), declaration := e.declaration.toString,
      invertible := e.invertible }
    limits := (state.limits.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, category := e.category.raw, shape := e.shape,
      declaration := e.declaration.toString, colimit := e.colimit }
    limitRealizations := (state.limitRealizations.qsort (fun a b => a.id.raw < b.id.raw)).map
      fun e => { id := e.id.raw, limit := e.limit.raw, realizer := e.realizer.raw,
                 realization := e.realization.toString, lift := e.lift.map (·.raw) }
    adjunctions := (state.adjunctions.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, left := e.left.raw, right := e.right.raw,
      declaration := e.declaration.toString }
    equalities := (state.equalities.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, realizer := e.realizer.raw, realization := e.realization.toString }
    backendOperations := (state.backendOperations.qsort (fun a b => a.id.raw < b.id.raw)).map
      fun e => { id := e.id.raw, backend := e.backend, operation := e.operation
                 decoder := e.decoder.toString }
    objects := (state.objects.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, category := e.category.raw, declaration := e.declaration.toString }
    presentations := (state.presentations.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, object := e.object.raw, realizer := e.realizer.raw
      presentation := e.presentation.toString }
    source := "lean-registry" }

private def registryManifestJson (state : RegistryState) : Json := toJson (registryManifest state)

/-- Return the manifest produced from the checked persistent registry state. -/
def checkedRegistryManifestDTO : CoreM RegistryManifest := do
  let state ← registryState
  match validatePersistedSemanticState state.toSemanticState *> validateRealizationReferences state with
  | .error message => throwError message
  | .ok () => pure (registryManifest state)

def checkedRegistryManifest : CoreM Json := do
  return toJson (← checkedRegistryManifestDTO)

end CasCatalogue
