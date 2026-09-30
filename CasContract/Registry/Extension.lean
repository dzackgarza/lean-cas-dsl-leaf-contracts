/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import LeanCategories.Catalogue.Registry.Semantic
public import Lean.Data.Json
public import Lean

@[expose] public section

set_option backward.privateInPublic true

/-!
# The registry: `lean-categories`' semantic registry, read by the kernel

The rows are `lean-categories`' (`LeanCategories.Catalogue.Registry.Semantic`), read here from the
pinned release; this repository writes none (`specs/architecture.md`). The kernel reads them
through `RegistryState`, and exports them as a manifest (`checkedRegistryManifest`).

A leaf contributes no row of any kind (`specs/leaf-registration.md`, "A registration is data"):
it is a manifest of registrations (`CasContract.Registration`), which the kernel admits against
these rows. Nothing a leaf supplies is recorded here.
-/

namespace CasCatalogue
open LeanCategories

open Lean
open Lean Meta
open Lean Elab Command

/-- A row of the registry: exactly a semantic row of the catalogue. -/
inductive RegistryEntry
  | category (e : NamedCategoryEntry)
  | categoryFamily (e : CategoryFamilyEntry)
  | classifier (e : ClassifierEntry)
  | functor (e : FunctorEntry)
  | opaque (e : OpaqueCategoryEntry)
  | fibration (e : FibrationEntry)
  | constructor (e : ConstructorEntry)
  | method (e : MethodEntry)
  | property (e : PropertyEntry)
  | lift (e : LiftEntry)
  | cell (e : CellEntry)
  | limit (e : LimitEntry)
  | adjunction (e : AdjunctionEntry)
  | object (e : ObjectEntry)
  | literal (e : LiteralEntry)
  | numeral (e : NumeralEntry)
  | graphLiteral (e : GraphLiteralEntry)
  | morphism (e : MorphismEntry)
  | operation (e : OperationEntry)
  | inclusion (e : InclusionEntry)
  | powerObject (e : PowerObjectEntry)
  deriving Repr

/-- The semantic row a registry row is. -/
def RegistryEntry.toSemantic : RegistryEntry → SemanticEntry
  | .category e => .category e
  | .categoryFamily e => .categoryFamily e
  | .classifier e => .classifier e
  | .functor e => .functor e
  | .opaque e => .opaque e
  | .fibration e => .fibration e
  | .constructor e => .constructor e
  | .method e => .method e
  | .property e => .property e
  | .lift e => .lift e
  | .cell e => .cell e
  | .limit e => .limit e
  | .adjunction e => .adjunction e
  | .object e => .object e
  | .literal e => .literal e
  | .numeral e => .numeral e
  | .graphLiteral e => .graphLiteral e
  | .morphism e => .morphism e
  | .operation e => .operation e
  | .inclusion e => .inclusion e
  | .powerObject e => .powerObject e

/-- A semantic row, as a registry row. -/
def RegistryEntry.ofSemantic : SemanticEntry → RegistryEntry
  | .category e => .category e
  | .categoryFamily e => .categoryFamily e
  | .classifier e => .classifier e
  | .functor e => .functor e
  | .opaque e => .opaque e
  | .fibration e => .fibration e
  | .constructor e => .constructor e
  | .method e => .method e
  | .property e => .property e
  | .lift e => .lift e
  | .cell e => .cell e
  | .limit e => .limit e
  | .adjunction e => .adjunction e
  | .object e => .object e
  | .literal e => .literal e
  | .numeral e => .numeral e
  | .graphLiteral e => .graphLiteral e
  | .morphism e => .morphism e
  | .operation e => .operation e
  | .inclusion e => .inclusion e
  | .powerObject e => .powerObject e

/-- Stable identifier of a registry row. -/
def RegistryEntry.stableId (entry : RegistryEntry) : String := entry.toSemantic.stableId

/-- Lean declarations a row names. -/
def RegistryEntry.declarations (entry : RegistryEntry) : Array Name :=
  entry.toSemantic.declarations

/-- The registry: the imported semantic registry, and nothing else. -/
structure RegistryState extends SemanticState
  deriving Inhabited

