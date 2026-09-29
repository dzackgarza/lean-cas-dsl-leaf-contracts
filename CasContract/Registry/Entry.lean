/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import LeanCategories.Catalogue.Registry.Entry
public import CasContract.Id
public import CasContract.Trust

@[expose] public section

/-!
# Realization registry entries

The rows a backend leaf contributes. The semantic rows are `lean-categories'`
(`LeanCategories.Catalogue.Registry.Entry`).
-/

namespace CasCatalogue

/-- A functor action registry row (CC-ACTION): `realization` names a `RealizedAction F dC dD`,
an executable object and morphism action on realizations together with the proof that it
commutes with denotation, where `F` is (an instance of) the Mathlib functor of `edge`: a
registered functor row, or a registered classifier's forgetful functor. A composite functor's
action is the composite of its factors' actions and is never registered. -/
structure FunctorActionEntry where
  id : ActionId
  edge : EdgeRef
  realization : Lean.Name
  deriving Repr

/-- A realizer row (CC-SEP): `denotation` names a denotation functor `R ⥤ C` whose category `C` is the
registered category `category`. A handle's category is the category of the realizer it is used
with; nothing inspects the handle to find one. `backend` names the engine that produces handles. -/
structure RealizerEntry where
  id : RealizerId
  category : CategoryId
  denotation : Lean.Name
  backend : String
  /-- A `Functor.FullyFaithful` witness for the denotation, when it is fully faithful (an induced
  realization): cells are then realized on it as preimages. -/
  fullyFaithful : Option Lean.Name := none
  deriving Repr

/-- A fused implementation row (CC-ROUTE, CC-TRUST): a backend realization of the whole composite
`method ∘ route`, keyed by that semantic composite. It is one more realization of the same
operation, never a new method, and carries its epistemic status. -/
structure ImplementationEntry where
  id : ImplementationId
  method : MethodId
  route : Array EdgeRef
  realization : Lean.Name
  backend : String
  trust : Trust
  deriving Repr

/-- A registered isomorphism between two realized objects (CC-CARRIER): `evidence` names a
an isomorphism `source ≅ target` in the handle category of the registered realizer `realizer`. -/
structure HandleIsoEntry where
  id : HandleIsoId
  realizer : RealizerId
  source : Lean.Name
  target : Lean.Name
  evidence : Lean.Name
  deriving Repr

/-- A backend's presentation of the apex of a registered limit on one of its realizations:
`realization` sends a diagram of handles to an apex handle with the identification of its
denotation with the apex (the legs and mediators are then the core's, `realizedLimitCone`). -/
structure LimitRealizationEntry where
  id : LimitRealizationId
  limit : LimitId
  realizer : RealizerId
  realization : Lean.Name
  /-- A creation lift along which the limit, computed in the lift's target, is returned to the
  realizer's category, the lift's source (CC-LIFT). -/
  lift : Option LiftId := none
  deriving Repr

/-- A backend operation row (CC-ADAPTER, CC-DECODE): the backend `backend` answers the registered
semantic operation `operation` (a registered limit or method id; the key its adapter announces and
is called by), and `decoder` decodes its untrusted JSON answer into the operation's semantic result
type, or rejects it (`… → Json → Except String τ`). -/
structure BackendOperationEntry where
  id : BackendOperationId
  backend : String
  operation : String
  decoder : Lean.Name
  deriving Repr

/-- An equality row (CC-DECIDE): `realization` names a `HomEquality d` for the denotation `d` of
the registered realizer `realizer`: the category's equality of morphisms, decided on its handles
(three-valued, with evidence). -/
structure EqualityEntry where
  id : EqualityId
  realizer : RealizerId
  realization : Lean.Name
  deriving Repr

/-- A decision-procedure row (CC-PROP, CC-DECIDE): `realization` names a `Decider c d` for the
registered classifier `classifier`. A backend decides a property; it never defines one. -/
structure DeciderEntry where
  id : DeciderId
  classifier : ClassifierId
  realization : Lean.Name
  deriving Repr


/-- A presentation row (CC-CALC, CC-SEP): `presentation : (parameters) → Σ a : R, d.obj a ≅ X`,
for the registered object `object` with the same parameters: a handle of the realizer `realizer`
presenting that object's value, with its identification. The leaf never names the object; the
row states which handles present which values. -/
structure PresentationEntry where
  id : PresentationId
  object : ObjectId
  realizer : RealizerId
  presentation : Lean.Name
  deriving Repr

/-- An observation row (CC-DECODE): `observe : (h : R) → { l : T // d.obj h = denote l }`, reading
each handle of the realizer `realizer` as a literal of the registered literal form `literal`
(`T`, `denote`), with the proof that the handle denotes that literal. A computed value is compared
with a literal by evaluating the observation alone. -/
structure ObservationEntry where
  id : ObservationId
  realizer : RealizerId
  literal : LiteralId
  observe : Lean.Name
  deriving Repr

end CasCatalogue
