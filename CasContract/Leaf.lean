/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Adapter
public import CasContract.Action
public import CasContract.Decide
public import CasContract.Trust
public import LeanCategories.Catalogue.Realization
public import LeanCategories.Catalogue.Constructors
public import CasContract.Limits
public import CasContract.Refine
public import CasContract.Port
public import Lean.Data.Json

@[expose] public section

/-!
# The leaf API

The one kernel module a backend leaf (`CasLeaves`) imports. Besides it, a leaf imports the
registered semantics it realizes (`LeanCategories.Catalogue.Semantics.*`: category, functor, classifier and
operation identifiers and their Lean denotations). It exposes the types a leaf's contributions have: a realization is a
category of handles with a denotation functor (Mathlib; `InducedCategory`, `Discrete`, `Core` are the
usual handle categories), a `RealizedAction` is a handle functor with a `CatCommSq`, a `Decider`, an
isomorphism of handles, implementations; JSON for codecs; and `register_leaf`. A leaf module importing any other kernel module is rejected when it registers
(`addLeafRegistryEntryChecked`) and by the leaf-boundary acceptance probe.
-/