instance : Coe RegistryState SemanticState := ⟨RegistryState.toSemanticState⟩

/-- Every row. -/
def RegistryState.registryEntries (state : RegistryState) : List RegistryEntry :=
  state.toSemanticState.entries.map RegistryEntry.ofSemantic

/-- Whether this row's stable ID conflicts with a registered row. -/
def RegistryState.hasEntryId (state : RegistryState) (entry : RegistryEntry) : Bool :=
  state.toSemanticState.hasEntryId entry.toSemantic

/-- The registry of the current environment, read-only: `lean-categories`' semantic rows. Nothing
in this repository, the kernel or a leaf writes to it. -/
def registryState : CoreM RegistryState := do
  return { toSemanticState := ← semanticState }

/-- Inspect a row's declarations: by `lean-categories`' validators, which every row is. -/
def validateRegistryEntryDeclaration (entry : RegistryEntry) : MetaM Unit :=
  validateSemanticEntryDeclaration entry.toSemantic

/-- The notebook's roots: it registers nothing (`CasDslTests.Boundary`). -/
def notebookRoots : List Name := [`CasDsl, `CasDslTests]

/-- Every registry row, grouped by the imported module that wrote it. -/
def registryRowsByModule (env : Environment) : Array (Name × Array RegistryEntry) :=
  (semanticRowsByModule env).map fun (module, rows) =>
    (module, rows.map RegistryEntry.ofSemantic)

private def registryObject (fields : List (String × Json)) : Json := Json.mkObj fields

structure RegistryManifestParameter where
  ids : Array String
  name : String
  kind : String
  dependency : Option Nat
  deriving DecidableEq, Repr, ToJson, FromJson

inductive RegistryManifestParameterExpr
  | variable (id : String)
  | apply (operation : String) (argument : RegistryManifestParameterExpr)
  | apply2 (operation : String) (left right : RegistryManifestParameterExpr)
  | apply3 (operation : String)
      (first second third : RegistryManifestParameterExpr)
  deriving DecidableEq, Repr

private def registryManifestParameterExprJson : RegistryManifestParameterExpr → Json
  | .variable id => registryObject [("tag", "variable"), ("id", id)]
  | .apply operation argument => registryObject [
      ("tag", "apply"), ("operation", operation),
      ("argument", registryManifestParameterExprJson argument)]
  | .apply2 operation left right => registryObject [
      ("tag", "apply2"), ("operation", operation),
      ("left", registryManifestParameterExprJson left),
      ("right", registryManifestParameterExprJson right)]
  | .apply3 operation first second third => registryObject [
      ("tag", "apply3"), ("operation", operation),
      ("first", registryManifestParameterExprJson first),
      ("second", registryManifestParameterExprJson second),
      ("third", registryManifestParameterExprJson third)]

instance : ToJson RegistryManifestParameterExpr where
  toJson := registryManifestParameterExprJson

private partial def registryManifestParameterExprOfJson : Json → Except String RegistryManifestParameterExpr :=
  fun j => do
    let tag ← j.getObjValAs? String "tag"
    match tag with
    | "variable" => .variable <$> j.getObjValAs? String "id"
    | "apply" => .apply <$> j.getObjValAs? String "operation" <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "argument")
    | "apply2" => .apply2 <$> j.getObjValAs? String "operation" <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "left") <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "right")
    | "apply3" => .apply3 <$> j.getObjValAs? String "operation" <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "first") <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "second") <*> registryManifestParameterExprOfJson (← j.getObjValAs? Json "third")
    | _ => throw s!"unknown parameter expression tag: {tag}"

instance : FromJson RegistryManifestParameterExpr where
  fromJson? := registryManifestParameterExprOfJson

mutual

inductive RegistryManifestConstructorArg
  | category (category : RegistryManifestCategoryExpr)
  | object (id : String)
  | functor (id : String)

inductive RegistryManifestCategoryExpr
  | atom (id : String)
  | familyApp (family : String) (args : Array RegistryManifestParameterExpr)
  | classifierTotal (classifier : String)
  | refine (base : RegistryManifestCategoryExpr) (classifier : String)
  | opaque (id : String)
  | familyTotal (family : String)
  | construct (constructor : String) (args : Array RegistryManifestConstructorArg)

