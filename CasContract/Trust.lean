/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Action
public import Mathlib.CategoryTheory.Core

@[expose] public section

/-!
# Epistemic status and fused realizations (CC-TRUST, CC-ROUTE)

Every computed result records how much is known about it (FOUNDATIONS Remark 46.5):

* `kernelTheorem` — a Lean theorem about this very value;
* `leanChecked` — computed by actions proved to commute with denotation (`RealizedAction`);
* `certificateChecked` — a backend answer accepted because a Lean-proved checker accepted its
  certificate;
* `trustedAssertion` — a backend answer taken on trust.

A composite is only as trusted as its weakest step (`Trust.meet`).

A backend may realize a whole composite at once — "cardinality of a formed module" as one call —
as a *fused* realization of the semantic composite `M ∘ U` (#53 §10). It is registered against that
composite, never as a new method (CC-ROUTE). A `TrustedImplementation` is such a realization with
no proof: its type fixes what it claims to compute (the route functor `U`, the method functor `M`,
the denotations), and the registry records it as a trusted assertion.
-/

open CategoryTheory

namespace CasCatalogue

/-- Epistemic status of a result, strongest first. -/
inductive Trust
  | kernelTheorem
  | leanChecked
  | certificateChecked
  | trustedAssertion
  deriving DecidableEq, Repr, Inhabited

namespace Trust

/-- Rank: lower is stronger. -/
def rank : Trust → Nat
  | kernelTheorem => 0
  | leanChecked => 1
  | certificateChecked => 2
  | trustedAssertion => 3

/-- The status of a composite: the weaker of the two. -/
def meet (a b : Trust) : Trust := if a.rank ≥ b.rank then a else b

/-- How the notebook displays a status. -/
def label : Trust → String
  | kernelTheorem => "kernel theorem"
  | leanChecked => "Lean-checked computation"
  | certificateChecked => "certificate-checked backend answer"
  | trustedAssertion => "trusted backend assertion"

end Trust

/-- A computed value with its epistemic status and provenance. -/
structure Result (α : Type _) where
  value : α
  trust : Trust
  provenance : String
  deriving Repr

universe u v u' v' u'' v'' w w' x x'

/-- A fused, unproved realization of `x ↦ M(Core(U)(x))` for an iso-invariant method `M` reached
along `U`: the indices fix the claim, and nothing proves it. -/
structure TrustedImplementation {C : Type u} [Category.{v} C] {D : Type u'} [Category.{v'} D]
    {E : Type u''} [Category.{v''} E] {RC : Type w} [Category.{x} RC] {RE : Type w'}
    [Category.{x'} RE] (U : C ⥤ D) (M : Core D ⥤ E) (dC : RC ⥤ C) (dE : RE ⥤ E) where
  obj : RC → RE

end CasCatalogue

namespace CasCatalogue

/-- Realizations whose handles present sets of elements: a functor from handles to types, so that
a morphism handle (in particular a registered isomorphism of handles, CC-CARRIER) transports
elements. -/
class ElementAction (R : Type w) [Category.{x} R] where
  elements : R ⥤ Type

/-- The elements of a handle. -/
abbrev ElementAction.Elt {R : Type w} [Category.{x} R] [ElementAction R] (a : R) : Type :=
  (ElementAction.elements (R := R)).obj a

/-- Transport of elements along a morphism handle. -/
def ElementAction.act {R : Type w} [Category.{x} R] [ElementAction R] {a b : R} (f : a ⟶ b)
    (x : ElementAction.Elt a) : ElementAction.Elt b :=
  (ElementAction.elements (R := R)).map f x

end CasCatalogue

namespace CasCatalogue

/-- A backend realization of `x ↦ M(Core(U)(x))` that returns a certificate with its answer, and a
Lean checker whose acceptance is proved to imply the answer's correctness. -/
structure CertifiedImplementation {C : Type u} [Category.{v} C] {D : Type u'} [Category.{v'} D]
    {E : Type u''} [Category.{v''} E] {RC : Type w} [Category.{x} RC] {RE : Type w'}
    [Category.{x'} RE] (U : C ⥤ D) (M : Core D ⥤ E) (dC : RC ⥤ C) (dE : RE ⥤ E) where
  obj : RC → RE
  Certificate : Type
  certificate : RC → Certificate
  check : RC → Certificate → Bool
  sound : ∀ a, check a (certificate a) = true → dE.obj (obj a) = M.obj ⟨U.obj (dC.obj a)⟩

/-- Run a certified implementation: certificate-checked when its checker accepts, otherwise only
the backend's assertion. (`macro_inline`: compiled code never receives the denotations.) -/
@[macro_inline] def CertifiedImplementation.run {C : Type u} [Category.{v} C] {D : Type u'} [Category.{v'} D]
    {E : Type u''} [Category.{v''} E] {RC : Type w} [Category.{x} RC] {RE : Type w'}
    [Category.{x'} RE] {U : C ⥤ D} {M : Core D ⥤ E} {dC : RC ⥤ C} {dE : RE ⥤ E}
    (impl : CertifiedImplementation U M dC dE) (a : RC) (provenance : String) :
    Result RE :=
  if impl.check a (impl.certificate a) then ⟨impl.obj a, .certificateChecked, provenance⟩
  else ⟨impl.obj a, .trustedAssertion, provenance ++ " (certificate rejected)"⟩

/-- A result whose value is its computation's kernel-reduced normal form: the kernel checks
`computed = value` when the enclosing declaration is added. -/
def Result.ofKernel {α : Type _} (computed value : α) (_ : computed = value) (provenance : String) :
    Result α :=
  ⟨value, .kernelTheorem, provenance⟩

end CasCatalogue
