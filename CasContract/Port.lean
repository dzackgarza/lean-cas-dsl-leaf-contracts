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
* any other constructor application is `{"ctor": <constructor>, "args": [<data fields>]}`, the
  constructor spelled by its short name within its type (`finite`, `aleph0`, `some`, `true`);
* a proof field is never on the wire.

An answer is a value of the operation's declared result form in this encoding. The kernel decodes
it against that form, deciding every condition the form imposes, or rejects it; nothing in an
answer beyond its value is read.
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