end

deriving instance BEq, Repr for RegistryManifestConstructorArg, RegistryManifestCategoryExpr

private partial def registryManifestCategoryExprJson : RegistryManifestCategoryExpr → Json
  | .atom id => registryObject [("tag", "atom"), ("id", id)]
  | .familyApp family args => registryObject [
      ("tag", "familyApp"), ("family", family), ("args", toJson args)]
  | .classifierTotal classifier => registryObject [
      ("tag", "classifierTotal"), ("classifier", classifier)]
  | .refine base classifier => registryObject [
      ("tag", "refine"), ("base", registryManifestCategoryExprJson base),
      ("classifier", classifier)]
  | .opaque id => registryObject [("tag", "opaque"), ("id", id)]
  | .familyTotal family => registryObject [("tag", "familyTotal"), ("family", family)]
  | .construct constructor args => registryObject [
      ("tag", "construct"), ("constructor", constructor),
      ("args", Json.arr (args.map fun
        | .category category => registryObject [
            ("tag", "category"), ("category", registryManifestCategoryExprJson category)]
        | .object id => registryObject [("tag", "object"), ("id", id)]
        | .functor id => registryObject [("tag", "functor"), ("id", id)]))]

instance : ToJson RegistryManifestCategoryExpr where
  toJson := registryManifestCategoryExprJson

instance : Inhabited RegistryManifestCategoryExpr := ⟨.atom ""⟩

/-- Decode a constructor argument, given the category-expression decoder. -/
private def constructorArgOfJson
    (category : Json → Except String RegistryManifestCategoryExpr) (arg : Json) :
    Except String RegistryManifestConstructorArg := do
  match ← arg.getObjValAs? String "tag" with
  | "category" => .category <$> category (← arg.getObjValAs? Json "category")
  | "object" => .object <$> arg.getObjValAs? String "id"
  | "functor" => .functor <$> arg.getObjValAs? String "id"
  | tag => throw s!"unknown constructor argument tag: {tag}"

private partial def registryManifestCategoryExprOfJson : Json → Except String RegistryManifestCategoryExpr :=
  fun j => do
    let tag ← j.getObjValAs? String "tag"
    match tag with
    | "atom" => .atom <$> j.getObjValAs? String "id"
    | "familyApp" => .familyApp <$> j.getObjValAs? String "family" <*> j.getObjValAs? _ "args"
    | "classifierTotal" => .classifierTotal <$> j.getObjValAs? String "classifier"
    | "refine" => .refine <$> registryManifestCategoryExprOfJson (← j.getObjValAs? Json "base") <*> j.getObjValAs? String "classifier"
    | "opaque" => .opaque <$> j.getObjValAs? String "id"
    | "familyTotal" => .familyTotal <$> j.getObjValAs? String "family"
    | "construct" => do
        let constructor ← j.getObjValAs? String "constructor"
        let args ← j.getObjValAs? (Array Json) "args"
        let args ← args.mapM (constructorArgOfJson registryManifestCategoryExprOfJson)
        pure (.construct constructor args)
    | _ => throw s!"unknown category expression tag: {tag}"

instance : FromJson RegistryManifestCategoryExpr where
  fromJson? := registryManifestCategoryExprOfJson

inductive RegistryManifestFunctorExpr
  | identity (category : RegistryManifestCategoryExpr)
  | atomic (id : String)
  | classifierForget (classifier : String) (host : RegistryManifestCategoryExpr)
  | opaquePort (id : String)
  | familyFibreInclusion (family : String) (args : Array RegistryManifestParameterExpr)
  | familyReindex (family morphism : String)
      (source target : Array RegistryManifestParameterExpr)
  | comp (left right : RegistryManifestFunctorExpr)
  | constructMap (constructor : String) (functor : RegistryManifestFunctorExpr)
  deriving BEq, Repr

