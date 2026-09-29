/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Action
public import Mathlib.CategoryTheory.Limits.HasLimits
public import Mathlib.CategoryTheory.Limits.Preserves.Basic
public import Mathlib.CategoryTheory.Whiskering

@[expose] public section

/-!
# Limits on realizations (CC-UNIV)

A limit of a registered diagram is Mathlib's: a `LimitCone` (apex, legs, `IsLimit` with its
mediator `IsLimit.lift`). A backend presents the apex: a handle whose denotation it identifies with
the apex. Over a fully faithful realization, that is all a backend supplies; the legs on handles
and every mediator on handles are preimages of Mathlib's, and the result is Mathlib's `LimitCone`
of the diagram of handles (`IsLimit.ofFaithful`, with the realization's explicit preimage, so the
mediators compute). Mathlib's own reflection of limits along fully faithful functors goes through
`Functor.preimage`, a choice, and would not.
-/

open CategoryTheory Limits

namespace CasCatalogue

universe v u v' u' w w'

variable {J : Type w} [Category.{w'} J] {R : Type u} [Category.{v} R] {C : Type u'}
  [Category.{v'} C]

/-- A limit cone of `G`, transported to a diagram `F ≅ G` (`IsLimit.postcomposeInvEquiv`). -/
def limitConeOfIso {F G : J ⥤ C} (α : F ≅ G) (L : LimitCone G) : LimitCone F :=
  ⟨(Cones.postcompose α.inv).obj L.cone, (IsLimit.postcomposeInvEquiv α L.cone).symm L.isLimit⟩

variable {d : R ⥤ C} {D : J ⥤ R}

/-- The morphism rule of a faithful functor `F : R ⥤ E` (sage-categories D183): a map below that is
the image of a morphism above is lifted to that morphism, computably. Faithfulness makes the lift
unique; the rule supplies it as data, where Mathlib's `Functor.preimage` would choose it. -/
structure MorphismRule {E : Type*} [Category E] (F : R ⥤ E) where
  lift : ∀ {X Y : R} (g : F.obj X ⟶ F.obj Y), (∃ f, F.map f = g) → (X ⟶ Y)
  map_lift : ∀ {X Y : R} (g : F.obj X ⟶ F.obj Y) (h : ∃ f, F.map f = g), F.map (lift g h) = g

/-- A fully faithful functor's rule is its preimage. -/
def MorphismRule.ofFullyFaithful {E : Type*} [Category E] {F : R ⥤ E} (hF : F.FullyFaithful) :
    MorphismRule F :=
  ⟨fun g _ => hF.preimage g, fun _ _ => hF.map_preimage _⟩

/-- A limit returned along a faithful functor `F` (CC-LIFT, D183): for a limit cone `L` of `D ⋙ F`
below and an object `a` above whose image `φ` identifies with `L`'s apex, and whose legs below are
images of morphisms above (`legs`), the legs and every mediator are the ones below, lifted by the
morphism rule. That the mediators are morphisms above follows from reflection of the limit
(Mathlib `isLimitOfReflects`), used only in the proof. -/
def realizedLiftedLimitCone {E : Type*} [Category E] {F : R ⥤ E} [F.Faithful] [ReflectsLimit D F]
    (rule : MorphismRule F) (L : LimitCone (D ⋙ F)) (a : R) (φ : F.obj a ≅ L.cone.pt)
    (legs : ∀ j, ∃ f : a ⟶ D.obj j, F.map f = φ.hom ≫ L.cone.π.app j) : LimitCone D :=
  let c : Cone D :=
    { pt := a
      π :=
        { app := fun j => rule.lift _ (legs j)
          naturality := fun j k f => by
            apply F.map_injective
            simp only [Functor.const_obj_obj, Functor.const_obj_map, Category.id_comp,
              Functor.map_comp, rule.map_lift, Category.assoc]
            rw [← Functor.comp_map, L.cone.w f] } }
  have hc : IsLimit (F.mapCone c) :=
    IsLimit.ofIsoLimit L.isLimit (Cones.ext φ fun j => by simp [c, rule.map_lift]).symm
  ⟨c, IsLimit.ofFaithful F hc
    (fun s => rule.lift (hc.lift (F.mapCone s))
      ⟨(isLimitOfReflects F hc).lift s, hc.uniq (F.mapCone s) _ fun j => by
        simp only [Functor.mapCone_π_app, ← F.map_comp, (isLimitOfReflects F hc).fac]⟩)
    fun _ => rule.map_lift _ _⟩

/-- The legs of a lifted limit lie over the legs of `L`. -/
theorem realizedLiftedLimitCone_leg {E : Type*} [Category E] {F : R ⥤ E} [F.Faithful]
    [ReflectsLimit D F] (rule : MorphismRule F) (L : LimitCone (D ⋙ F)) (a : R)
    (φ : F.obj a ≅ L.cone.pt) (legs : ∀ j, ∃ f : a ⟶ D.obj j, F.map f = φ.hom ≫ L.cone.π.app j)
    (j : J) :
    F.map ((realizedLiftedLimitCone rule L a φ legs).cone.π.app j) = φ.hom ≫ L.cone.π.app j :=
  rule.map_lift _ _

/-- The realized limit of a diagram of handles `D` over a fully faithful realization `d`: the
lifted limit along `d` with the preimage as morphism rule; the apex handle `a` is presented by a
backend, whose denotation `φ` identifies with the apex of a limit cone `L` of `D ⋙ d`. -/
def realizedLimitCone (hd : d.FullyFaithful) (L : LimitCone (D ⋙ d)) (a : R)
    (φ : d.obj a ≅ L.cone.pt) : LimitCone D :=
  haveI := hd.faithful
  haveI := hd.full
  realizedLiftedLimitCone (MorphismRule.ofFullyFaithful hd) L a φ fun j =>
    ⟨hd.preimage _, hd.map_preimage _⟩

theorem realizedLimitCone_pt (hd : d.FullyFaithful) (L : LimitCone (D ⋙ d)) (a : R)
    (φ : d.obj a ≅ L.cone.pt) : (realizedLimitCone hd L a φ).cone.pt = a := rfl

/-- The denotation of a leg of the realized limit is the leg of `L` after `φ`. -/
theorem realizedLimitCone_leg (hd : d.FullyFaithful) (L : LimitCone (D ⋙ d)) (a : R)
    (φ : d.obj a ≅ L.cone.pt) (j : J) :
    d.map ((realizedLimitCone hd L a φ).cone.π.app j) = φ.hom ≫ L.cone.π.app j :=
  hd.map_preimage _

/-- A limit returned along a fully faithful functor `U : C ⥤ E` (CC-LIFT): for a diagram of
handles `D` whose image in `E` has the limit cone `L`, and an apex handle lying over `L`'s apex, the
limit cone of `D` has as legs and mediators the preimages along `d ⋙ U` of `L`'s. A fully faithful
`U` creates the limits whose apex lies in its image (Mathlib `createsLimitOfFullyFaithfulOfIso`);
the registered creation lift names it, and the backend's apex handle is the witness. -/
def realizedReturnedLimitCone {E : Type*} [Category E] (hd : d.FullyFaithful) {U : C ⥤ E}
    (hU : U.FullyFaithful) (L : LimitCone ((D ⋙ d) ⋙ U)) (a : R) (φ : U.obj (d.obj a) ≅ L.cone.pt) :
    LimitCone D :=
  realizedLimitCone (hd.comp hU) L a φ

/-- The legs of a returned limit lie over the legs of `L`. -/
theorem realizedReturnedLimitCone_leg {E : Type*} [Category E] (hd : d.FullyFaithful) {U : C ⥤ E}
    (hU : U.FullyFaithful) (L : LimitCone ((D ⋙ d) ⋙ U)) (a : R) (φ : U.obj (d.obj a) ≅ L.cone.pt)
    (j : J) :
    U.map (d.map ((realizedReturnedLimitCone hd hU L a φ).cone.π.app j)) = φ.hom ≫ L.cone.π.app j :=
  realizedLimitCone_leg (d := d ⋙ U) (hd.comp hU) L a φ j

/-- The realized limit of `D` computed through an adjunction `Δ ⊣ L`: the apex is the image of `D`
under the realized action of the right adjoint `L`, and the limit cone of `D ⋙ d` is Mathlib's
(`coneOfAdj`, legs the counit, mediators the transposes, `isLimitConeOfAdj`). -/
noncomputable def realizedLimitConeOfAdj (hd : d.FullyFaithful) {L : (J ⥤ C) ⥤ C}
    (adj : Functor.const J ⊣ L) (aL : RealizedAction L ((Functor.whiskeringRight J R C).obj d) d)
    (D : J ⥤ R) : LimitCone D :=
  realizedLimitCone hd ⟨coneOfAdj adj (D ⋙ d), isLimitConeOfAdj adj (D ⋙ d)⟩ (aL.obj D)
    (aL.objIso D)

/-! ### Colimits (the dual)

Mathlib's precedent for the morphism rule is `TopCat.isColimitCoconeOfForget`: the descent below,
made a continuous map by a proof. -/

/-- A colimit cocone of `G`, transported to a diagram `F ≅ G` (`IsColimit.precomposeHomEquiv`). -/
def colimitCoconeOfIso {F G : J ⥤ C} (α : F ≅ G) (L : ColimitCocone G) : ColimitCocone F :=
  ⟨(Cocone.precompose α.hom).obj L.cocone,
    (IsColimit.precomposeHomEquiv α L.cocone).symm L.isColimit⟩

/-- A colimit returned along a faithful functor `F` (the dual of `realizedLiftedLimitCone`): the
coprojections and every descent are the ones below, lifted by the morphism rule; reflection proves
that the descents below are morphisms above. -/
def realizedLiftedColimitCocone {E : Type*} [Category E] {F : R ⥤ E} [F.Faithful]
    [ReflectsColimit D F] (rule : MorphismRule F) (L : ColimitCocone (D ⋙ F)) (a : R)
    (φ : F.obj a ≅ L.cocone.pt)
    (legs : ∀ j, ∃ f : D.obj j ⟶ a, F.map f = L.cocone.ι.app j ≫ φ.inv) : ColimitCocone D :=
  let c : Cocone D :=
    { pt := a
      ι :=
        { app := fun j => rule.lift _ (legs j)
          naturality := fun j k f => by
            apply F.map_injective
            simp only [Functor.const_obj_obj, Functor.const_obj_map, Category.comp_id,
              Functor.map_comp, rule.map_lift]
            rw [← Category.assoc, ← Functor.comp_map, L.cocone.w f] } }
  have hc : IsColimit (F.mapCocone c) :=
    IsColimit.ofIsoColimit L.isColimit (Cocone.ext φ.symm fun j => by simp [c, rule.map_lift])
  ⟨c, IsColimit.ofFaithful F hc
    (fun s => rule.lift (hc.desc (F.mapCocone s))
      ⟨(isColimitOfReflects F hc).desc s, hc.uniq (F.mapCocone s) _ fun j => by
        simp only [Functor.mapCocone_ι_app, ← F.map_comp, (isColimitOfReflects F hc).fac]⟩)
    fun _ => rule.map_lift _ _⟩

/-- The coprojections of a lifted colimit lie over those of `L`. -/
theorem realizedLiftedColimitCocone_leg {E : Type*} [Category E] {F : R ⥤ E} [F.Faithful]
    [ReflectsColimit D F] (rule : MorphismRule F) (L : ColimitCocone (D ⋙ F)) (a : R)
    (φ : F.obj a ≅ L.cocone.pt)
    (legs : ∀ j, ∃ f : D.obj j ⟶ a, F.map f = L.cocone.ι.app j ≫ φ.inv) (j : J) :
    F.map (show D.obj j ⟶ a from (realizedLiftedColimitCocone rule L a φ legs).cocone.ι.app j) =
      L.cocone.ι.app j ≫ φ.inv :=
  rule.map_lift _ _

/-- The realized colimit over a fully faithful realization: the backend presents the apex. -/
def realizedColimitCocone (hd : d.FullyFaithful) (L : ColimitCocone (D ⋙ d)) (a : R)
    (φ : d.obj a ≅ L.cocone.pt) : ColimitCocone D :=
  haveI := hd.faithful
  haveI := hd.full
  realizedLiftedColimitCocone (MorphismRule.ofFullyFaithful hd) L a φ fun _ =>
    ⟨hd.preimage _, hd.map_preimage _⟩

/-- The denotation of a coprojection of the realized colimit is the coprojection of `L` followed by
`φ⁻¹`. -/
theorem realizedColimitCocone_leg (hd : d.FullyFaithful) (L : ColimitCocone (D ⋙ d)) (a : R)
    (φ : d.obj a ≅ L.cocone.pt) (j : J) :
    d.map (show D.obj j ⟶ a from (realizedColimitCocone hd L a φ).cocone.ι.app j) =
      L.cocone.ι.app j ≫ φ.inv :=
  hd.map_preimage _

end CasCatalogue
