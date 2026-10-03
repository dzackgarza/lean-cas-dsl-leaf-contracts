/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Failure
public import Lean.Data.Json

@[expose] public section

/-!
# The backend port (`specs/leaf-registration.md`, "A registration is data")

The kernel owns this protocol; a leaf owns the program behind its port, in whatever language its
engine needs. Only data crosses it: the kernel's encoding of an input goes out, and JSON comes
back, which the kernel decodes in the operation's declared result form or rejects. No Lean crosses
it in either direction.

A backend is a child process speaking length-prefixed JSON frames (the ASCII decimal byte length,
a newline, the UTF-8 payload; a Python reference implementation is this package's
`python/cas_port.py`, on the `PYTHONPATH` of every program the kernel starts). It first announces
itself (`{op: "ready", backend, backend_version, capabilities}`; nothing in the announcement is
believed or consulted), then answers requests `{request_id, op, args}` with
`{request_id, status, value}`, where `op` is a registration's operation id and `args` the encoded
input. Which operations are called on it is the admitted registrations' (`CasCatalogue.Admission`).

## The wire encoding of inputs and answers

The kernel's codec (`CasCatalogue.Codec`) fixes one structural encoding, derived from each form's
inductive type; a leaf reads and writes exactly this, and nothing else:

* an input object is a named object of the catalogue at its parameters,
  `{"ctor": <object id>, "args": [<parameters>]}`; a parameter that is itself a named object is
  encoded the same way;
* a natural number or an integer is a JSON number; a list is a JSON array; a `Multiset` or a
  `Finset` is a list of its elements;
* a record (one constructor, no indices: a pair, a point of `Fin n`, a subtype) is the JSON array
  of its data fields, or that field alone when it has exactly one (a point of `Fin n` is its
  number, a pair is `[x, y]`);
* a function whose domain has an independently synthesized finite enumeration is a graph,
  a list of pairs `[x, f x]`, including every domain point exactly once. This also applies
  to function data fields of a record; all declared field conditions are checked. Thus an
  equivalence's two function fields retain both forward and inverse graphs, while its proof
  fields are omitted. Function encoding does not change the selected source or target type;
* any other constructor application is `{"ctor": <constructor>, "args": [<data fields>]}`, the
  constructor spelled by its short name within its type (`finite`, `aleph0`, `some`, `true`);
* a proof field is never on the wire;
* a morphism of a concrete category is its graph, a list of pairs `[x, f x]` of points;
  a registered named morphism may instead be encoded as
  `{"ctor": <morphism id>, "args": [<explicit parameters>]}`. Its declaration fixes the
  parameter types and endpoints; this permits named arrows on infinite carriers without
  enumerating a graph. The kernel checks the instantiated endpoints against the requested arrow;
* the action of a registered functor on an arrow may be represented as
  `{"ctor":"map","args":[{"ctor":<functor id>,"args":[<explicit parameters>]},<arrow>]}`.
  Structural classifier-forget edges use
  `{"ctor":"classifierForget","args":[<registered classifier id>,
  [<ordered actual classifier declaration arguments>]]}`; a registered
  constructor's derived action uses
  `{"ctor":"constructorMap","args":[<registered constructor id>,<inner edge descriptor>]}`.
  These descriptors name the actual registered edge; they do not invent a functor row.
  The arrow uses its source-category encoding. The registered functor and its exact parameters
  determine the resulting arrow and endpoints. Composition is
  `{"ctor":"compose","args":[<first arrow>,<second arrow>]}` in categorical order
  (first, then second); both arrows are checked at their shared endpoint. Accepted presentation
  changes retain their actual comparison arrows in this composition, never an endpoint rename;