private partial def registryManifestFunctorExprJson : RegistryManifestFunctorExpr → Json
  | .identity category => registryObject [("tag", "identity"), ("category", toJson category)]
  | .atomic id => registryObject [("tag", "atomic"), ("id", id)]
  | .classifierForget classifier host => registryObject [
      ("tag", "classifierForget"), ("classifier", classifier), ("host", toJson host)]
  | .opaquePort id => registryObject [("tag", "opaquePort"), ("id", id)]
  | .familyFibreInclusion family args => registryObject [
      ("tag", "familyFibreInclusion"), ("family", family), ("args", toJson args)]
  | .familyReindex family morphism source target => registryObject [
      ("tag", "familyReindex"), ("family", family), ("morphism", morphism),
      ("source", toJson source), ("target", toJson target)]
  | .comp left right => registryObject [
      ("tag", "comp"), ("left", registryManifestFunctorExprJson left),
      ("right", registryManifestFunctorExprJson right)]
  | .constructMap constructor functor => registryObject [
      ("tag", "constructMap"), ("constructor", constructor),
      ("functor", registryManifestFunctorExprJson functor)]

instance : ToJson RegistryManifestFunctorExpr where
  toJson := registryManifestFunctorExprJson

private partial def registryManifestFunctorExprOfJson : Json → Except String RegistryManifestFunctorExpr
  | j => do
    let tag ← j.getObjValAs? String "tag"
    match tag with
    | "identity" => .identity <$> j.getObjValAs? _ "category"
    | "atomic" => .atomic <$> j.getObjValAs? String "id"
    | "classifierForget" =>
        .classifierForget <$> j.getObjValAs? String "classifier" <*> j.getObjValAs? _ "host"
    | "opaquePort" => .opaquePort <$> j.getObjValAs? String "id"
    | "familyFibreInclusion" =>
        .familyFibreInclusion <$> j.getObjValAs? String "family" <*> j.getObjValAs? _ "args"
    | "familyReindex" =>
        .familyReindex <$> j.getObjValAs? String "family" <*> j.getObjValAs? String "morphism"
          <*> j.getObjValAs? _ "source" <*> j.getObjValAs? _ "target"
    | "comp" => .comp <$> (registryManifestFunctorExprOfJson (← j.getObjValAs? _ "left")) <*>
        (registryManifestFunctorExprOfJson (← j.getObjValAs? _ "right"))
    | "constructMap" => .constructMap <$> j.getObjValAs? String "constructor" <*>
        (registryManifestFunctorExprOfJson (← j.getObjValAs? _ "functor"))
    | _ => throw s!"unknown functor expression tag: {tag}"

instance : FromJson RegistryManifestFunctorExpr where
  fromJson? := registryManifestFunctorExprOfJson

structure RegistryManifestCategory where
  id : String
  declaration : String
  realization : String
  refinementRealization : String
  expression : RegistryManifestCategoryExpr
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestFamily where
  id : String
  schema : String
  realization : String
  transport : String
  parameters : Array RegistryManifestParameter
  variance : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestClassifier where
  id : String
  host : RegistryManifestCategoryExpr
  declaration : String
  realization : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestFunctor where
  id : String
  source : RegistryManifestCategoryExpr
  target : RegistryManifestCategoryExpr
  declaration : String
  realization : String
  expression : RegistryManifestFunctorExpr
  structural : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestPort where
  id : String
  source : RegistryManifestCategoryExpr
  target : RegistryManifestCategoryExpr
  declaration : String
  realization : String
  provenance : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestOpaque where
  id : String
  declaration : String
  realization : String
  reason : String
  ports : Array RegistryManifestPort
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestFibration where
  id : String
  projection : String
  variance : String
  evidence : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestConstructor where
  id : String
  signature : Array String
  semantics : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestMethod where
  id : String
  name : String
  owner : RegistryManifestCategoryExpr
  functor : String
  shape : String
  returnsToSource : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestCell where
  id : String
  source : RegistryManifestCategoryExpr
  target : RegistryManifestCategoryExpr
  left : Array String
  right : Array String
  declaration : String
  invertible : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestLimit where
  id : String
  category : String
  shape : String
  declaration : String
  colimit : Bool
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestObject where
  id : String
  category : String
  declaration : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestAdjunction where
  id : String
  left : String
  right : String
  declaration : String
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestProperty where
  id : String
  name : String
  classifier : String
  receiver : Option RegistryManifestCategoryExpr
  deriving BEq, Repr, ToJson, FromJson

