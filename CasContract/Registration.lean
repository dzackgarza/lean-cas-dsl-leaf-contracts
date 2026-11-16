/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import Lean.Data.Json

@[expose] public section

/-!
# A leaf is a manifest of registrations (`specs/leaf-registration.md`, "A registration is data")

A leaf ships no Lean. It is a manifest, `leaves.json` at the root of its package, naming the
backend programs it runs and, for each registration, the catalogue operation it computes, the
input form it accepts and the backend that computes it:

```json
{
  "backends": [{"name": "sage", "command": "python3", "args": ["sage/leaf.py"]}],
  "registrations": [{"operation": "meth.cardinality", "input": "obj.sets.fin", "backend": "sage"}]
}
```

A registration has these three fields and, optionally, its declared preferred routes
(constitution C6): for a surface name read on objects of a category, the structural route of the
binding the name denotes. A preference selects among bindings that survive the reading; it
asserts no agreement between them. Nothing else in the manifest carries meaning: any other field
is ignored. Which registrations are admitted is the kernel's decision, against the
catalogue (`CasCatalogue.Admission`); this module only reads the data.
-/

open Lean

namespace CasCatalogue

/-- A backend program of a leaf: the command that starts it, speaking the port protocol
(`CasContract.Port`), with its arguments resolved relative to the manifest's directory. -/
structure BackendProgram where
  name : String
  command : String
  args : Array String := #[]
  deriving Repr, Inhabited, DecidableEq

/-- A declared preferred route (constitution C6): the surface name `name`, read on an object of
the registered category `receiver`, denotes the binding reached along the structural route
`route` (edge labels, in order). It is registration data, not a mathematical claim. -/
structure PreferredRoute where
  name : String
  receiver : String
  route : Array String
  deriving Repr, Inhabited, DecidableEq

/-- A registration: the leaf computes the catalogue operation `operation` on inputs of the form
`input`, by the backend `backend`, and declares the preferred routes `preferredRoutes`. It has no
other field, so a leaf can express nothing else. -/
structure Registration where
  operation : String
  input : String
  backend : String
  preferredRoutes : Array PreferredRoute := #[]
  deriving Repr, Inhabited, DecidableEq

/-- A leaf's manifest. -/
structure Manifest where
  backends : Array BackendProgram := #[]
  registrations : Array Registration := #[]
  deriving Repr, Inhabited

/-- The name of a leaf package's manifest, at its root. -/
def manifestFile : String := "leaves.json"

namespace Manifest

def stringField (j : Json) (k : String) : Except String String :=
  match j.getObjVal? k with
  | .ok v => v.getStr?.mapError fun _ => s!"the field `{k}` is not a string in {j.compress}"
  | .error _ => .error s!"the field `{k}` is missing in {j.compress}"

def backendOf (j : Json) : Except String BackendProgram := do
  let name ← stringField j "name"
  let command ← stringField j "command"
  let args ← match j.getObjVal? "args" with
    | .error _ => pure #[]
    | .ok a => do
        let items ← a.getArr?.mapError fun _ => s!"the field `args` of {name} is not an array"
        items.mapM fun s => s.getStr?.mapError fun _ => s!"an argument of {name} is not a string"
  return { name, command, args }

def arrayField (j : Json) (k : String) : Except String (Array Json) :=
  match j.getObjVal? k with
  | .error _ => .ok #[]
  | .ok a => a.getArr?.mapError fun _ => s!"the field `{k}` is not an array"

def preferredRouteOf (j : Json) : Except String PreferredRoute := do
  let route ← match j.getObjVal? "route" with
    | .error _ => throw s!"the field `route` is missing in {j.compress}"
    | .ok a => do
        let items ← a.getArr?.mapError fun _ => s!"the field `route` is not an array in {j.compress}"
        items.mapM fun s => s.getStr?.mapError fun _ => s!"a route edge is not a string in {j.compress}"
  if route.isEmpty then throw s!"a preferred route has no edge in {j.compress}"
  return { name := ← stringField j "name", receiver := ← stringField j "receiver", route }

def registrationOf (j : Json) : Except String Registration := do
  return { operation := ← stringField j "operation", input := ← stringField j "input"
           backend := ← stringField j "backend"
           preferredRoutes := ← (← arrayField j "preferredRoutes").mapM preferredRouteOf }

/-- Read a manifest from its JSON. Fields other than the ones above are ignored. -/
def parse (j : Json) : Except String Manifest := do
  let .obj _ := j | throw "a leaf manifest must be a JSON object"
  let backends ← (← arrayField j "backends").mapM backendOf
  let registrations ← (← arrayField j "registrations").mapM registrationOf
  return { backends, registrations }

/-- Read the manifest at `path`. -/
def read (path : System.FilePath) : IO (Except String Manifest) := do
  let text ← IO.FS.readFile path
  return Json.parse text >>= parse

end Manifest

end CasCatalogue
