module
import CasRuntime.ManifestAdmission
import CasTools.NativeExpression
import LeanCategories.Catalogue
meta import CasRuntime.ManifestAdmission
meta import CasTools.NativeExpression
meta import LeanCategories.Catalogue
open Lean Meta Elab Command CasCatalogue CasCompiler CasRuntime






run_cmd do
  let document ← liftTermElabM do
    let state ← semanticState
    let registry : RegistryState := { toSemanticState := state }
    let categoryOf (id : CategoryId) : MetaM CategoryExpr := do
      let #[category] := state.categories.filter (·.id == id)
        | throwError "input form {id.raw} has no unique registered category"
      return category.expression
    let nativeContext (declaration : Name) : MetaM Json := do
      let info ← getConstInfo declaration
      return Json.mkObj [
        ("declaration", toJson declaration.toString),
        ("universeParameters", toJson (info.levelParams.map Name.toString)),
        ("signature", toJson (← ppExpr info.type).pretty),
        ("nativeType", CasTools.NativeExpression.encode #[info.type])]


    let mut requests : Array (String × String × Option CategoryExpr × Option Name) := #[]
    let mut candidates := registry.registryEntries.toArray.filterMap fun row =>
      if (registry.operation? row.stableId).isSome then some row.stableId else none
    for row in state.operations do
      requests := requests.push (row.id.raw, row.id.raw ++ "#input",
        some (← categoryOf row.category), some row.declaration)
    for row in state.methods do
      requests := requests.push (row.id.raw, row.id.raw ++ "#input", some row.owner,
        some (← (ComputationRef.method row.id).declaration state))
    for row in state.morphisms do
      requests := requests.push (row.id.raw, row.id.raw,
        some (← categoryOf row.category), some row.declaration)
    for row in state.binders do
      requests := requests.push (row.id.raw, row.id.raw,
        some (← categoryOf row.category), some row.operation)
    for row in state.limits do
      requests := requests.push (row.id.raw, row.category.raw,
        some (← categoryOf row.category), some row.declaration)
      let universal ← LimitUniversalFamily.forId row.id
      for port in ← PublishedPorts.forLimitUniversal row.id do
        requests := requests.push (port.operation, universal.input,
          some (← categoryOf row.category), some row.declaration)
    for row in state.presentations do
      requests := requests.push (row.id.raw, row.id.raw, none, some row.declaration)
    for row in state.objects do
      if let some declaration := row.application then
        requests := requests.push (row.applicationAddress, row.applicationAddress,
          some (← categoryOf row.category), some declaration)
    for row in state.functors do
      for address in #[row.id.raw, row.id.raw ++ "#map"] do
        requests := requests.push (address, row.id.raw ++ "#input", some row.source,
          some row.declaration)
      if let .familyReindex _ := row.expression.registrationKind then
        requests := requests.push (row.id.raw ++ "#cartesian", row.id.raw ++ "#cartesian",
          some row.source, some ``CategoryTheory.Pseudofunctor.CoGrothendieck.cartesianLift)
    for row in state.constructions do
      for address in #[row.id.raw, row.id.raw ++ "#map"] do
        requests := requests.push (address, row.id.raw ++ "#input", none, some row.declaration)
    for row in state.cells do
      requests := requests.push (row.id.raw ++ "#component", row.id.raw ++ "#component",
        some row.source, some row.declaration)
    for row in state.lifts do
      if let .createsLimits _ := row.kind then
        for port in ← PublishedPorts.forCreation row.id do
          requests := requests.push (port.operation, row.id.raw ++ "#input", none,
            some row.evidence)
      if row.computation.isNone then continue
      let ports := if row.kind == .subobjects then #[LiftPort.computation, .factor]
        else #[LiftPort.computation]
      for port in ports do
        let family ← LiftFamily.forLift row port
        for projection in ← family.projections do
          requests := requests.push (row.id.raw ++ "#" ++ projection.getString!,
            row.id.raw ++ "#input", none,
            some (if port == .computation then row.computation.get! else row.evidence))
    let mut edgeActions := #[]
    for edge in registry.imageEdges do
      if let .functor _ := edge.ref then continue
      let identity := edgeImageDescriptor edge.ref
      let address := "action:" ++ identity.compress
      let input := address ++ "#input"
      for operation in #[address, address ++ "#map"] do
        requests := requests.push (operation, input, some edge.source, none)
      edgeActions := edgeActions.push (Json.mkObj [
        ("identity", identity), ("objectOperation", toJson address),
        ("mapOperation", toJson (address ++ "#map")), ("input", toJson input),
        ("source", toJson (reprStr edge.source)), ("target", toJson (reprStr edge.target)),
        ("wire", toJson "api/wire-examples.md#derived-structural-actions")])


    for reference in PublishedPorts.references state do
      let declaration ← reference.declaration state
      for port in ← PublishedPorts.forReference reference do
        requests := requests.push (port.operation, PublishedPorts.inputAddress reference,
          none, some declaration)
    candidates := candidates ++ requests.map (·.1)
    let mut seen : Std.HashSet String := {}
    let mut operations := #[]
    let mut missingAdmissions := #[]
    for address in candidates do
      if seen.contains address then continue
      seen := seen.insert address
      let admitted ← publishedOperation state address
      if admitted then
        operations := operations.push (Json.mkObj [("operation", toJson address)])
      else
        missingAdmissions := missingAdmissions.push (Json.mkObj [
          ("operation", toJson address),
          ("reason", "the released declaration has no current kernel admission")])
    let mut formCandidates := registry.registryEntries.toArray.map (·.stableId)
    formCandidates := formCandidates ++ state.objects.filterMap fun row =>
      if row.application.isSome then some row.applicationAddress else none
    for edge in registry.imageEdges do
      for category in state.categories do
        let targetMatches := category.expression.syntacticEq edge.target ||
          match category.expression, edge.target with
          | .familyApp left _, .familyApp right _ => left == right
          | _, _ => false
        if targetMatches then formCandidates := formCandidates.push (edgeImageId edge.ref category.id)
    let requestContexts (input : String) : MetaM (Array String × Array Json) := do
      let mut categories : Array String := #[]
      let mut declarations : Array Name := #[]
      for (_, other, category, declaration) in requests do
        unless other == input do continue
        if let some category := category then
          let category := reprStr category
          unless categories.contains category do categories := categories.push category
        if let some declaration := declaration then
          unless declarations.contains declaration do declarations := declarations.push declaration
      return (categories, ← declarations.mapM nativeContext)
    let mut seenForms : Std.HashSet String := {}
    let mut forms := #[]
    for address in formCandidates do
      if seenForms.contains address then continue
      if let some form := registry.form? address then
        let expression ← categoryOf form.category
        seenForms := seenForms.insert address
        let (categories, contexts) ← requestContexts address
        forms := forms.push (Json.mkObj [
          ("input", toJson address), ("category", toJson form.category.raw),
          ("categoryExpression", toJson (reprStr expression)),
          ("categoryExpressions", toJson categories),
          ("nativeContext", if contexts.size == 1 then contexts[0]! else Json.null),
          ("nativeContexts", Json.arr contexts)])
    for (_, input, _, _) in requests do
      if seenForms.contains input then continue
      seenForms := seenForms.insert input
      let (categories, contexts) ← requestContexts input
      unless !categories.isEmpty || !contexts.isEmpty do
        throwError "complete request {input} lost its original dependent input context"
      forms := forms.push (Json.mkObj [
        ("input", toJson input), ("category", Json.null),
        ("categoryExpression", if categories.size == 1 then toJson categories[0]! else Json.null),
        ("categoryExpressions", toJson categories),
        ("nativeContext", if contexts.size == 1 then contexts[0]! else Json.null),
        ("nativeContexts", Json.arr contexts)])
    return Json.mkObj [("inputForms", Json.arr forms),
      ("operations", Json.arr operations), ("edgeActions", Json.arr edgeActions),
      ("missingAdmissions", Json.arr missingAdmissions)]
  let some output ← IO.getEnv "CAS_ADMISSION_ADDRESSES_OUTPUT"
    | throwError "missing CAS_ADMISSION_ADDRESSES_OUTPUT"
  IO.FS.writeFile output document.pretty
