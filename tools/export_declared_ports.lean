module
import LeanCategories.Catalogue
meta import LeanCategories.Catalogue
open Lean Meta Elab Command CasCatalogue
set_option pp.explicit true
set_option pp.universes true
set_option pp.fullNames true
run_cmd do
  let result : Json ← liftTermElabM do
    let state ← semanticState
    -- Explicit lift choices may use a non-structural functor. Reading its
    -- declared source does not add it to automatic semantic resolution.
    let rec sourceOf? : EdgeRef → Option CategoryExpr
      | .functor id => (state.functor? id).map (·.source)
      | .classifierForget id => (state.structuralEdge? (.classifierForget id)).map (·.source)
      | .constructMap id inner => do
          let constructor ← state.constructor? id
          guard constructor.functorialAction.isSome
          return .construct id #[.category (← sourceOf? inner)]
    let declarations ← IO.mkRef (#[] : Array Name)
    let describe (name : Name) : TermElabM Json := do
      declarations.modify (·.push name)
      let info ← getConstInfo name
      let resultType ← forallTelescope info.type fun params result => do
        let result ← whnf result
        let closed ← mkForallFVars params result
        declarations.modify (· ++ closed.getUsedConstants)
        return (← ppExpr closed).pretty
      return Json.mkObj [("declaration", toJson name.toString),
        ("type", toJson (← ppExpr info.type).pretty),
        ("resultType", toJson resultType),
        ("documentation", toJson (← findDocString? (← getEnv) name))]
    let mut lifts : Array Json := #[]
    for row in state.lifts do
      let mut ports : Array Json := #[]
      if let some declaration := row.computation then
        let info ← getConstInfo declaration
        ports ← forallTelescope info.type fun params _ => do
          let value := mkAppN (mkConst declaration (info.levelParams.map Level.param)) params
          let mut result : Array Json := #[]
          for (field, index) in #[("obj", 0), ("hom", 1), ("forward", 2), ("backward", 3)] do
            let term := mkProj ``MonoLiftComputation index value
            let type ← mkForallFVars params (← inferType term)
            if type.hasFVar || type.hasMVar || type.hasLevelMVar then
              throwError "lift {row.id.raw} field {field} has an open public signature"
            declarations.modify (· ++ type.getUsedConstants)
            result := result.push (Json.mkObj [("operation", toJson s!"{row.id.raw}#{field}"),
              ("input", toJson s!"{row.id.raw}#input"), ("field", toJson field),
              ("type", toJson (← ppExpr type).pretty)])
          return result
      let computation ← match row.computation with
        | some name => describe name
        | none => pure Json.null
      let factor ← if row.kind == .subobjects && row.computation.isSome then do
          let info ← getConstInfo row.evidence
          forallTelescope info.type fun params _ => do
            let evidence := mkAppN (mkConst row.evidence (info.levelParams.map Level.param)) params
            let canonical ← mkAppM ``MonoLift.factorComputation #[evidence]
            let callable := mkProj ``MonoLiftFactorComputation 0 canonical
            let type ← mkForallFVars params (← inferType callable)
            if type.hasFVar || type.hasMVar || type.hasLevelMVar then
              throwError "lift {row.id.raw} factor has an open public signature"
            declarations.modify (· ++ type.getUsedConstants ++ canonical.getUsedConstants)
            return Json.mkObj [("operation", toJson s!"{row.id.raw}#factor"),
              ("input", toJson s!"{row.id.raw}#input"),
              ("declaration", toJson "CasCatalogue.MonoLiftFactorComputation.factor"),
              ("type", toJson (← ppExpr type).pretty),
              ("documentation", toJson (← findDocString? (← getEnv)
                ``MonoLiftFactorComputation)),
              ("computation", ← describe ``MonoLift.factorComputation)]
        else pure Json.null
      let sources := state.categories.filter fun category =>
        (sourceOf? row.edge).any (category.expression.syntacticEq ·)
      lifts := lifts.push (Json.mkObj [("id", toJson row.id.raw),
        ("edge", toJson row.edge.label),
        ("kind", toJson (reprStr row.kind)),
        ("sourceCategories", toJson (sources.map (·.id.raw))),
        ("input", toJson s!"{row.id.raw}#input"),
        ("wire", toJson "api/wire-examples.md#complete-results-projections-and-lifts"),
        ("selection", ← describe row.evidence),
        ("computation", computation),
        ("ports", Json.arr ports), ("factor", factor)])
    let mut entries : Array Json := #[]
    for row in state.entries do
      let names := row.declarations ++ match row with
        | .object object => object.generator.toArray ++ object.application.toArray ++
            object.constants.toArray ++ object.inclusion.toArray ++ object.admission.toArray ++
            (object.refines.toArray.map (·.identification))
        | _ => #[]
      let signatures ← names.mapM describe
      entries := entries.push (Json.mkObj [("id", toJson row.stableId),
        ("registeredMetadata", toJson (reprStr row)),
        ("declarations", Json.arr signatures)])
    let mut categories : Array Json := #[]
    for row in state.categories do
      categories := categories.push (Json.mkObj [("id", toJson row.id.raw),
        ("signature", ← describe row.declaration)])
    let mut objects : Array Json := #[]
    for row in state.objects do
      objects := objects.push (Json.mkObj [("id", toJson row.id.raw),
        ("category", toJson row.category.raw), ("signature", ← describe row.declaration)])
    let mut functors : Array Json := #[]
    for row in state.functors do
      functors := functors.push (Json.mkObj [("id", toJson row.id.raw),
        ("signature", ← describe row.declaration)])
    let mut cells : Array Json := #[]
    for row in state.cells do
      let info ← getConstInfo row.declaration
      let componentType ← forallTelescope info.type fun parameters _ => do
        let value := mkAppN (mkConst row.declaration (info.levelParams.map Level.param)) parameters
        let natural ← if row.invertible then mkAppM ``CategoryTheory.Iso.hom #[value]
          else pure value
        let component ← mkAppM ``CategoryTheory.NatTrans.app #[natural]
        let type ← mkForallFVars parameters (← inferType component)
        if type.hasFVar || type.hasMVar || type.hasLevelMVar then
          throwError "cell {row.id.raw} has an open public component signature"
        declarations.modify (· ++ type.getUsedConstants)
        return (← ppExpr type).pretty
      cells := cells.push (Json.mkObj [("id", toJson row.id.raw),
        ("source", toJson (reprStr row.source)), ("target", toJson (reprStr row.target)),
        ("left", toJson (reprStr row.left)), ("right", toJson (reprStr row.right)),
        ("invertible", toJson row.invertible), ("signature", ← describe row.declaration),
        ("operation", toJson s!"{row.id.raw}#component"),
        ("input", toJson s!"{row.id.raw}#component"),
        ("componentType", toJson componentType),
        ("wire", toJson "api/wire-examples.md#natural-cell-components")])
    let mut constructions : Array Json := #[]
    for row in state.constructions do
      let info ← getConstInfo row.declaration
      let (objectActionType, mapActionType) ← forallTelescope info.type fun params _ => do
        let value := mkAppN (mkConst row.declaration (info.levelParams.map Level.param)) params
        let objectAction ← mkAppM ``Prefunctor.obj #[
          ← mkAppM ``CategoryTheory.Functor.toPrefunctor #[value]]
        let mapAction ← mkAppM ``CategoryTheory.Functor.map #[value]
        let objectType ← mkForallFVars params (← inferType objectAction)
        let mapType ← mkForallFVars params (← inferType mapAction)
        if objectType.hasFVar || objectType.hasMVar || objectType.hasLevelMVar ||
            mapType.hasFVar || mapType.hasMVar || mapType.hasLevelMVar then
          throwError "construction {row.id.raw} has an open public action signature"
        declarations.modify (· ++ objectType.getUsedConstants ++ mapType.getUsedConstants)
        return ((← ppExpr objectType).pretty, (← ppExpr mapType).pretty)
      constructions := constructions.push (Json.mkObj [("id", toJson row.id.raw),
        ("name", toJson row.name), ("target", toJson (reprStr row.target)),
        ("signature", ← describe row.declaration),
        ("input", toJson s!"{row.id.raw}#input"),
        ("objectOperation", toJson row.id.raw),
        ("mapOperation", toJson s!"{row.id.raw}#map"),
        ("objectActionType", toJson objectActionType),
        ("mapActionType", toJson mapActionType),
        ("wire", toJson "api/wire-examples.md#direct-constructions")])
    let mut datatypes : Array Json := #[]
    let mut typeAliases : Array Json := #[]
    let seeds ← declarations.get
    let mut names := seeds
    for name in seeds do
      let info ← getConstInfo name
      names := names ++ info.type.getUsedConstants
    let mut seen : NameSet := {}
    let mut cursor := 0
    while cursor < names.size do
      let name := names[cursor]!
      cursor := cursor + 1
      if seen.contains name then continue
      seen := seen.insert name
      if isPrivateName name then continue
      let constant ← getConstInfo name
      let .inductInfo info := constant | do
        let typeReference ← forallTelescope constant.type fun params result => do
          let .sort level := (← whnf result) | return none
          if level == .zero then return none
          let expression := mkAppN (mkConst name (constant.levelParams.map Level.param)) params
          let normalized ← match constant with
            | .defnInfo _ => whnf expression
            | _ => pure expression
          let exposed := normalized != expression
          let closed ← mkForallFVars params normalized
          if closed.hasFVar || closed.hasMVar || closed.hasLevelMVar then
            throwError "type alias {name} has an open public type expression"
          return some (exposed, closed)
        if let some (exposed, closed) := typeReference then
          names := names ++ closed.getUsedConstants
          let rendered ← ppExpr closed
          typeAliases := typeAliases.push (Json.mkObj [
            ("declaration", toJson name.toString),
            ("type", toJson (← ppExpr constant.type).pretty),
            ("normalizedType", if exposed then toJson rendered.pretty else Json.null),
            ("representation", toJson (if exposed then "exposed-type" else "abstract"))])
        continue
      let mut constructors : Array Json := #[]
      for ctor in info.ctors do
        let ci ← getConstInfo ctor
        names := names ++ ci.type.getUsedConstants
        let fields ← forallTelescope ci.type fun binders _ => do
          let mut fields : Array Json := #[]
          for binder in binders[info.numParams:] do
            let type ← inferType binder
            fields := fields.push (Json.mkObj [
              ("name", toJson (← binder.fvarId!.getDecl).userName.toString),
              ("type", toJson (← ppExpr type).pretty),
              ("proof", toJson (← isProp type))])
          return fields
        constructors := constructors.push (Json.mkObj [
          ("declaration", toJson ctor.toString),
          ("type", toJson (← ppExpr ci.type).pretty), ("fields", Json.arr fields)])
      datatypes := datatypes.push (Json.mkObj [("declaration", toJson name.toString),
        ("type", toJson (← ppExpr info.type).pretty),
        ("constructors", Json.arr constructors)])
    return Json.mkObj [("entries", Json.arr entries), ("categories", Json.arr categories),
      ("datatypes", Json.arr datatypes), ("typeAliases", Json.arr typeAliases), ("lifts", Json.arr lifts), ("objects", Json.arr objects),
      ("functors", Json.arr functors), ("constructions", Json.arr constructions),
      ("cells", Json.arr cells)]
  let output := (← IO.getEnv "CAS_DECLARED_PORTS_OUTPUT").getD "declared-ports.json"
  let required (name : String) : IO String := do
    let some value ← IO.getEnv name | throw (IO.userError s!"missing provenance: {name}")
    if value.isEmpty then throw (IO.userError s!"empty provenance: {name}")
    return value
  let provenance := Json.mkObj [
    ("mathematicsRevision", toJson (← required "CAS_DECLARED_PORTS_MATH_REVISION")),
    ("protocolRevision", toJson (← required "CAS_DECLARED_PORTS_PROTOCOL_REVISION")),
    ("exporterSha256", toJson (← required "CAS_DECLARED_PORTS_EXPORTER_SHA256"))]
  let .ok fields := result.getObj? | throwError "expected metadata object"
  IO.FS.writeFile output (Json.mkObj (("provenance", provenance) :: fields.toList)).pretty