* a diagram, the input of a registered limit or colimit, is registered on the form of its
  category (`"input": "cat.sets"`) and sent as Mathlib's standard constructor of its shape with
  its explicit arguments, `{"ctor": "pair", "args": [X, Y]}` or
  `{"ctor": "cospan", "args": [f, g]}`, objects and arrows in their own encodings.
  A retained parallel-arrow diagram is `{"ctor":"parallelPair","args":[f,g]}`.
  Its cone or cocone has one defining arrow, so the reply is respectively
  `{"ctor":"cone","args":[<apex>,<inclusion>]}` or
  `{"ctor":"cocone","args":[<apex>,<projection>]}`. The two arrows in the request
  are retained exactly, including a registered trivial or zero arrow where the
  mathematical declaration specifies one; a shape label does not replace an arrow.

A registered functor's object action receives
`{"ctor": <functor id>, "args": [<ordered explicit declaration arguments>],
"receiver": <source object data>}`. The registered declaration determines the argument
types, source and target, including dependent parameters. The kernel checks those types and
endpoints; a backend cannot choose the functor or its parameters. The result is decoded in
the declared target form.

An object of a registered arrow category uses
`{"ctor":"arrow","args":[<source object>,<target object>,<defining map>]}`,
registered on that arrow category's id. Both endpoints retain their selected object data;
the map is decoded at those exact endpoints. This is an arrow-category object, so its
applicable methods are those declared for that category; a bare named map is not retyped
as an object of its source or target category.

The stored map of a complete arrow object may be described by
`{"ctor":"arrowHom","args":[<complete arrow object data>]}`. The receiver must decode in
an independently fixed category with the registered arrow-constructor semantics. The result
is that object's actual stored defining map, at its exact full source and target. This does
not permit an arbitrary field projection, a new operation, or a different choice of endpoints.
For an `arrow` envelope above, the stored map is its third argument.

A value of a registered subobject category uses
`{"ctor":"subobject","args":[<apex object>,<ambient object>,<inclusion>]}`,
registered on that category's id. The inclusion is decoded at these exact endpoints;
its monomorphism condition is established independently by the kernel. The reply supplies
all three data fields and no proof. Prescribed lifts retain the resulting structured apex
and its defining inclusion, including the selected form and value object.

The kernel may encode a completed prescribed lift for subsequent computations as
`{"ctor":"liftedSubobject","args":[<original complete subobject reply>,
<source receiver data>,[<prescribed lift ids in route order>]]}`. It produces this data only
after constructing and checking the full lifted inclusion through the registered lifts.
It is not a backend's choice of lift or a backend proof.

A named object's registered generator arrow is
`{"ctor":"generator","args":[<registered named set object id>,
[<ordered explicit generator declaration arguments>]]}`. The declaration and its full
signature own the endpoint and any index; this descriptor does not introduce a new arrow row.
A selected structured object's carrier reaches that set only along its registered structure.

Closed points at selected named objects use
`{"ctor":"element","args":[<exact selected object descriptor>,<arithmetic data>]}`.
The descriptor includes every ordered parameter and must equal the independently selected
endpoint. Arithmetic data has only `ctor` and ordered `args`: `numeral` takes one natural
number, `generator` takes no argument or one natural index, `add` and `mul` take two data
expressions, and `neg` takes one. These tags invoke existing registered language operations;
they do not contain Lean source or choose an object by its carrier.

A registered comparison's point application is requested under that comparison id, with
`{"ctor":"presentationApply","args":[<ordered parameters>,<inverse boolean>,
<exact source descriptor>,<exact target descriptor>,<input point data>]}`. The reply is an
`element` envelope at the exact target, independently decoded and compared by the kernel.

A complete accepted structural functor action may be carried as
`{"ctor":"functorAction","args":[<exact edge descriptor>,<complete selected source object>]}`.
The kernel reconstructs the actual registered functor at its full parameters and applies it
to that source at the independently fixed target category. For a registered constructive
functor whose result is in the registered subobjects category, its canonical apex or inclusion
is described by `{"ctor":"subobjectApex","args":[<complete functorAction data>]}` or
`{"ctor":"subobjectInclusion","args":[<complete functorAction data>]}`. Only the
registered subobject construction's apex and defining inclusion may be projected. These are
categorical data descriptions, with exact expected types checked independently; they do not
name a new limit, supply a proof or choose a lift.

