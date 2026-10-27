"""Reference implementation, in Python, of the backend port protocol that `CasCatalogue/Port.lean`
specifies: frames are the ASCII decimal byte length of the payload, a newline, then that many bytes
of UTF-8 JSON; stdout carries only frames, stderr is the program's log stream. The core owns the
protocol, not backend programs: a leaf's program may use this module or speak the protocol in any
language."""

import json
import sys


def object_field(args):
    """Read (object id, map field, ordered declaration parameters).

    presentation and inversePresentation select the accepted functorPresentation
    identification's hom and inv. The formal caller fixes the field and complete
    endpoints; this helper establishes framing only, not an identity or map law.
    """
    if not isinstance(args, dict) or args.get("ctor") != "objectField":
        raise ValueError("an object field requires the objectField envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 3:
        raise ValueError("an object field requires its object id, field and ordered parameters")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("an object field has no registered object id")
    if fields[1] not in ("inclusion", "constants", "presentation", "inversePresentation"):
        raise ValueError("an object field requires a published map field selector")
    if not isinstance(fields[2], list):
        raise ValueError("object field parameters must be ordered data")
    return tuple(fields)


def point_invocation(args, operation=None):
    """Read common invocation framing; endpoint meaning belongs to the formal caller.

    Return (id, parameters, arrow, domain, source, target, argument). No mathematical
    correctness, backend class membership, or law is established here.
    """
    if not isinstance(args, dict) or args.get("ctor") != "apply":
        raise ValueError("a point invocation requires the apply envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 7:
        raise ValueError("a point invocation requires all seven ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a point invocation has no released operation id")
    if operation is not None and fields[0] != operation:
        raise ValueError("the invocation id differs from the requested operation")
    if not isinstance(fields[1], list):
        raise ValueError("invocation parameters must be ordered data")
    return tuple(fields)


def functor_map_invocation(args, functor_id):
    """Read the unchanged seven-field invocation of a registered functor's map.

    Require its exact action id, matching ordered parameter data and a typed source
    arrow. Both actual image endpoints and the original generalized argument remain
    in the returned tuple. Formal types, selected images and live owners are checked
    by the caller; this helper supplies framing, not functor laws or portability.
    """
    if not isinstance(functor_id, str) or not functor_id:
        raise ValueError("a functor map invocation has no registered id")
    fields = point_invocation(args, functor_id + "#map")
    arrow = fields[2]
    if not isinstance(arrow, dict) or arrow.get("ctor") != "map":
        raise ValueError("a functor map invocation requires its selected map action")
    action_fields = arrow.get("args")
    if not isinstance(action_fields, list) or len(action_fields) != 2:
        raise ValueError("a functor map action requires its selected functor and complete source arrow")
    action, source_arrow = action_fields
    if not isinstance(action, dict) or action.get("ctor") != functor_id:
        raise ValueError("the functor map action differs from the dispatched functor")
    parameters = action.get("args")
    if not isinstance(parameters, list):
        raise ValueError("functor map parameters must be ordered data")
    # Compare JSON data, so false and zero are distinct and object-key order is not.
    if json.dumps(parameters, sort_keys=True, allow_nan=False) != \
            json.dumps(fields[1], sort_keys=True, allow_nan=False):
        raise ValueError("the functor map action changed its ordered invocation parameters")
    typed_map(source_arrow)
    return fields


def presentation_invocation(args):
    """Read parameters, inverse flag, source, target and point data, in that order.

    The enclosing request's op identifies the published comparison. This helper
    checks framing only and does not identify endpoints or prove inverse laws.
    """
    if not isinstance(args, dict) or args.get("ctor") != "presentationApply":
        raise ValueError("a comparison invocation requires the presentationApply envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 5:
        raise ValueError("a comparison invocation requires all five ordered fields")
    if not isinstance(fields[0], list):
        raise ValueError("comparison parameters must be ordered data")
    if not isinstance(fields[1], bool):
        raise ValueError("the comparison direction must be a boolean")
    return tuple(fields)


def _selected_parameter(args, kind):
    if not isinstance(args, dict) or args.get("ctor") != kind:
        raise ValueError("a selected %s requires the %s envelope" % (kind, kind))
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("a selected %s requires its registered id and ordered parameters" % kind)
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a selected %s has no registered id" % kind)
    if not isinstance(fields[1], list):
        raise ValueError("selected %s parameters must be ordered data" % kind)
    return tuple(fields)


def category_parameter(args):
    """Read (registered category id, ordered parameters), retaining the selection.

    The formal caller checks the complete category dictionary. Parsing establishes
    no category laws and does not identify categories from shared carriers.
    """
    return _selected_parameter(args, "category")


def cartesian_map(args):
    """Read the accepted reindex action, ordered parameters and original receiver.

    The actual base map is retained among the complete declaration parameters.
    This checks framing only, not cartesianness or the selected endpoint types.
    """
    if not isinstance(args, dict) or args.get("ctor") != "cartesianMap":
        raise ValueError("a cartesian arrow requires the cartesianMap envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 3:
        raise ValueError("a cartesian arrow requires its reindex action, parameters and receiver")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a cartesian arrow has no registered reindex action")
    if not isinstance(fields[1], list):
        raise ValueError("cartesian arrow parameters must be ordered data")
    return tuple(fields)


def constructed_category(args):
    """Read (registered constructor id, ordered complete argument descriptors).

    The published constructor signature fixes each argument kind and its order.
    Category arguments recursively use category/constructedCategory descriptors;
    object and functor arguments keep their existing complete representations.
    Parsing does not supply a category law or select a different formal category.
    """
    return _selected_parameter(args, "constructedCategory")


def construction_field(args):
    """Read a complete retained construction and its ordered non-proof data-port index.

    This index is determined by the published dataConstructor, not by the diagram.
    The formal caller validates the selected field and complete expected type.
    """
    if not isinstance(args, dict) or args.get("ctor") != "constructionField":
        raise ValueError("a construction data field requires the constructionField envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 4:
        raise ValueError("a construction data field requires its limit, diagram, packet and port index")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a construction data field has no registered limit id")
    if type(fields[3]) is not int or fields[3] < 0:
        raise ValueError("a construction data-port index must be a natural number")
    return tuple(fields)


def structured_projection_action(args):
    """Read a complete constructed category and its foundational projection action.

    Actual accepted constructor semantics and functor types are caller-validated.
    This descriptor is action data inside map, not a registration address.
    """
    if not isinstance(args, dict) or args.get("ctor") != "structuredProjectionAction":
        raise ValueError("a structured projection action requires the structuredProjectionAction envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("a structured projection action requires its complete category and field")
    constructed_category(fields[0])
    if fields[1] not in ("source", "target", "inclusion"):
        raise ValueError("a structured projection action requires source, target or inclusion")
    return tuple(fields)


def functor_parameter(args):
    """Read (registered functor id, ordered parameters) without choosing an action.

    Full source and target dictionaries belong to the formal declaration and caller.
    """
    return _selected_parameter(args, "functor")


def cell_component(args):
    """Read (cell id, ordered parameters, complete receiver, inverse flag).

    Registered source and target functors determine the component and endpoints.
    Parsing does not prove invertibility or identify its action with an identity.
    """
    if not isinstance(args, dict) or args.get("ctor") != "cellComponent":
        raise ValueError("a natural component requires the cellComponent envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 4:
        raise ValueError("a natural component requires its id, parameters, receiver and direction")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a natural component has no registered cell id")
    if not isinstance(fields[1], list):
        raise ValueError("natural component parameters must be ordered data")
    if not isinstance(fields[3], bool):
        raise ValueError("natural component orientation must be Boolean")
    return tuple(fields)


def component_address(cell_id, constructors=()):
    """Canonical public address; registration and type validity belong to the kernel."""
    if not isinstance(cell_id, str) or not cell_id:
        raise ValueError("a component address requires a registered cell id")
    if not isinstance(constructors, (list, tuple)) or any(
        not isinstance(item, str) or not item for item in constructors
    ):
        raise ValueError("a component address requires an ordered constructor path")
    if not constructors:
        return cell_id + "#component"
    return "component:" + json.dumps(
        [cell_id, list(constructors)], ensure_ascii=False, separators=(",", ":")
    )


def constructed_cell_component(args):
    """Read (outer-to-inner constructor ids, complete component fields).

    The nested receiver has the derived constructed type. No constructor action,
    naturality, invertibility, or endpoint identity is established by parsing.
    """
    if not isinstance(args, dict) or args.get("ctor") != "constructedCellComponent":
        raise ValueError("an induced component requires the constructedCellComponent envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("an induced component requires its constructor path and component")
    constructors, component = fields
    if not isinstance(constructors, list) or not constructors:
        raise ValueError("an induced component requires a nonempty constructor path")
    base = cell_component(component)
    component_address(base[0], constructors)
    return constructors, base


def core_object(args):
    """Read the complete underlying object of the caller's selected Core source."""
    if not isinstance(args, dict) or args.get("ctor") != "coreObject":
        raise ValueError("a core object requires the coreObject envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 1:
        raise ValueError("a core object requires one complete receiver")
    return fields[0]


def core_iso(args):
    """Read (source, target, forward, backward), retaining both map directions.

    This frames the caller's independently selected comparison; it does not prove
    inverse equations, map laws, equality of endpoints, or mathematical correctness.
    """
    if not isinstance(args, dict) or args.get("ctor") != "coreIso":
        raise ValueError("a core comparison requires the coreIso envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 4:
        raise ValueError("a core comparison requires both complete endpoints and both directions")
    return tuple(fields)


def construction_invocation(args, operation):
    """Read (construction id, ordered parameters, complete source receiver).

    Use the exact dispatched construction operation id. The formal caller checks
    the dependent signature; no parameter or source is inferred from backend data.
    """
    if not isinstance(operation, str) or not operation:
        raise ValueError("a construction invocation has no registered id")
    if not isinstance(args, dict) or args.get("ctor") != operation:
        raise ValueError("the construction invocation differs from the dispatched operation")
    parameters = args.get("args")
    if not isinstance(parameters, list):
        raise ValueError("construction parameters must be ordered data")
    if "receiver" not in args:
        raise ValueError("a construction invocation has no complete source receiver")
    return operation, parameters, args["receiver"]


def _action_identity(identity):
    if not isinstance(identity, dict) or len(identity) != 1:
        raise ValueError("an action identity requires one complete published edge descriptor")
    if "functor" in identity or "classifierForget" in identity:
        selected = identity.get("functor", identity.get("classifierForget"))
        if not isinstance(selected, str) or not selected:
            raise ValueError("an action identity has no registered id")
    elif "constructorMap" in identity:
        fields = identity["constructorMap"]
        if not isinstance(fields, list) or len(fields) != 2 or \
                not isinstance(fields[0], str) or not fields[0]:
            raise ValueError("a constructor identity requires its id and complete inner identity")
        _action_identity(fields[1])
    else:
        raise ValueError("an action identity requires a published edge descriptor")
    return identity


def action_address(identity):
    """Encode a canonical non-FunctorEntry edge address; registry checks remain external."""
    _action_identity(identity)
    if "functor" in identity:
        raise ValueError("a bare registered functor uses its own published operation address")
    return "action:" + json.dumps(identity, ensure_ascii=False, separators=(",", ":"))


def action_identity(address):
    """Read only the canonical address spelling, including complete constructor nesting."""
    if not isinstance(address, str) or not address.startswith("action:"):
        raise ValueError("a derived action requires its action address")
    identity = json.loads(address[7:])
    if action_address(identity) != address:
        raise ValueError("a derived action address must use its canonical compact identity")
    return identity


def _descriptor_action_identity(descriptor):
    if not isinstance(descriptor, dict) or not isinstance(descriptor.get("ctor"), str) or \
            not descriptor["ctor"] or not isinstance(descriptor.get("args"), list):
        raise ValueError("a complete action requires its id and ordered parameters")
    name, fields = descriptor["ctor"], descriptor["args"]
    if name == "classifierForget":
        if len(fields) != 2 or not isinstance(fields[0], str) or not fields[0] or \
                not isinstance(fields[1], list):
            raise ValueError("classifier forgetting requires its id and ordered actual parameters")
        return {"classifierForget": fields[0]}
    if name == "constructorMap":
        if len(fields) != 2 or not isinstance(fields[0], str) or not fields[0]:
            raise ValueError("a constructor action requires its constructor and complete inner action")
        return {"constructorMap": [fields[0], _descriptor_action_identity(fields[1])]}
    return {"functor": name}


def method_invocation(args, operation, functor_id):
    """Read (method id, ordered complete action descriptors, actual receiver).

    The last descriptor is the independently selected method functor; preceding
    descriptors are its residual structural actions in composition order. Keep
    every original parameter packet and receiver. Registry membership, the full
    selected route, types, result interface and live owners are kernel checks.
    This parser has no raw-receiver compatibility fallback.
    """
    if not isinstance(functor_id, str) or not functor_id:
        raise ValueError("a method invocation has no selected functor id")
    request = construction_invocation(args, operation)
    if not request[1]:
        raise ValueError("a method invocation requires its final complete functor descriptor")
    identities = [_descriptor_action_identity(descriptor) for descriptor in request[1]]
    if identities[-1] != {"functor": functor_id}:
        raise ValueError("the method invocation differs from its selected registered functor")
    return request


def action_invocation(args, address):
    """Read the existing object frame without discarding nested action parameters."""
    identity = action_identity(address)
    request = construction_invocation(args, address)
    if len(request[1]) != 1:
        raise ValueError("a derived object action requires its one complete action descriptor")
    if _descriptor_action_identity(request[1][0]) != identity:
        raise ValueError("the complete action descriptor differs from the registered address")
    return request


def action_map_invocation(args, address):
    """Read the unchanged apply packet for the canonical derived map action.

    These checks establish framing and exact descriptor occurrence only. Registry
    membership, constructor functorialAction, formal endpoints and owners remain
    independently checked; source data do not prove any mathematical law.
    """
    identity = action_identity(address)
    request = point_invocation(args, address + "#map")
    arrow = request[2]
    if not isinstance(arrow, dict) or arrow.get("ctor") != "map" or \
            not isinstance(arrow.get("args"), list) or len(arrow["args"]) != 2:
        raise ValueError("a derived map action requires its complete action and source arrow")
    action, source_arrow = arrow["args"]
    if json.dumps(request[1], sort_keys=True, allow_nan=False) != \
            json.dumps([action], sort_keys=True, allow_nan=False):
        raise ValueError("the derived map action changed its complete invocation descriptor")
    if _descriptor_action_identity(action) != identity:
        raise ValueError("the complete action descriptor differs from the registered address")
    typed_map(source_arrow)
    return request


def value_data(data):
    """Supply inline computational data under the caller's fixed result contract."""
    return {"ctor": "valueData", "args": [data]}


def _service_fields(value, names):
    if not isinstance(value, dict) or set(value) != set(names):
        raise ValueError("a computation control record has unexpected or missing fields")


def result_ref(index):
    """Reference an actual earlier node result in one deferred computation only."""
    if type(index) is not int or index < 0:
        raise ValueError("a result reference requires a natural node index")
    return {"ctor": "resultRef", "args": [index]}


def result_ref_index(value):
    """Return None for ordinary JSON; reject malformed reserved reference syntax."""
    if not isinstance(value, dict) or value.get("ctor") != "resultRef":
        return None
    _service_fields(value, ("ctor", "args"))
    fields = value["args"]
    if not isinstance(fields, list) or len(fields) != 1 or \
            type(fields[0]) is not int or fields[0] < 0:
        raise ValueError("a result reference requires exactly one natural node index")
    return fields[0]


def validate_result_refs(bound, value):
    """Check nested reference scope without resolving data, types or live owners."""
    if type(bound) is not int or bound < 0:
        raise ValueError("a reference scope requires a natural bound")
    if isinstance(value, dict) and value.get("ctor") == "deferredData":
        raise ValueError("a deferred computation is a service reply, not a template data constructor")
    index = result_ref_index(value)
    if index is not None:
        if index >= bound:
            raise ValueError("a result reference is self, forward or outside its program")
        return
    if isinstance(value, list):
        for item in value:
            validate_result_refs(bound, item)
    elif isinstance(value, dict):
        for item in value.values():
            validate_result_refs(bound, item)


def _deferred_call(call):
    _service_fields(call, ("op", "input", "args"))
    if not isinstance(call["op"], str) or not call["op"] or \
            not isinstance(call["input"], str) or not call["input"]:
        raise ValueError("a deferred call requires its published operation and input addresses")
    return call


def deferred_call(operation, input_form, arguments):
    """Describe a call to a published interface; never choose its implementation.

    `arguments` keeps that operation's full ordinary request grammar. The kernel
    checks admission and derives the result interface from the formal declaration.
    """
    return _deferred_call({"op": operation, "input": input_form, "args": arguments})


def deferred_computation(packet):
    """Parse an ordered service program and return its unchanged (calls, result).

    Only framing and backward-reference scope are checked. The shared kernel
    service resolves typed node results with their actual suppliers/dependencies,
    validates every request role and executes admitted operations. This parser
    supplies no mathematical statement, owner transfer or correctness evidence.
    """
    _service_fields(packet, ("ctor", "args"))
    if packet["ctor"] != "deferredData":
        raise ValueError("a deferred computation requires the deferredData envelope")
    fields = packet["args"]
    if not isinstance(fields, list) or len(fields) != 2 or not isinstance(fields[0], list):
        raise ValueError("a deferred computation requires its ordered calls and final result template")
    calls, result = fields
    for index, call in enumerate(calls):
        validate_result_refs(index, _deferred_call(call)["args"])
    validate_result_refs(len(calls), result)
    return calls, result


def deferred_data(calls, result):
    """Return a service program directly from a handler, without a valueData wrapper.

    A node may invoke any published constructor/operation through its admitted
    input interface. Backend selection, result typing and ownership remain in the
    kernel. Optional private implementation imports have no semantic standing.
    """
    packet = {"ctor": "deferredData", "args": [calls, result]}
    deferred_computation(packet)
    return packet


def lift_parameters(args):
    """Read all explicit data arguments of the selected evidence declaration.

    The declaration and order are published in lifts[].selection. These are
    independent of the action descriptor's own arguments. Proofs are omitted.
    Historical liftInput packets may omit the member for an empty selection.
    """
    if not isinstance(args, dict) or args.get("ctor") not in {
            "liftInput", "monoLiftInput", "liftFactorInput"}:
        raise ValueError("selection parameters require a declared lift request")
    if "parameters" not in args and args["ctor"] == "liftInput":
        return []
    parameters = args.get("parameters")
    if not isinstance(parameters, list):
        raise ValueError("a lift request requires its ordered selection parameters")
    return parameters


def lift_input(args, operation):
    """Read a four-field lift request without inventing an original Arrow.

    Return (kind, lift_id, selected_action, source, base, earlier_outputs).
    For liftInput the source is the complete original Arrow; for monoLiftInput
    it is the actual selected source object. Both use the same <lift>#input
    registration and exactly four field operations. Framing is not monicity,
    inverse, factorization, universal or mathematical-correctness evidence.
    Use lift_parameters(args) for the separate ordered evidence-family data.
    """
    if not isinstance(args, dict) or args.get("ctor") not in {"liftInput", "monoLiftInput"}:
        raise ValueError("a lift request requires its declared source context")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 5:
        raise ValueError("a lift request requires id, action, source, base and preceding outputs")
    lift_id, action, source, base, outputs = fields
    if not isinstance(lift_id, str) or not lift_id:
        raise ValueError("a lift request requires its exact registered id")
    field = operation.removeprefix(lift_id + "#") if isinstance(operation, str) else ""
    order = ("obj", "hom", "forward", "backward")
    if not isinstance(operation, str) or not operation.startswith(lift_id + "#") or field not in order:
        raise ValueError("the dispatched operation differs from the selected lift field")
    if not isinstance(outputs, list) or len(outputs) != order.index(field):
        raise ValueError("the lift request omits or changes the actual preceding output prefix")
    if not isinstance(base, dict) or base.get("ctor") not in {"arrow", "subobject"}:
        raise ValueError("the lift request requires its complete base subobject")
    if not isinstance(base.get("args"), list) or len(base["args"]) != 3:
        raise ValueError("the lift base requires actual apex, ambient and inclusion data")
    if args["ctor"] == "liftInput":
        if not isinstance(source, dict) or source.get("ctor") != "arrow" or \
                not isinstance(source.get("args"), list) or len(source["args"]) != 3:
            raise ValueError("the prescribed lift requires its complete original source Arrow")
    lift_parameters(args)
    return args["ctor"], lift_id, action, source, base, outputs


def lift_factor_input(args, operation):
    """Read the separate universal-factor request; no proofs are wire fields.

    Return (lift_id, action, source, base, four_outputs, typed_g, typed_f).
    Endpoint laws belong to the independently selected formal factor and are
    tested by acceptance, never inferred from this framing validator.
    Use lift_parameters(args) for the same selection used by the four fields.
    """
    if not isinstance(args, dict) or args.get("ctor") != "liftFactorInput":
        raise ValueError("a factor request requires its complete selected lift context")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 7:
        raise ValueError("a factor request requires seven ordered fields")
    lift_id, action, source, base, outputs, g, f = fields
    if not isinstance(lift_id, str) or not lift_id or operation != lift_id + "#factor":
        raise ValueError("the dispatched factor differs from the selected lift")
    if not isinstance(outputs, list) or len(outputs) != 4:
        raise ValueError("a factor request requires exactly the four existing lift outputs")
    for output in outputs[1:]:
        typed_map(output)
    if not isinstance(base, dict) or base.get("ctor") not in {"arrow", "subobject"}:
        raise ValueError("a factor request requires its complete base subobject")
    if not isinstance(base.get("args"), list) or len(base["args"]) != 3:
        raise ValueError("the lift base requires actual apex, ambient and inclusion data")
    typed_map(g)
    typed_map(f)
    lift_parameters(args)
    return lift_id, action, source, base, outputs, g, f


def morphism_endpoint(args):
    """Read an actual callable and its source/target selector as endpoint data.

    The independent full arrow signature fixes the endpoint. This framing helper
    does not reconstruct mathematics, enumerate points, or transfer token owners.
    """
    if not isinstance(args, dict) or args.get("ctor") != "morphismEndpoint":
        raise ValueError("a declared endpoint requires the morphismEndpoint envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("a declared endpoint requires its complete callable and endpoint selector")
    callable_data, selector = fields
    if selector not in ("source", "target"):
        raise ValueError("a declared endpoint selector must be source or target")
    return callable_data, selector


def endpoint_data(callable_data, selector):
    """Retain one endpoint of the independently selected complete callable."""
    result = {"ctor": "morphismEndpoint", "args": [callable_data, selector]}
    morphism_endpoint(result)
    return result


def typed_map(args):
    """Read complete actual source, target and callable data, in that order.

    The caller checks these against its selected endpoint descriptions. This helper
    supplies framing only; it does not establish equations or transfer token owners.
    """
    if not isinstance(args, dict) or args.get("ctor") != "typedMap":
        raise ValueError("a computational map requires the typedMap envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 3:
        raise ValueError("a computational map requires its complete source, target and callable")
    return tuple(fields)


def map_data(source, target, callable_data):
    """Supply a map's actual complete endpoints and callable representation."""
    return {"ctor": "typedMap", "args": [source, target, callable_data]}


def object_product(args):
    """Read both complete object descriptors of a public binary product, in order.

    The product may be a callable's declared Prod source or a complete symbolic
    object such as a cone apex. It needs no separate named-object row. This helper
    checks framing only; it does not establish product laws or formal meaning.
    """
    if not isinstance(args, dict) or args.get("ctor") != "objectProduct":
        raise ValueError("a product endpoint requires its declared envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("a product endpoint requires both ordered object descriptors")
    return tuple(fields)


def admitted_point(args):
    """Read an independently fixed admission context without certifying its data.

    Return (object id, parameters, domain, original target, admitted target, data).
    Formal evidence and the computational data's session remain with the caller.
    """
    if not isinstance(args, dict) or args.get("ctor") != "admittedPoint":
        raise ValueError("an admitted point requires its declared envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 6:
        raise ValueError("an admitted point requires all six ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("an admitted point has no published object id")
    if not isinstance(fields[1], list):
        raise ValueError("admission parameters must be ordered data")
    return tuple(fields)


def constrained_point(args):
    """Read (constructor, original domain, data-field type, selected target, data).

    The formal caller checks the fixed closed nonrecursive one-constructor,
    no-index structure: exactly one data field and only Prop fields otherwise.
    Its actual proof stays in the checked semantic term. Parsing preserves the
    original data; it supplies no proof and does not change any opaque owner.
    """
    if not isinstance(args, dict) or args.get("ctor") != "constrainedPoint":
        raise ValueError("a constrained point requires the constrainedPoint envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 5:
        raise ValueError("a constrained point requires all five ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a constrained point has no actual constructor name")
    return tuple(fields)


def operation_expression(args):
    """Read symbolic input operation data at the caller's selected structure.

    Return (registered operation id, full parameters, operand expressions).
    This framing helper executes no mathematical operation and asserts no law.
    """
    if not isinstance(args, dict) or args.get("ctor") != "operationExpression":
        raise ValueError("an operation expression requires its declared envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 3:
        raise ValueError("an operation expression requires all three ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("an operation expression has no registered operation id")
    if not isinstance(fields[1], list) or not isinstance(fields[2], list):
        raise ValueError("operation parameters and operands must be ordered data")
    return tuple(fields)


def opaque_data(token):
    """Supply a connection-local computational token, with no semantic authority.

    The kernel retains its supplying session and owner. The adapter keeps the native
    value alive on this connection and consumes it through its registered operations.
    """
    if not isinstance(token, str) or not token:
        raise ValueError("an opaque computational value has no token")
    return {"ctor": "opaqueData", "args": [token]}


def _read_exact(n):
    buf = b""
    while len(buf) < n:
        chunk = sys.stdin.buffer.read(n - len(buf))
        if not chunk:
            raise EOFError("EOF mid-frame (wanted %d bytes, got %d)" % (n, len(buf)))
        buf += chunk
    return buf


def read_frame():
    """One frame, or None on clean EOF at a frame boundary."""
    line = b""
    while True:
        ch = sys.stdin.buffer.read(1)
        if not ch:
            if line:
                raise EOFError("EOF inside frame length %r" % line)
            return None
        if ch == b"\n":
            break
        line += ch
    if not line or any(ch < ord("0") or ch > ord("9") for ch in line):
        raise ValueError("bad frame length %r" % line)
    return json.loads(_read_exact(int(line)).decode("utf-8"))


def write_frame(obj):
    payload = json.dumps(obj, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(str(len(payload)).encode("ascii") + b"\n" + payload)
    sys.stdout.buffer.flush()


def serve(backend, backend_version, adapter_version, ops, protocol=1):
    """Announce `ops` and answer requests until EOF.

    A handler may return deferred_data(...) directly. It is sent as the ordinary
    successful reply value, then interpreted by the shared kernel service before
    computational result decoding. There is no backend callback or local recipe
    interpreter in this server.
    """
    write_frame({"op": "ready", "protocol": protocol, "backend": backend,
                 "backend_version": backend_version, "adapter_version": adapter_version,
                 "capabilities": sorted(ops)})
    while True:
        frame = read_frame()
        if frame is None:
            return
        rid, op = frame.get("request_id"), frame.get("op")
        if op not in ops:
            write_frame({"request_id": rid, "status": "unsupported", "op": op})
            continue
        try:
            if "args" not in frame:
                raise ValueError("the request omitted its args field")
            write_frame({"request_id": rid, "status": "ok", "value": ops[op](frame["args"])})
        except Exception as exc:  # the caller decodes, and rejects, whatever comes back
            write_frame({"request_id": rid, "status": "error", "kind": type(exc).__name__,
                         "message": str(exc)})
