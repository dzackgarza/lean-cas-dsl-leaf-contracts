/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Action
public import LeanCategories.Catalogue.Holds
public import Mathlib.CategoryTheory.FiberedCategory.Fiber

@[expose] public section

/-!
# Property queries and three-valued decisions (CC-PROP, CC-DECIDE)

A property is a registered classifier `p : 𝒞.A → 𝒞`; nothing else owns property meaning. The
query "does `x` have `A`" asks whether the fibre of `p` over `x` is inhabited (FOUNDATIONS
Def. 46.4): `Classifier.Holds`.

A decision is `proved` with a proof, `refuted` with a proof of the negation, or `undecided`.
Undecided is the absence of a decision procedure, not a third truth value, so no combinator turns
it into a refutation: a conjunction is refuted only when a conjunct is.

A `Decider c d` decides `c.Holds` on the denotation of every handle of a realizer; it is
registered against the classifier `c`, never as a category or a runtime label.
-/

open CategoryTheory

namespace CasCatalogue

universe uObj uHom w x

/-- A three-valued decision of `p`, with evidence for either answer. -/
inductive Decision (p : Prop) where
  | proved (h : p)
  | refuted (h : ¬p)
  | undecided

namespace Decision

variable {p q : Prop}

/-- The answer, forgetting the evidence: `some true`, `some false`, or `none`. -/
def answer : Decision p → Option Bool
  | proved _ => some true
  | refuted _ => some false
  | undecided => none

/-- Conjunction: refuted only when a conjunct is refuted; undecided otherwise unless both are
proved. -/
def and : Decision p → Decision q → Decision (p ∧ q)
  | proved hp, proved hq => proved ⟨hp, hq⟩
  | refuted hp, _ => refuted fun h => hp h.1
  | _, refuted hq => refuted fun h => hq h.2
  | _, _ => undecided

/-- A decision of an equivalent proposition. -/
def map (e : p ↔ q) : Decision p → Decision q
  | proved h => proved (e.mp h)
  | refuted h => refuted fun hq => h (e.mpr hq)
  | undecided => undecided

/-- A `Decidable` instance is a complete decision procedure. -/
def ofDecidable (p : Prop) [Decidable p] : Decision p :=
  if h : p then proved h else refuted h

/-- A refutation is sound: it is never produced for a true proposition. -/
theorem answer_ne_false_of {d : Decision p} (h : p) : d.answer ≠ some false := by
  cases d with
  | refuted hn => exact absurd h hn
  | _ => simp [answer]

end Decision

/-- A decision procedure for equality of morphism handles of a realization `d`, stated about their
denotations: equality is the category's, decided on the realization. A refutation carries a proof
of `d.map f ≠ d.map g`, so two equal morphisms, however constructed, are never decided unequal. -/
structure HomEquality {C : Type uObj} [Category.{uHom} C] {R : Type w} [Category.{x} R]
    (d : R ⥤ C) where
  decide : ∀ {a b : R} (f g : a ⟶ b), Decision (d.map f = d.map g)

/-- A decision procedure for the property `c` on the handles of a realizer `R`, stated about
their denotations. -/
structure Decider {C : LeanCategories.ObjCat.{uObj, uHom}} (c : LeanCategories.Classifier C)
    {R : Type w} [Category.{x} R] (d : R ⥤ C) where
  decide : (a : R) → Decision (Classifier.Holds c (d.obj a))

end CasCatalogue
