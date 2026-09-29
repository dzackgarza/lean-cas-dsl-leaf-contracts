/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Registry.Extension
public import CasContract.Failure
public import Lean.Data.Json

@[expose] public section

/-!
# The backend port (CC-ADAPTER)

The core owns this protocol and its contract, never a backend program: each leaf owns the
program behind its port, in whatever language its engine needs.

A backend is a child process speaking length-prefixed JSON frames (the ASCII decimal byte length,
a newline, the UTF-8 payload; a Python reference implementation is this package's
`python/cas_port.py`, on the `PYTHONPATH` of every adapter `connect` starts).
It first announces itself and its
capabilities, then answers requests `{request_id, op, args}` with `{request_id, status, value}`.

Its operations are keyed by registered semantic operations: every capability it announces must be
declared for it by a registered `backendOperation` row naming a registered limit or method, or the
connection is refused (`connect`). Its answers are untrusted JSON, decoded by the row's decoder into
the operation's semantic result type, or rejected. The framing follows `CasDsl.Port`.
-/

open Lean

namespace CasCatalogue.Backend

/-- Why a backend call failed. -/
inductive PortError
  /-- The backend is not installed or cannot start. -/
  | unavailable (backend reason : String)
  /-- The adapter broke the protocol. -/
  | protocol (message : String)
  /-- The adapter announced an operation not declared for it on a registered operation. -/
  | contract (message : String)
  /-- The backend reported an error for a request. -/
  | backend (kind message : String)
  /-- The answer is not a value of the operation's result type: its decoder rejected it. -/
  | malformed (operation message : String)
  deriving Repr, Inhabited

/-- The stratum of a port failure. A backend that cannot start or that reports an error is
unavailable. An answer outside the protocol or rejected by its decoder is malformed. A connection
refused for announcing undeclared operations is unavailable: the realization is not admitted. -/
def PortError.stratum : PortError → Stratum
  | .unavailable .. | .contract _ | .backend .. => .unavailable
  | .protocol _ | .malformed .. => .malformed

def PortError.render : PortError → String
  | .unavailable b r => s!"{b} is unavailable: {r}"
  | .protocol m => s!"protocol error: {m}"
  | .contract m => s!"contract violation: {m}"
  | .backend k m => s!"backend error ({k}): {m}"
  | .malformed o m => s!"the answer to {o} is not a value of its result type: {m}"

/-- What an adapter announces. -/
structure Ready where
  backend : String
  backendVersion : String
  capabilities : Array String

abbrev Stdio : IO.Process.StdioConfig := { stdin := .piped, stdout := .piped, stderr := .inherit }

/-- A connection to a started adapter. -/
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
  catch e => return .error (.protocol s!"cannot read from the adapter: {e}")

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

def abort (child : IO.Process.Child Stdio) : IO Unit := do
  try child.kill catch _ => pure ()
  try discard child.wait catch _ => pure ()

/-- Close the adapter's input (its shutdown signal) and reap it. -/
def stop (c : Conn) : IO Unit := do
  let (_stdin, child) ← c.child.takeStdin
  try discard child.wait catch _ => pure ()

/-- The operations declared for `backend` by registered rows. -/
def declaredOperations (state : RegistryState) (backend : String) : Array String :=
  (state.backendOperations.filter (·.backend == backend)).map (·.operation)

/-- The directory of the Lake package `package` in the workspace being run: `.lake/packages/package`
when it is a dependency, the working directory when it is the root. -/
def packageDir (package : String) : IO System.FilePath := do
  let dependency : System.FilePath := ".lake" / "packages" / package
  return if ← dependency.pathExists then dependency else "."

/-- The file `path` of the Lake package `package` (a leaf's adapter program, say). -/
def packageFile (package : String) (path : System.FilePath) : IO String :=
  return ((← packageDir package) / path).toString

/-- The name of this package, whose `python/` holds the port's reference implementation. -/
def contractPackage : String := "cas_leaf_contracts"

/-- Start `cmd args` as the adapter of `backend` and check its announcement: it is `backend`, and
every capability is an operation declared for it on a registered semantic operation. -/
def connect (state : RegistryState) (backend cmd : String) (args : Array String := #[]) :
    IO (Except PortError Conn) := do
  unless ← System.FilePath.pathExists cmd do
    return .error (.unavailable backend s!"{cmd} does not exist")
  -- The adapter finds the reference implementation `cas_port` on its `PYTHONPATH`.
  let portPython := (← packageDir contractPackage) / "python"
  let path := match ← IO.getEnv "PYTHONPATH" with
    | some p => s!"{portPython}:{p}"
    | none => portPython.toString
  let child ← try
      IO.Process.spawn { toStdioConfig := Stdio, cmd, args, env := #[("PYTHONPATH", some path)] }
    catch e => return .error (.unavailable backend s!"cannot spawn {cmd}: {e}")
  let ready ← match (← readFrame child.stdout) >>= readyOf with
    | .ok ready => pure ready
    | .error e => abort child; return .error (match e with
        | .protocol m => .unavailable backend s!"no ready frame ({m})"
        | e => e)
  unless ready.backend == backend do
    abort child
    return .error (.contract s!"the adapter announced {ready.backend}, not {backend}")
  let declared := declaredOperations state backend
  let undeclared := ready.capabilities.filter (!declared.contains ·)
  unless undeclared.isEmpty do
    abort child
    return .error (.contract s!"{backend} announces operations not declared on registered \
      semantic operations: {undeclared.toList}")
  return .ok { child, ready, nextId := ← IO.mkRef 1 }

/-- Send one request and read its answer's value. -/
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

/-- Call `op` and decode its answer with the operation's registered decoder: a rejection is
`malformed`, never a value. -/
def callDecoded {τ : Type} (c : Conn) (op : String) (args : Json)
    (decode : Json → Except String τ) : IO (Except PortError τ) := do
  return (← call c op args) >>= fun answer =>
    (decode answer).mapError fun m => .malformed op m

end CasCatalogue.Backend
