module
import CasCompiler.CreationFamily
meta import CasCompiler.CreationFamily
import LeanCategories.Catalogue
meta import LeanCategories.Catalogue
import LeanCategories.Catalogue.Registry.Computation
meta import LeanCategories.Catalogue.Registry.Computation
open Lean Meta Elab Command CasCatalogue CasCompiler
set_option pp.explicit true
set_option pp.universes true
set_option pp.fullNames true
/-- Native record fields retain proof positions and complete types. Computational
addresses follow the released record-field rule within the supplied exact owner. -/
private partial def nativeRecordDocuments (declarations : IO.Ref (Array Name))
    (owner input : String) (parameters : Array Expr) (value : Expr)
    (path : Array Name) (publishFields : Bool := true) : TermElabM (Array Json) := do
  let type ← whnf (← inferType value)
  let .const ownerType _ := type.getAppFn | return #[]
  let some information := getStructureInfo? (← getEnv) ownerType | return #[]
  let mut fields := #[]
  let mut wireIndex := 0
  for label in information.fieldNames, index in [:information.fieldNames.size] do
    let some projection := information.getProjFn? index
      | throwError "the universal record lost its original native field"
    let field ← mkProjection value label
    let proof ← isProof field
    let fieldType ← mkForallFVars parameters (← inferType field)
      (usedOnly := false) (usedLetOnly := false)
    if fieldType.hasFVar || fieldType.hasMVar || fieldType.hasLevelMVar then
      throwError "a native universal field has an open public signature"
    declarations.modify (· ++ fieldType.getUsedConstants)
    let selected := path.push projection
    let common := [
      ("projection", toJson projection.toString),
      ("sourceIndex", toJson index),
      ("path", toJson (selected.map Name.toString)),
      ("type", toJson (← ppExpr fieldType).pretty),
      ("proof", toJson proof)]
    if proof then
      fields := fields.push (Json.mkObj common)
    else
      let operation := if wireIndex == 0 then owner else owner ++ "#" ++ projection.getString!
      let nested ← nativeRecordDocuments declarations owner input parameters field selected publishFields
      let address := if publishFields then
        [("operation", toJson operation), ("input", toJson input)] else []
      fields := fields.push (Json.mkObj (common ++ address ++ [
        ("wireIndex", toJson wireIndex), ("fields", Json.arr nested)]))
      wireIndex := wireIndex + 1
  return fields

