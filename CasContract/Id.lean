module

public import LeanCategories.Catalogue.Id

@[expose] public section

/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

/-!
# Stable identities of realization rows

The semantic identities (categories, functors, classifiers, methods, …) are `lean-categories`'
(`LeanCategories.Catalogue.Id`); these name the rows of the realization registry.
-/

namespace CasCatalogue

/-- Stable id of a registered functor action on realizations (CC-ACTION), e.g.
`act.modules.underlying.int_free`. -/
structure ActionId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of a registered decision procedure, e.g. `dec.magmas.commutative.table`. -/
structure DeciderId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of a registered realizer (a denotation of handles into a category), CC-SEP. -/
structure RealizerId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of a registered fused implementation of a semantic composite, CC-ROUTE. -/
structure ImplementationId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of a registered isomorphism between two realized objects, CC-CARRIER. -/
structure HandleIsoId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of a backend's presentation of the apex of a registered limit. -/
structure LimitRealizationId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of an operation a backend declares on a registered semantic operation. -/
structure BackendOperationId where
  raw : String
  deriving DecidableEq, Repr, Hashable

/-- Stable id of a category's registered equality procedure on a realization. -/
structure EqualityId where
  raw : String
  deriving DecidableEq, Repr, Hashable


/-- Stable id of a presentation row: a leaf's handles for the values of a named object. -/
structure PresentationId where
  raw : String
  deriving DecidableEq, Repr, Hashable

instance : Inhabited PresentationId := ⟨⟨""⟩⟩
/-- Stable id of an observation row: a leaf's reading of its handles as literals. -/
structure ObservationId where
  raw : String
  deriving DecidableEq, Repr, Hashable

instance : Inhabited ObservationId := ⟨⟨""⟩⟩
instance : Inhabited ActionId := ⟨⟨""⟩⟩
instance : Inhabited DeciderId := ⟨⟨""⟩⟩
instance : Inhabited RealizerId := ⟨⟨""⟩⟩
instance : Inhabited ImplementationId := ⟨⟨""⟩⟩
instance : Inhabited HandleIsoId := ⟨⟨""⟩⟩
instance : Inhabited LimitRealizationId := ⟨⟨""⟩⟩
instance : Inhabited BackendOperationId := ⟨⟨""⟩⟩
instance : Inhabited EqualityId := ⟨⟨""⟩⟩

end CasCatalogue
