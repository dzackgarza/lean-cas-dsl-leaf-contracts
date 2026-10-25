module
import CasCatalogue.Admission
import LeanCategories.Catalogue
meta import CasCatalogue.Admission
meta import LeanCategories.Catalogue
open Lean Elab Command CasCatalogue

/- Read-only adapter for addresses derived by the kernel's published admission API.
Run in the kernel environment; the contract package does not depend on the kernel. -/
run_cmd do
  let state ← liftTermElabM do registryState
  let mut candidates := state.registryEntries.toArray.map (·.stableId)
  candidates := candidates ++ state.objects.map (·.applicationAddress)
  candidates := candidates ++ state.cells.map (·.componentAddress)
  candidates := candidates ++ state.functors.map (·.cartesianAddress)
  for row in state.functors do
    candidates := candidates.push row.inputAddress
    candidates := candidates.push row.mapAddress
  let actionEdges := (state.classifiers.map fun row => EdgeRef.classifierForget row.id) ++
    state.imageEdges.map (·.ref)
  for edge in actionEdges do
    if let .functor _ := edge then continue
    candidates := candidates.push (edgeActionAddress edge)
    candidates := candidates.push (edgeActionMapAddress edge)
    candidates := candidates.push (edgeActionInputAddress edge)
  for row in state.constructions do
    candidates := candidates.push row.inputAddress
    candidates := candidates.push row.mapAddress
  for row in state.lifts do
    candidates := candidates.push row.inputAddress
    candidates := candidates ++ LiftField.all.map row.fieldAddress
    candidates := candidates.push row.factorAddress
  for edge in state.imageEdges do
    for category in state.categories do
      let targetMatches :=  category.expression.syntacticEq edge.target ||
        match category.expression, edge.target with
        | .familyApp left _, .familyApp right _ => left == right
        | _, _ => false
      if targetMatches then candidates := candidates.push (edgeImageId edge.ref category.id)
  let mut seen : Std.HashSet String := {}
  let mut forms : Array Json := #[]
  let mut operations : Array Json := #[]
  let mut edgeActions : Array Json := #[]
  for address in candidates do
    if seen.contains address then continue
    seen := seen.insert address
    if let some form := state.form? address then
      forms := forms.push (Json.mkObj [("input", toJson address),
        ("category", toJson (form.namedCategory?.map (·.raw))),
        ("categoryExpression", toJson ((state.formExpression? form).map reprStr))])
    if let some operation := state.operation? address then
      operations := operations.push (Json.mkObj [("operation", toJson operation.id)])
      if let .edgeAction edge false := operation then
        edgeActions := edgeActions.push (Json.mkObj [
          ("identity", edgeImageDescriptor edge),
          ("objectOperation", toJson (edgeActionAddress edge)),
          ("mapOperation", toJson (edgeActionMapAddress edge)),
          ("input", toJson (edgeActionInputAddress edge)),
          ("source", toJson ((state.selectedEdgeSource? edge).map reprStr)),
          ("target", toJson ((state.selectedEdgeTarget? edge).map reprStr)),
          ("wire", toJson "api/wire-examples.md#derived-structural-actions")])
  let some output ← IO.getEnv "CAS_ADMISSION_ADDRESSES_OUTPUT"
    | throwError "missing CAS_ADMISSION_ADDRESSES_OUTPUT"
  IO.FS.writeFile output (Json.mkObj [("inputForms", Json.arr forms),
    ("operations", Json.arr operations), ("edgeActions", Json.arr edgeActions)]).pretty