run_cmd do
  let result : Json ← liftTermElabM do
    let state ← semanticState
    let rowKind : SemanticEntry → String
      | .category _ => "category" | .categoryFamily _ => "categoryFamily"
      | .classifier _ => "classifier" | .functor _ => "functor"
      | .opaque _ => "opaque" | .fibration _ => "fibration"
      | .constructor _ => "constructor" | .presentation _ => "presentation"
      | .construction _ => "construction" | .method _ => "method"
      | .property _ => "property" | .lift _ => "lift" | .cell _ => "cell"
      | .limit _ => "limit" | .adjunction _ => "adjunction" | .object _ => "object"
      | .literal _ => "literal" | .numeral _ => "numeral" | .graphLiteral _ => "graphLiteral"
      | .morphism _ => "morphism" | .operation _ => "operation" | .inclusion _ => "inclusion"
      | .powerObject _ => "powerObject" | .subsetLiteral _ => "subsetLiteral"
      | .binder _ => "binder"


    let rec sourceOf? : EdgeRef → Option CategoryExpr
      | .functor id => (state.functor? id).map (·.source)
      | .classifierForget id => (state.structuralEdge? (.classifierForget id)).map (·.source)
      | .constructMap id inner => do
          let constructor ← state.constructor? id
          guard constructor.functorialAction.isSome
          return .construct id #[.category (← sourceOf? inner)]
    let declarations ← IO.mkRef (#[] : Array Name)
    let categoryOf (id : CategoryId) : TermElabM CategoryExpr := do
      let #[row] := state.categories.filter (·.id == id)
        | throwError "category interface has no unique category {id.raw}"
      return row.expression
    let objectCategory (id : ObjectId) : TermElabM CategoryExpr := do
      let #[row] := state.objects.filter (·.id == id)
        | throwError "category interface has no unique object {id.raw}"
      categoryOf row.category
    let functorCategories (id : FunctorId) : TermElabM (Array (CategoryExpr × String)) := do
      let #[row] := state.functors.filter (·.id == id)
        | throwError "category interface has no unique functor {id.raw}"
      return #[(row.source, "source"), (row.target, "target")]


    let rowOwners : SemanticEntry → TermElabM (Array (CategoryExpr × String))
      | .category row => pure #[(row.expression, "category")]
      | .opaque row => pure #[(.opaque row.id, "category")]
      | .categoryFamily row => pure #[(.familyTotal row.id, "total")]
      | .classifier row => pure #[(row.host, "host"), (.classifierTotal row.id, "total")]
      | .functor row => pure #[(row.source, "source"), (row.target, "target")]
      | .fibration row => functorCategories row.projection
      | .constructor _ => pure #[]
      | .presentation row => do
          return #[(← objectCategory row.source, "source"),
            (← objectCategory row.target, "target")]
      | .construction row => pure #[(row.target, "target")]
      | .method row => pure #[(row.owner, "owner")]
      | .property row => do
          if let some receiver := row.receiver then return #[(receiver, "receiver")]
          let #[classifier] := state.classifiers.filter (·.id == row.classifier)
            | throwError "property {row.id.raw} has no unique classifier"
          return #[(classifier.host, "receiver")]
      | .lift row => pure <| (sourceOf? row.edge).toArray.map (·, "source")
      | .cell row => pure #[(row.source, "source"), (row.target, "target")]
      | .limit row => do return #[(← categoryOf row.category, "owner")]
      | .adjunction row => functorCategories row.left
      | .object row => do return #[(← categoryOf row.category, "owner")]
      | .literal row => do return #[(← categoryOf row.category, "owner")]
      | .numeral row => do
          match row.over with
          | some id => return #[(← categoryOf id, "owner")]
          | none => return #[]
      | .graphLiteral row => do return #[(← categoryOf row.category, "owner")]
      | .morphism row => do return #[(← categoryOf row.category, "owner")]
      | .operation row => do return #[(← categoryOf row.category, "owner")]
      | .inclusion row => do return #[(← categoryOf row.category, "owner")]
      | .powerObject row => do
          return #[(← objectCategory row.object, "owner"),
            (← objectCategory row.omega, "truthValues")]
      | .subsetLiteral row => do
          let #[power] := state.powerObjects.filter (·.id == row.powerObject)
            | throwError "subset literal {row.id.raw} has no unique power object"
          return #[(← objectCategory power.object, "owner")]
      | .binder row => do return #[(← categoryOf row.category, "owner")]
    let describe (name : Name) : TermElabM Json := do
      declarations.modify (·.push name)
      let info ← getConstInfo name
      let (parameters, resultType) ← forallTelescope info.type fun params result => do
        let parameters ← params.mapIdxM fun index parameter => do
          let binder ← parameter.fvarId!.getDecl
          return Json.mkObj [("index", toJson index),
            ("name", toJson binder.userName.toString),
            ("type", toJson (← ppExpr binder.type).pretty),
            ("binder", toJson (reprStr binder.binderInfo)),
            ("explicit", toJson binder.binderInfo.isExplicit),
            ("proof", toJson (← isProp binder.type))]
        let result ← whnf result
        let closed ← mkForallFVars params result
        declarations.modify (· ++ closed.getUsedConstants)
        return (parameters, (← ppExpr closed).pretty)
      return Json.mkObj [("declaration", toJson name.toString),
        ("type", toJson (← ppExpr info.type).pretty),
        ("universeParameters", toJson (info.levelParams.map Name.toString)),
        ("parameters", Json.arr parameters),
        ("resultType", toJson resultType),
        ("documentation", toJson (← findDocString? (← getEnv) name))]
    let actionTypes (id : String) (declaration : Name) : TermElabM (String × String) := do
      let info ← getConstInfo declaration
      forallTelescope info.type fun params _ => do
        let value := mkAppN (mkConst declaration (info.levelParams.map Level.param)) params
        let type ← whnf (← inferType value)
        let value ← if type.isAppOfArity ``CategoryTheory.Cat.Hom 2 then
            mkAppM ``CategoryTheory.Cat.Hom.toFunctor #[value]
          else pure value
        let objectAction ← mkAppM ``Prefunctor.obj #[
          ← mkAppM ``CategoryTheory.Functor.toPrefunctor #[value]]
        let mapAction ← mkAppM ``CategoryTheory.Functor.map #[value]
        let objectType ← mkForallFVars params (← inferType objectAction)
        let mapType ← mkForallFVars params (← inferType mapAction)
        if objectType.hasFVar || objectType.hasMVar || objectType.hasLevelMVar ||
            mapType.hasFVar || mapType.hasMVar || mapType.hasLevelMVar then
          throwError "functor {id} has an open public action signature"
        declarations.modify (· ++ objectType.getUsedConstants ++ mapType.getUsedConstants)
        return ((← ppExpr objectType).pretty, (← ppExpr mapType).pretty)
    let mut limits : Array Json := #[]
    for row in state.limits do
      let information ← getConstInfo row.declaration
      let declaration := mkConst row.declaration (information.levelParams.map Level.param)
      let coneProjection := if row.colimit then
        ``CategoryTheory.Limits.ColimitCocone.cocone else ``CategoryTheory.Limits.LimitCone.cone
      let universalProjection := if row.colimit then
        ``CategoryTheory.Limits.ColimitCocone.isColimit else ``CategoryTheory.Limits.LimitCone.isLimit
      let universal ← forallTelescope information.type fun parameters _ => do
        let presentation := mkAppN declaration parameters
        let native ← mkAppM universalProjection #[presentation]
        unless !(← isProof native) do
          throwError "the accepted universal property lost its data interface"
        let nativeType ← mkForallFVars parameters (← inferType native)
          (usedOnly := false) (usedLetOnly := false)
        if nativeType.hasFVar || nativeType.hasMVar || nativeType.hasLevelMVar then
          throwError "the universal family has an open public signature"
        declarations.modify (· ++ nativeType.getUsedConstants)
        let parentType ← whnf (← inferType presentation)
        let some parent := getStructureInfo? (← getEnv) parentType.getAppFn.constName!
          | throwError "the accepted presentation lost its original native record"
        let mut preceding := #[]
        let mut found := false
        for label in parent.fieldNames, index in [:parent.fieldNames.size] do
          let some projection := parent.getProjFn? index
            | throwError "the accepted presentation lost an original native field"
          if projection == universalProjection then
            found := true
            break
          let field ← mkProjection presentation label
          let type ← mkForallFVars parameters (← inferType field)
            (usedOnly := false) (usedLetOnly := false)
          declarations.modify (· ++ type.getUsedConstants)
          preceding := preceding.push (Json.mkObj [
            ("projection", toJson projection.toString), ("sourceIndex", toJson index),
            ("path", toJson #[projection.toString]),
            ("type", toJson (← ppExpr type).pretty), ("proof", toJson (← isProof field))])
        unless found do throwError "the universal data lost its original presentation position"
        let operation := row.id.raw ++ "#" ++ universalProjection.getString!
        let input := operation ++ "#input"
        return Json.mkObj [
          ("operation", toJson operation), ("input", toJson input),
          ("projection", toJson universalProjection.toString),
          ("path", toJson #[universalProjection.toString]),
          ("type", toJson (← ppExpr nativeType).pretty),
          ("universeParameters", toJson (information.levelParams.map Name.toString)),
          ("parameterCount", toJson parameters.size),
          ("precedingFields", Json.arr preceding),
          ("fields", Json.arr (← nativeRecordDocuments declarations operation input parameters
            native #[universalProjection]))]
      limits := limits.push (Json.mkObj [
        ("id", toJson row.id.raw), ("category", toJson row.category.raw),
        ("operation", toJson row.id.raw), ("input", toJson row.category.raw),
        ("signature", ← describe row.declaration),
        ("coneProjection", toJson coneProjection.toString),
        ("dataConstructor", ← match row.dataConstructor with
          | some name => describe name | none => pure Json.null),
        ("standardization", ← match row.standardization with
          | some name => describe name | none => pure Json.null),
        ("universal", universal),
        ("wire", toJson "api/wire-examples.md#native-universal-data")])
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
      let creation ← match row.kind with
        | .createsLimits _ => do
          let family ← CreationFamily.forLift row
          let template ← family.standardizedTemplate
          let templateType ← inferType template
          declarations.modify (· ++ templateType.getUsedConstants)
          forallTelescopeReducing templateType fun parameters _ => do
            unless parameters.size ≥ 2 do
              throwError "the standardized creation family lost its actual cone and universal inputs"
            let parameterDocuments ← parameters.mapIdxM fun index parameter => do
              let binder ← parameter.fvarId!.getDecl
              return Json.mkObj [
                ("index", toJson index), ("name", toJson binder.userName.toString),
                ("type", toJson (← ppExpr binder.type).pretty),
                ("binder", toJson (reprStr binder.binderInfo)),
                ("explicit", toJson binder.binderInfo.isExplicit),
                ("proof", toJson (← isProp binder.type))]
            return Json.mkObj [
              ("operation", toJson row.id.raw), ("input", toJson (row.id.raw ++ "#input")),
              ("source", ← describe ``CategoryTheory.liftsToLimitOfCreates),
              ("family", toJson (← ppExpr template).pretty),
              ("familyType", toJson (← ppExpr templateType).pretty),
              ("universeParameters", toJson (family.universeParams.map Name.toString)),
              ("selectedContext", Json.arr (parameterDocuments.extract 0 (parameters.size - 2))),
              ("inputs", Json.arr (parameterDocuments.extract (parameters.size - 2) parameters.size)),
              ("fields", Json.arr (← nativeRecordDocuments declarations row.id.raw
                (row.id.raw ++ "#input") parameters (mkAppN template parameters) #[] false))]
        | _ => pure Json.null
      lifts := lifts.push (Json.mkObj [("id", toJson row.id.raw),
        ("edge", toJson row.edge.label),
        ("kind", toJson (reprStr row.kind)),
        ("sourceCategories", toJson (sources.map (·.id.raw))),
        ("input", toJson s!"{row.id.raw}#input"),
        ("wire", toJson "api/wire-examples.md#complete-results-projections-and-lifts"),
        ("selection", ← describe row.evidence),
        ("computation", computation),
        ("ports", Json.arr ports), ("factor", factor), ("creation", creation)])
    let mut entries : Array Json := #[]
    let mut memberships : Array (Array (CategoryExpr × String)) := #[]
    for row in state.entries do
      let additional ← match row with
        | .object object => pure <| object.generator.toArray ++ object.application.toArray ++
            object.constants.toArray ++ object.inclusion.toArray ++ object.admission.toArray ++
            (object.refines.toArray.map (·.identification)) ++
            (object.functorPresentation.toArray.flatMap fun presentation =>
              #[presentation.argument, presentation.identification])
        | .method method => do
          pure #[← (ComputationRef.method method.id).declaration state]
        | .property property => do
          let #[classifier] := state.classifiers.filter (·.id == property.classifier)
            | throwError "property {property.id.raw} has no unique native classifier"
          pure #[classifier.declaration, classifier.realization]
        | _ => pure #[]
      let names := row.declarations ++ additional
      let signatures ← names.mapM describe
      let owners ← rowOwners row
      memberships := memberships.push owners
      let surfaceName := match row with
        | .category e => some e.name | .object e => some e.name
        | .morphism e => some e.name | .operation e => some e.name
        | .method e => some e.name | .property e => some e.name
        | .construction e => some e.name | .presentation e => some e.name
        | .binder e => some e.token | _ => none
      entries := entries.push (Json.mkObj [("id", toJson row.stableId),
        ("kind", toJson (rowKind row)),
        ("name", toJson surfaceName),
        ("owners", Json.arr (owners.map fun (category, role) =>
          Json.mkObj [("category", toJson (reprStr category)), ("role", toJson role)])),
        ("registeredMetadata", toJson (reprStr row)),
        ("declarations", Json.arr signatures)])
    let mut categories : Array Json := #[]
    for row in state.categories do
      categories := categories.push (Json.mkObj [("id", toJson row.id.raw),
        ("expression", toJson (reprStr row.expression)),
        ("signature", ← describe row.declaration), ("realization", ← describe row.realization)])
    let mut categoryFamilies : Array Json := #[]
    for row in state.categoryFamilies do
      let parameters := row.schema.parameterMetadata.map fun parameter =>
        Json.mkObj [("name", toJson parameter.name), ("kind", toJson parameter.kind.raw),
          ("identifiers", toJson (parameter.ids.map (·.raw))),
          ("dependency", toJson parameter.dependency)]
      categoryFamilies := categoryFamilies.push (Json.mkObj [("id", toJson row.id.raw),
        ("schema", toJson (reprStr row.schema)), ("parameters", Json.arr parameters),
        ("realization", ← describe row.realization), ("transport", ← describe row.transport),
        ("transportSemantics", toJson (reprStr row.transportSemantics)),
        ("wire", toJson "api/wire-examples.md#family-reindexing-and-cartesian-arrows")])
    let mut objects : Array Json := #[]
    for row in state.objects do
      let presentation ← match row.functorPresentation with
        | none => pure Json.null
        | some presentation => do
          let info ← getConstInfo presentation.identification
          let fields ← forallTelescope info.type fun parameters _ => do
            let comparison := mkAppN
              (mkConst presentation.identification (info.levelParams.map Level.param)) parameters
            let mut fields := #[]
            for (field, projection) in #[("presentation", ``CategoryTheory.Iso.hom),
                ("inversePresentation", ``CategoryTheory.Iso.inv)] do
              let arrow ← mkAppM projection #[comparison]
              let type ← mkForallFVars parameters (← inferType arrow)
              if type.hasFVar || type.hasMVar || type.hasLevelMVar then
                throwError "object {row.id.raw} field {field} has an open public signature"
              declarations.modify (· ++ type.getUsedConstants)
              fields := fields.push (Json.mkObj [("field", toJson field),
                ("type", toJson (← ppExpr type).pretty)])
            return fields
          pure (Json.mkObj [("functor", toJson presentation.functor.raw),
            ("route", toJson (presentation.route.map reprStr)),
            ("argument", ← describe presentation.argument),
            ("identification", ← describe presentation.identification),
            ("fields", Json.arr fields),
            ("wire", toJson "api/wire-examples.md#registered-object-fields")])
      objects := objects.push (Json.mkObj [("id", toJson row.id.raw),
        ("category", toJson row.category.raw), ("signature", ← describe row.declaration),
        ("application", ← match row.application with
          | some declaration => pure <| Json.mkObj [
              ("operation", toJson s!"{row.id.raw}#application"),
              ("signature", ← describe declaration)]
          | none => pure Json.null),
        ("fields", toJson <|
          (if row.inclusion.isSome then #["inclusion"] else #[]) ++
          (if row.constants.isSome then #["constants"] else #[]) ++
          (if row.refines.isSome then #["refinement", "inverseRefinement"] else #[]) ++
          (if row.functorPresentation.isSome then
            #["presentation", "inversePresentation"] else #[])),
        ("functorPresentation", presentation)])
    let mut functors : Array Json := #[]
    for row in state.functors do
      let (objectActionType, mapActionType) ← actionTypes row.id.raw row.declaration
      let cartesian ← match row.expression.registrationKind with
        | .familyReindex family =>
          pure (Json.mkObj [("family", toJson family.raw),
            ("operation", toJson s!"{row.id.raw}#cartesian"),
            ("input", toJson s!"{row.id.raw}#cartesian"),
            ("action", ← describe ``CategoryTheory.Pseudofunctor.CoGrothendieck.cartesianLift),
            ("wire", toJson "api/wire-examples.md#family-reindexing-and-cartesian-arrows")])
        | _ => pure Json.null
      functors := functors.push (Json.mkObj [("id", toJson row.id.raw),
        ("source", toJson (reprStr row.source)), ("target", toJson (reprStr row.target)),
        ("expression", toJson (reprStr row.expression)),
        ("signature", ← describe row.declaration), ("cartesian", cartesian),
        ("input", toJson s!"{row.id.raw}#input"),
        ("objectOperation", toJson row.id.raw),
        ("mapOperation", toJson s!"{row.id.raw}#map"),
        ("objectActionType", toJson objectActionType),
        ("mapActionType", toJson mapActionType),
        ("wire", toJson "api/wire-examples.md#registered-functor-actions")])
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
    let mut cellConstructors : Array Json := #[]
    let mut categoryConstructors : Array Json := #[]
    for row in state.constructors do
      categoryConstructors := categoryConstructors.push (Json.mkObj [
        ("id", toJson row.id.raw),
        ("signature", toJson (row.signature.map fun kind => match kind with
          | .category => "category" | .object => "object" | .functor => "functor")),
        ("semantics", ← describe row.semantics),
        ("functorialAction", ← match row.functorialAction with
          | some declaration => describe declaration | none => pure Json.null),
        ("wire", toJson "api/wire-examples.md#direct-constructions")])
      if let some action := row.comparisonAction then
        cellConstructors := cellConstructors.push (Json.mkObj [
          ("id", toJson row.id.raw), ("comparisonAction", ← describe action),
          ("semantics", ← describe row.semantics),
          ("functorialAction", ← match row.functorialAction with
            | some declaration => describe declaration | none => pure Json.null),
          ("identityComparison", ← match row.identityComparison with
            | some declaration => describe declaration | none => pure Json.null),
          ("compositionComparison", ← match row.compositionComparison with
            | some declaration => describe declaration | none => pure Json.null),
          ("wire", toJson "api/wire-examples.md#constructor-induced-components")])
    for row in state.constructions do
      let (objectActionType, mapActionType) ← actionTypes row.id.raw row.declaration
      constructions := constructions.push (Json.mkObj [("id", toJson row.id.raw),
        ("name", toJson row.name), ("target", toJson (reprStr row.target)),
        ("signature", ← describe row.declaration),
        ("input", toJson s!"{row.id.raw}#input"),
        ("objectOperation", toJson row.id.raw),
        ("mapOperation", toJson s!"{row.id.raw}#map"),
        ("objectActionType", toJson objectActionType),
        ("mapActionType", toJson mapActionType),
        ("wire", toJson "api/wire-examples.md#direct-constructions")])
    let describeComputationReference (reference : ComputationRef)
        (family familyType : Expr) : TermElabM Json := do
      let (kind, id) := match reference with
        | .operation id => ("operation", id.raw)
        | .functor id => ("functor", id.raw)
        | .method id => ("method", id.raw)
        | .construction id => ("construction", id.raw)
        | .morphism id => ("morphism", id.raw)
      let declaration ← reference.declaration state
      return Json.mkObj [("kind", toJson kind), ("id", toJson id),
        ("declaration", toJson declaration.toString), ("signature", ← describe declaration),
        ("family", toJson (← ppExpr family).pretty),
        ("familyType", toJson (← ppExpr familyType).pretty)]
    let mut derivations : Array Json := #[]
    for row in ← computationDerivations do
      let checked ← validateComputationDerivation state row
      derivations := derivations.push (Json.mkObj [("id", toJson row.id.raw),
        ("target", ← describeComputationReference row.target checked.target checked.familyType),
        ("prerequisites", Json.arr (← checked.prerequisites.mapM fun prerequisite =>
          describeComputationReference prerequisite.reference prerequisite.family
            prerequisite.familyType)),
        ("universeParameters", toJson (checked.universeParams.map Name.toString)),
        ("targetType", toJson (← ppExpr checked.familyType).pretty),
        ("plan", ← describe row.plan), ("correctness", ← describe row.correctness),
        ("planApplication", toJson (← ppExpr checked.plan).pretty),
        ("correctnessType", toJson (← ppExpr (← inferType checked.correctness)).pretty)])
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
    let mut categoryExpressions : Array CategoryExpr := #[]
    for owners in memberships do
      for (expression, _) in owners do
        unless categoryExpressions.any (·.syntacticEq expression) do
          categoryExpressions := categoryExpressions.push expression
    let mut categoryInterfaces : Array Json := #[]
    for expression in categoryExpressions do
      let selected := (entries.zip memberships).filterMap fun (entry, owners) =>
        if owners.any (fun (owner, _) => owner.syntacticEq expression) then some entry else none
      let rows (kind : String) (metadata : Array Json) : Array Json :=
        metadata.filter fun detail => selected.any fun entry =>
          entry.getObjValAs? String "kind" == .ok kind &&
          entry.getObjValAs? String "id" == detail.getObjValAs? String "id"
      categoryInterfaces := categoryInterfaces.push (Json.mkObj [
        ("expression", toJson (reprStr expression)),
        ("categories", Json.arr (rows "category" categories)),
        ("entries", Json.arr selected),
        ("objects", Json.arr (rows "object" objects)),
        ("functors", Json.arr (rows "functor" functors)),
        ("constructions", Json.arr (rows "construction" constructions)),
        ("cells", Json.arr (rows "cell" cells)),
        ("lifts", Json.arr (rows "lift" lifts)),
        ("limits", Json.arr (rows "limit" limits)),
        ("categoryFamilies", Json.arr (rows "categoryFamily" categoryFamilies))])
    let genericEntries := (entries.zip memberships).filterMap fun (entry, owners) =>
      if owners.isEmpty then some entry else none
    return Json.mkObj [("entries", Json.arr entries), ("categories", Json.arr categories),
      ("categoryInterfaceVersion", toJson (1 : Nat)),
      ("categoryInterfaces", Json.arr categoryInterfaces),
      ("genericEntries", Json.arr genericEntries),
      ("datatypes", Json.arr datatypes), ("typeAliases", Json.arr typeAliases),
      ("lifts", Json.arr lifts), ("limits", Json.arr limits), ("objects", Json.arr objects),
      ("functors", Json.arr functors), ("constructions", Json.arr constructions),
      ("cells", Json.arr cells), ("cellConstructors", Json.arr cellConstructors),
      ("categoryConstructors", Json.arr categoryConstructors),
      ("categoryFamilies", Json.arr categoryFamilies),
      ("computationDerivations", Json.arr derivations)]
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