Canonical data from a registered limit or colimit uses
`{"ctor":"limitApex","args":[<registered limit id>,<complete diagram>]}` or
`{"ctor":"limitLeg","args":[<registered limit id>,<complete diagram>,<index>]}`.
The kernel instantiates the registered mathematical presentation and projects its apex or
leg. These descriptors contain no proof and assert no comparison with another apex.

The defining leg of a complete returned construction may instead use
`{"ctor":"constructionLeg","args":[<registered limit id>,<complete diagram>,
<complete returned cone or cocone envelope>,<exact typed index>]}`. The index is data at
the actual diagram's declared object type. The kernel independently reconstructs the full
returned cone or cocone for that same fixed construction, including every defining map and
any required checked presentation comparison, before projecting its actual leg. A different
apex's leg cannot be replaced by the canonical leg or identified by cardinality. Any endpoint
alignment must use the retained checked presentation maps. This is the existing registered
universal construction's defining-map projection, not a new mathematical operation.
`{"ctor":"zero","args":[<source object>,<target object>]}` requires the category's
actual zero-morphism structure. `identity` has the same endpoints syntax and requires equal
endpoints. Every constructed value is checked at its exact expected type.

An arrow of a registered presentation comparison is
`{"ctor":"presentation","args":[<comparison id>,[<ordered explicit parameters>],
<inverse boolean>]}`. False selects its forward arrow; true selects its inverse.
The registered comparison fixes both endpoints and the actual isomorphism. A structural
functor's action on this arrow uses the same `map` envelope as any other arrow.

