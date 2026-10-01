/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import Lean.Exception

@[expose] public section

/-!
# Stratified failures (`specs/architecture.md`, "Failure is stratified")

A call can fail in kinds that are never collapsed:

* `invalid`: semantic. The expression names nothing registered, the operation does not apply
  (no structural route reaches its owner), or several semantic routes are not identified by a
  coherence.
* `noImplementation`: the operation applies, and no admitted registration computes it on this
  form (`specs/leaf-registration.md`, "The realized reading"): a gap.
* `ambiguousRealization`: several admitted registrations compute it on this form, and choosing
  one is a choice the kernel does not make: a gap, reported as ambiguous.
* `unavailable`: a registration's backend cannot be started, or it failed while computing.
* `malformed`: a backend answered outside the protocol, or outside the operation's result form.

A well-typed wrong answer is the fifth kind. The kernel cannot see it; the acceptance suite
detects it, by comparing the decoded answer with the assertion's expected value.

Each failure is thrown with its stratum as the tag of its message (`throwStratum`), and the
stratum is read back from the exception (`Exception.stratum?`). The rendering carries the
stratum's label, so a reader sees the kind of failure before its detail.
-/

open Lean

namespace CasCatalogue

/-- The kind of a failed call. -/
inductive Stratum
  | invalid
  | noImplementation
  | ambiguousRealization
  | unavailable
  | malformed
  deriving DecidableEq, Repr, Inhabited

namespace Stratum

def all : List Stratum :=
  [.invalid, .noImplementation, .ambiguousRealization, .unavailable, .malformed]

/-- The message tag of the stratum. -/
def tag : Stratum → Name
  | .invalid => `CasCatalogue.Stratum.invalid
  | .noImplementation => `CasCatalogue.Stratum.noImplementation
  | .ambiguousRealization => `CasCatalogue.Stratum.ambiguousRealization
  | .unavailable => `CasCatalogue.Stratum.unavailable
  | .malformed => `CasCatalogue.Stratum.malformed

/-- The label a reader sees first. -/
def label : Stratum → String
  | .invalid => "not a valid call"
  | .noImplementation => "NoImplementation"
  | .ambiguousRealization => "ambiguous realization"
  | .unavailable => "realization unavailable"
  | .malformed => "malformed realization output"

end Stratum

/-- Throw a failure of the stratum `s`. -/
def throwStratum {m : Type → Type} {α : Type} [Monad m] [MonadError m] (s : Stratum)
    (message : MessageData) : m α :=
  throwError (MessageData.tagged s.tag m!"{s.label}: {message}")

/-- The stratum a failure was thrown with, if any. -/
def Exception.stratum? (e : Exception) : Option Stratum :=
  Stratum.all.find? fun s => e.toMessageData.hasTag (· == s.tag)

end CasCatalogue