structure RegistryManifestLift where
  id : String
  edge : String
  evidence : String
  kind : String
  deriving BEq, Repr, ToJson, FromJson

/-- The exported registry: the semantic rows of the catalogue. No row of a leaf exists to export. -/
structure RegistryManifest where
  schemaVersion : String
  categories : Array RegistryManifestCategory
  classifiers : Array RegistryManifestClassifier
  functors : Array RegistryManifestFunctor
  opaqueCategories : Array RegistryManifestOpaque
  categoryFamilies : Array RegistryManifestFamily
  fibrations : Array RegistryManifestFibration
  constructors : Array RegistryManifestConstructor
  methods : Array RegistryManifestMethod
  properties : Array RegistryManifestProperty
  lifts : Array RegistryManifestLift
  cells : Array RegistryManifestCell
  limits : Array RegistryManifestLimit
  adjunctions : Array RegistryManifestAdjunction
  objects : Array RegistryManifestObject
  source : String
  deriving BEq, Repr, ToJson, FromJson

private def registryManifestParameterExpr : ParameterExpr → RegistryManifestParameterExpr
  | .variable id => .variable id.raw
  | .apply operation argument => .apply operation.raw (registryManifestParameterExpr argument)
  | .apply2 operation left right =>
      .apply2 operation.raw (registryManifestParameterExpr left) (registryManifestParameterExpr right)
  | .apply3 operation first second third =>
      .apply3 operation.raw (registryManifestParameterExpr first)
        (registryManifestParameterExpr second) (registryManifestParameterExpr third)

private partial def registryManifestCategoryExpr : CategoryExpr → RegistryManifestCategoryExpr
  | .atom id => .atom id.raw
  | .familyApp family args => .familyApp family.raw (args.map registryManifestParameterExpr)
  | .classifierTotal classifier => .classifierTotal classifier.raw
  | .refine base classifier => .refine (registryManifestCategoryExpr base) classifier.raw
  | .opaque id => .opaque id.raw
  | .familyTotal family => .familyTotal family.raw
  | .construct constructor args => .construct constructor.raw (args.map fun
      | .category category => .category (registryManifestCategoryExpr category)
      | .object id => .object id.raw
      | .functor id => .functor id.raw)

private def registryManifestFunctorExpr {source target : CategoryExpr} :
    FunctorExpr source target → RegistryManifestFunctorExpr
  | .identity category => .identity (registryManifestCategoryExpr category)
  | .atomic id => .atomic id.raw
  | .classifierForget classifier host =>
      .classifierForget classifier.raw (registryManifestCategoryExpr host)
  | .opaquePort id => .opaquePort id.raw
  | .familyFibreInclusion family args =>
      .familyFibreInclusion family.raw (args.map registryManifestParameterExpr)
  | .familyReindex family morphism source target =>
      .familyReindex family.raw morphism.raw (source.map registryManifestParameterExpr)
        (target.map registryManifestParameterExpr)
  | .comp left right => .comp (registryManifestFunctorExpr left) (registryManifestFunctorExpr right)
  | .constructMap constructor functor =>
      .constructMap constructor.raw (registryManifestFunctorExpr functor)

private def registryManifestSchema : CategoryFamilySchema → String
  | .ring => "ring"
  | .commRing => "commRing"
  | .commRingModule => "commRingModule"
  | .commRingNat => "commRingNat"
  | .commRingIndexType => "commRingIndexType"
  | .domain => "domain"