An answer is a value of the operation's declared result form in this encoding. The answer of a
limit is its cone, `{"ctor": "cone", "args": [<apex>, <leg>, ...]}`, and of a colimit its cocone,
`{"ctor": "cocone", "args": [<apex>, <leg>, ...]}`: the apex a value of a registered form of the
category (a named object at its parameters), each leg a morphism. The kernel decodes every answer
against its form, deciding every condition the form imposes (for a cone: it rebuilds it with
Mathlib's standard constructor of the shape and decides that the legs commute), or rejects it as
malformed; nothing in an answer beyond its value is read.

A structured reply may additionally carry map data relating the independently declared
presentation of the requested diagram to the returned presentation:

```json
{"ctor":"cone","args":["<apex>","<legs>"],
 "presentation":{"hom":"<graph>","inv":"<graph>"}}
```

The same envelope is permitted for a cocone. `hom` runs from the independent presentation's
apex to the returned apex; `inv` runs in the reverse direction. Both use the declared
category's morphism encoding. These are computations, never proofs or a certificate. The
kernel decodes them at those exact endpoints, checks both inverse equations and compatibility
with every defining leg, and reconstructs the universal property from the independent
presentation. Missing or incorrect defining maps are malformed. A missing presentation
computation is a realization gap when the kernel cannot reconstruct the comparison itself;
it does not authorize replacing the requested diagram or its mathematical question.
-/

open Lean

namespace CasCatalogue.Backend

/-- Why a backend call failed. -/
inductive PortError
  /-- The backend is not installed or cannot start. -/
  | unavailable (backend reason : String)
  /-- The program broke the protocol. -/
  | protocol (message : String)
  /-- The backend reported an error for a request. -/
  | backend (kind message : String)
  deriving Repr, Inhabited

/-- The stratum of a port failure. A backend that cannot start or that reports an error is
unavailable. An answer outside the protocol is malformed. -/
def PortError.stratum : PortError → Stratum
  | .unavailable .. | .backend .. => .unavailable
  | .protocol _ => .malformed

def PortError.render : PortError → String
  | .unavailable b r => s!"{b} is unavailable: {r}"
  | .protocol m => s!"protocol error: {m}"
  | .backend k m => s!"backend error ({k}): {m}"

/-- What a program announces. Nothing here is consulted. -/
structure Ready where
  backend : String
  backendVersion : String
  capabilities : Array String

abbrev Stdio : IO.Process.StdioConfig := { stdin := .piped, stdout := .piped, stderr := .inherit }

/-- A connection to a started program. -/
structure Conn where
  child : IO.Process.Child Stdio
  ready : Ready
  nextId : IO.Ref Nat

def writeFrame (h : IO.FS.Handle) (j : Json) : IO Unit := do
  let bytes := j.compress.toUTF8
  h.putStr s!"{bytes.size}\n"
  h.write bytes
  h.flush

partial def readExact (h : IO.FS.Handle) (n : Nat) (acc : ByteArray) :
    IO (Option ByteArray) := do
  if acc.size ≥ n then return some acc
  let chunk ← h.read (USize.ofNat (n - acc.size))
  if chunk.size == 0 then return none
  readExact h n (acc ++ chunk)

def readFrame (h : IO.FS.Handle) : IO (Except PortError Json) := do
  try
    let line ← h.getLine
    let some n := line.trimAscii.toNat?
      | return .error (.protocol s!"bad frame length {repr line}")
    let some bytes ← readExact h n .empty
      | return .error (.protocol s!"EOF mid-frame (wanted {n} bytes)")
    let some payload := String.fromUTF8? bytes | return .error (.protocol "frame is not UTF-8")
    return (Json.parse payload).mapError fun e => .protocol s!"bad JSON frame: {e}"
  catch e => return .error (.protocol s!"cannot read from the program: {e}")

def field (j : Json) (k : String) : Except PortError Json :=
  (j.getObjVal? k).mapError fun _ => .protocol s!"field '{k}' missing in {j.compress}"

def str (j : Json) (k : String) : Except PortError String := do
  (← field j k).getStr?.mapError fun _ => .protocol s!"field '{k}' is not a string"

def readyOf (j : Json) : Except PortError Ready := do
  unless (← str j "op") == "ready" do throw (.protocol s!"expected a ready frame: {j.compress}")
  let caps ← (← field j "capabilities").getArr?.mapError fun _ =>
    .protocol "capabilities is not an array"
  return { backend := ← str j "backend", backendVersion := ← str j "backend_version"
           capabilities := ← caps.mapM fun c => c.getStr?.mapError fun _ =>
             .protocol "a capability is not a string" }

/-- Kill a program and reap it. Nothing it does on the way out is waited on or believed. -/
def abort (child : IO.Process.Child Stdio) : IO Unit := do
  try child.kill catch _ => pure ()
  try discard child.wait catch _ => pure ()

/-- Close the program's input (its shutdown signal) and reap it. -/
def stop (c : Conn) : IO Unit := do
  let (_stdin, child) ← c.child.takeStdin
  try discard child.wait catch _ => pure ()

/-- The directory of the Lake package `package` in the workspace being run: `.lake/packages/package`
when it is a dependency, the working directory when it is the root. -/
def packageDir (package : String) : IO System.FilePath := do
  let dependency : System.FilePath := ".lake" / "packages" / package
  return if ← dependency.pathExists then dependency else "."

/-- The name of this package, whose `python/` holds the port's reference implementation. -/
def contractPackage : String := "cas_leaf_contracts"

/-- Send one request and read its answer's value: untrusted JSON, which the kernel decodes in the
operation's result form or rejects. -/
def call (c : Conn) (op : String) (args : Json) : IO (Except PortError Json) := do
  let id ← c.nextId.modifyGet fun n => (n, n + 1)
  try writeFrame c.child.stdin (Json.mkObj [("request_id", toJson id), ("op", op), ("args", args)])
  catch e => return .error (.protocol s!"cannot send {op}: {e}")
  let reply? ← readFrame c.child.stdout
  return do
    let reply ← reply?
    unless (reply.getObjValAs? Nat "request_id").toOption == some id do
      throw (.protocol s!"the reply does not answer request {id}")
    match ← str reply "status" with
    | "ok" => field reply "value"
    | "error" => throw (.backend (← str reply "kind") (← str reply "message"))
    | status => throw (.protocol s!"{c.ready.backend} answered {op} with status {status}")

end CasCatalogue.Backend
