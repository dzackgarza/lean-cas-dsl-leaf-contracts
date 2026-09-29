/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Decide
public import Mathlib.CategoryTheory.ObjectProperty.FullSubcategory

@[expose] public section

/-!
# Same-object refinement (CC-PROP, CC-DECIDE)

A refinement of a category `C` by a property `P` is Mathlib's full subcategory `P.FullSubcategory`
with its inclusion `P.ι`. On a realization `d : R ⥤ C`, the handles proved to lie in it are the
full subcategory of handles on `P.inverseImage d`, denoting through `P.lift`. A proved decision
re-types a handle into it: the same handle, carrying the proof, whose image under the inclusion is
the handle itself and whose denotation's image under `P.ι` is its denotation, both
definitionally; a refuted or undecided decision leaves the handle where it was (`refine`).
Containment `P ≤ Q` is Mathlib's `ObjectProperty.ιOfLE`, and the refined handles follow it
(`refineLE`).
-/

open CategoryTheory

namespace CasCatalogue

universe v u v' u' uObj uHom

variable {C : Type u} [Category.{v} C] {R : Type u'} [Category.{v'} R]

/-- The handles whose denotations satisfy `P`. -/
abbrev Refined (d : R ⥤ C) (P : ObjectProperty C) : Type u' := (P.inverseImage d).FullSubcategory

/-- A refined handle denotes its denotation, as an object of the refinement. -/
def refinedDenotation (d : R ⥤ C) (P : ObjectProperty C) : Refined d P ⥤ P.FullSubcategory :=
  P.lift ((P.inverseImage d).ι ⋙ d) fun a => a.property

/-- A refined realization is fully faithful when the realization is (the preimage of a morphism of
the refinement is the preimage of its underlying morphism). -/
def refinedDenotationFullyFaithful {d : R ⥤ C} (hd : d.FullyFaithful) (P : ObjectProperty C) :
    (refinedDenotation d P).FullyFaithful :=
  Functor.FullyFaithful.ofCompFaithful (G := P.ι) ((ObjectProperty.fullyFaithfulι _).comp hd)

/-- The inclusion of the refinement, realized by forgetting the proof; its square commutes
strictly. -/
def refinedInclusion (d : R ⥤ C) (P : ObjectProperty C) :
    RealizedAction P.ι (refinedDenotation d P) d :=
  RealizedAction.ofEq (P.inverseImage d).ι rfl

/-- Re-typing after a decision: proved places the same handle in the refinement; refuted and
undecided leave it unplaced. -/
@[macro_inline] def refine {d : R ⥤ C} {P : ObjectProperty C} (a : R) : Decision (P (d.obj a)) → Option (Refined d P)
  | .proved h => some ⟨a, h⟩
  | _ => none

/-- A re-typed handle is the same handle. -/
theorem refine_eq_some {d : R ⥤ C} {P : ObjectProperty C} {a : R} {δ : Decision (P (d.obj a))}
    {r : Refined d P} (h : refine a δ = some r) : (refinedInclusion d P).obj r = a := by
  cases δ <;> simp [refine] at h
  subst h; rfl

/-- Only a proof places a handle. -/
theorem refine_isSome {d : R ⥤ C} {P : ObjectProperty C} {a : R} {δ : Decision (P (d.obj a))} :
    (refine a δ).isSome ↔ ∃ h, δ = .proved h := by
  cases δ with
  | proved h => exact ⟨fun _ => ⟨h, rfl⟩, fun _ => rfl⟩
  | _ => simp [refine]

/-- Containment of refinements: a refined handle for `P ≤ Q` is one for `Q`, over `ιOfLE`. -/
def refineLE {d : R ⥤ C} {P Q : ObjectProperty C} (h : P ≤ Q) (r : Refined d P) : Refined d Q :=
  ⟨r.obj, h _ r.property⟩

theorem refinedDenotation_refineLE {d : R ⥤ C} {P Q : ObjectProperty C} (h : P ≤ Q)
    (r : Refined d P) :
    (refinedDenotation d Q).obj (refineLE h r) =
      (ObjectProperty.ιOfLE h).obj ((refinedDenotation d P).obj r) := rfl

end CasCatalogue