private def registryManifest (state : RegistryState) : RegistryManifest :=
  let cats := state.categories.qsort (fun a b => a.id.raw < b.id.raw)
  let families := state.categoryFamilies.qsort (fun a b => a.id.raw < b.id.raw)
  let clfs := state.classifiers.qsort (fun a b => a.id.raw < b.id.raw)
  let functors := state.functors.qsort (fun a b => a.id.raw < b.id.raw)
  let opaqueEntries := state.opaqueCategories.qsort (fun a b => a.id.raw < b.id.raw)
  { schemaVersion := "0.3.0-semantic"
    categories := cats.map fun e => {
      id := e.id.raw, declaration := e.declaration.toString,
      realization := e.realization.toString,
      refinementRealization := e.refinementRealization.map Lean.Name.toString |>.getD "",
      expression := registryManifestCategoryExpr e.expression }
    classifiers := clfs.map fun e => {
      id := e.id.raw,
      host := registryManifestCategoryExpr e.host, declaration := e.declaration.toString,
      realization := e.realization.toString }
    functors := functors.map fun e => {
      id := e.id.raw,
      source := registryManifestCategoryExpr e.source, target := registryManifestCategoryExpr e.target,
      declaration := e.declaration.toString, realization := e.realization.toString,
      expression := registryManifestFunctorExpr e.expression, structural := e.structural }
    opaqueCategories := opaqueEntries.map fun e => {
      id := e.id.raw, declaration := e.declaration.toString, realization := e.realization.toString,
      reason := e.reason,
      ports := e.ports.map fun p => {
        id := p.id.raw, source := registryManifestCategoryExpr p.source,
        target := registryManifestCategoryExpr p.target, declaration := p.declaration.toString,
        realization := p.realization.toString, provenance := p.provenance } }
    categoryFamilies := families.map fun e => {
      id := e.id.raw,
      schema := registryManifestSchema e.schema,
      realization := e.realization.toString, transport := e.transport.toString,
      parameters := e.schema.parameterMetadata.map fun parameter => {
        ids := parameter.ids.toArray.map (·.raw), name := parameter.name,
        kind := parameter.kind.raw, dependency := parameter.dependency },
      variance := e.transportSemantics.variance.raw }
    fibrations := (state.fibrations.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, projection := e.projection.raw,
      variance := match e.variance with
        | .cartesian => "cartesian"
        | .cocartesian => "cocartesian",
      evidence := e.evidence.toString }
    constructors := (state.constructors.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, semantics := e.semantics.toString,
      signature := e.signature.map fun
        | .category => "category"
        | .object => "object"
        | .functor => "functor" }
    methods := (state.methods.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, name := e.name, owner := registryManifestCategoryExpr e.owner,
      functor := e.functor.raw,
      shape := match e.shape with
        | .object => "object"
        | .isoInvariant => "isoInvariant",
      returnsToSource := e.returnsToSource }
    properties := (state.properties.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, name := e.name, classifier := e.classifier.raw,
      receiver := e.receiver.map registryManifestCategoryExpr }
    lifts := (state.lifts.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, edge := e.edge.label, evidence := e.evidence.toString
      kind := match e.kind with
        | .subobjects => "subobjects"
        | .createsLimits shape => s!"creates_limits:{shape}" }
    cells := (state.cells.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, source := registryManifestCategoryExpr e.source,
      target := registryManifestCategoryExpr e.target, left := e.left.map (·.label),
      right := e.right.map (·.label), declaration := e.declaration.toString,
      invertible := e.invertible }
    limits := (state.limits.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, category := e.category.raw, shape := e.shape,
      declaration := e.declaration.toString, colimit := e.colimit }
    adjunctions := (state.adjunctions.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, left := e.left.raw, right := e.right.raw,
      declaration := e.declaration.toString }
    objects := (state.objects.qsort (fun a b => a.id.raw < b.id.raw)).map fun e => {
      id := e.id.raw, category := e.category.raw, declaration := e.declaration.toString }
    source := "lean-registry" }

private def registryManifestJson (state : RegistryState) : Json := toJson (registryManifest state)

/-- Return the manifest produced from the checked persistent registry state. -/
def checkedRegistryManifestDTO : CoreM RegistryManifest := do
  let state ← registryState
  match validatePersistedSemanticState state.toSemanticState with
  | .error message => throwError message
  | .ok () => pure (registryManifest state)

def checkedRegistryManifest : CoreM Json := do
  return toJson (← checkedRegistryManifestDTO)

end CasCatalogue
