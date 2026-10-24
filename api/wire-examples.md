# Computational wire examples

This is the concrete companion to [the protocol](../CasContract/Port.lean) and
[the declaration reference](declared-ports.json). A leaf needs these public inputs
and its engine; it does not need to read kernel source. These are framing and
parameter-order examples, not acceptance assertions or expected mathematical answers.

## Requests, replies and failures

Each JSON frame has its UTF-8 **byte** length in ASCII decimal, a newline, then
the payload. Signs, whitespace, decimal points and non-ASCII digits are not valid
length characters. `0`, `false`, `[]` and `{}` in `args` are distinct and reach
the implementation unchanged. The ready frame is informational.

Here is a complete request for the published square-root morphism at a closed point:

```json
{"request_id":17,"op":"mor.sets.real_sqrt","args":{"ctor":"apply","args":["mor.sets.real_sqrt",[],{"ctor":"mor.sets.real_sqrt","args":[]},{"ctor":"obj.sets.fin","args":[1]},{"ctor":"obj.sets.reals","args":[]},{"ctor":"obj.sets.reals","args":[]},{"ctor":"element","args":[{"ctor":"obj.sets.reals","args":[]},{"ctor":"numeral","args":[11]}]}]}}
```

The connection can retain a native exact result, returning an opaque token. These
are the successful opaque-reply and failure shapes for that request:

```json
{"request_id":17,"status":"ok","value":{"ctor":"opaqueData","args":["native-result-17"]}}
{"request_id":17,"status":"unsupported","op":"mor.sets.real_sqrt"}
{"request_id":17,"status":"error","kind":"EngineError","message":"engine computation failed"}
```

Inline success uses `{"request_id":17,"status":"ok","value":{"ctor":"valueData","args":[DATA]}}`,
where `DATA` has the declared result form. `unsupported` is `noImplementation` and
must name the dispatched operation. An engine failure is `unavailable`. A wrong
request id, unknown status, invalid frame, missing component or incompatible
endpoint is `malformed`. A well-framed wrong computation remains a correctness
failure. An unhandled kernel exception is internal; it cannot judge the question invalid.

Python helpers `object_field`, `point_invocation`, `presentation_invocation`, `admitted_point`,
`constrained_point`, `operation_expression`, `construction_invocation`, `category_parameter`,
`functor_parameter`, `core_object`, `core_iso`, `typed_map` and `object_product` parse public envelopes. `value_data`, `opaque_data`
and `map_data` construct them. They establish framing, not mathematical laws.

## Notation used below

This Python only builds ordinary JSON and introduces no additional wire tags:

```python
def node(tag, *args):
    return {"ctor": tag, "args": list(args)}

def apply(operation, parameters, arrow, domain, source, target, argument):
    return node("apply", operation, parameters, arrow,
                domain, source, target, argument)

def element(selected, expression):
    return node("element", selected, expression)

def numeral(selected, n):
    return element(selected, node("numeral", n))

one = node("obj.sets.fin", 1)  # current public source; copy the request's actual descriptor
Z = node("obj.sets.integers")
Q = node("obj.sets.rationals")
R = node("obj.sets.reals")
C = node("obj.sets.complexes")
Qring = node("obj.rings.rationals")
Qcomm = node("obj.commutative_rings.rationals")
```

The kernel selects the global-point source from the registry. A leaf copies the
request's actual generalized domain; it must not manufacture `Fin(1)` for every
request. A nonconstant generalized point retains its actual domain.

## Registered presentation comparisons

A comparison uses its own original operation id and a five-field application
packet. Its explicit parameters, direction, complete source and complete target
come from the selected formal request. For the published F9 comparison, a forward
request has this framing (the point token already belongs to the live connection):

```python
first = node("obj.commutative_rings.f9_x")
second = node("obj.commutative_rings.f9_y")
comparison_request = {
    "request_id": 23,
    "op": "cmp.f9.translation",
    "args": node("presentationApply", [], False, first, second,
                 node("opaqueData", "original-point")),
}
```

The boolean is a JSON boolean, not an integer or string. `False` selects the
forward map; `True` selects its inverse, with the actual source and target in
that inverse order. A structural action may change their complete descriptors;
consume the ones actually supplied. The point retains its original data, which
may be portable or owned. The reply uses the ordinary `valueData` or `opaqueData`
result interface at the selected target. This example prescribes no field
polynomial, generator image or numerical answer.

The comparison's own exported input address admits this complete request for
that same comparison. Admitted source/target endpoint registrations remain
available at the same time. Overlap is ambiguous, without priority or fallback;
an unapplied comparison-arrow descriptor does not by itself add a complete-request
candidate. The Python helper `presentation_invocation` returns all five ordered
fields and rejects a missing field, an extra field or a nonboolean direction.

## Registered object fields

A map published by an object row uses `objectField(object_id, field, parameters)`.
The selectors `inclusion` and `constants` retain their declared maps. An accepted
`ObjectEntry.functorPresentation` also exposes both directions of its identification:

```python
forward = node("objectField", object_id, "presentation", declaration_parameters)
backward = node("objectField", object_id, "inversePresentation", declaration_parameters)
```

`presentation` selects the registered identification's `hom`, from the selected
functor image along its declared route to the named object. `inversePresentation`
selects its `inv` in the reverse direction. Every explicit object declaration
parameter is retained in order. The kernel instantiates the actual registered
functor, argument, route and identification; a shared carrier or matching endpoint
does not supply a comparison. The selected object must publish the requested field.

These are arrow descriptors and may occur in `map`, `compose`, `point`, or a
declared callable's complete `apply` request. They introduce no new operation or
registration address. `object_field` and `Backend.ObjectField` check the three-field
framing only; the formal caller checks the registered field and exact endpoint types.

## Natural cell components

Every `cells` API record publishes its complete declaration, component type, source and target
routes, invertibility, and derived `<cell id>#component` operation/input address. The component
at a selected receiver uses the same point-application contract as other callable maps:

```python
component = node("cellComponent", cell_id, declaration_parameters, receiver, False)
request = {
    "op": cell_id + "#component",
    "args": apply(cell_id + "#component",
                  [declaration_parameters, receiver, False], component,
                  domain, source, target, point_data),
}
reply = value_data(result_point_data)
```

`source` is the complete object obtained by the published left route at `receiver`; `target`
is the object obtained by the right route. An inverse request has `True` and swaps those two
endpoints, and is valid only for an invertible cell. The kernel retains the actual component
and validates its complete type before dispatch. Equal underlying carriers do not erase
its map. Parameters and receiver can contain previously computed data; the ordinary ownership
rule retains every opaque value's owning session. A component descriptor can also appear
inside `typedMap`, functor `map`, and categorical `compose` data.

Omitting the receiver, supplying a non-Boolean orientation, naming an unregistered cell,
selecting an inverse of a noninvertible cell, or changing either full selected endpoint is
malformed. A well-framed result at those endpoints can still be mathematically wrong.
The `cell_component` Python helper and `Backend.CellComponent` Lean helper check framing only.

## Direct constructions

A registered `ConstructionEntry` is applied at its full dependent parameters. It
has one object-action address `<id>`, one map point address `<id>#map`, and one
complete-request input `<id>#input`. Its constructed-image form `<id>` belongs to
the registered target category. The source category is the complete source of the
selected functor; no underlying-set or per-category substitute is implicit.

For example, this object-action request selects the category dictionary and the
complete core source before asking for a computational group representation:

```python
groups = node("category", "cat.groups", [])
X = node("obj.groups.cyclic", 5)
core_X = node("coreObject", X)
action = node("con.automorphisms", groups)
constructed_X = node("functorAction", action, core_X)
object_request = {
    "request_id": 29,
    "op": "con.automorphisms",
    "args": {"ctor": "con.automorphisms", "args": [groups],
             "receiver": core_X},
}
```

Its manifest addresses are operation `con.automorphisms`, input
`con.automorphisms#input`. A successful reply uses `valueData(DATA)` with the
construction target's complete published representation, or an `opaqueData` token
owned by the replying live connection. This example specifies framing only; it
prescribes no computed group, cardinality or generators.

Selected parameters always retain order and structure:

| Declared parameter | Descriptor |
| --- | --- |
| Registered category dictionary | `node("category", category_id, ordered_parameters)` |
| Registered functor dictionary | `node("functor", functor_id, ordered_parameters)` |
| Registered object | `node(object_id, *ordered_parameters)` |
| Object of the selected core source | `node("coreObject", underlying_object)` |
| Morphism of that core source | `node("coreIso", source, target, forward, backward)` |

The category or functor id names an exported declaration, and its parameter array
includes every explicit data parameter in that declaration's order. The kernel
checks its complete typed dictionary. The same carrier with another category
structure or another selected functor is different data. Empty parameter arrays
are explicit; they do not authorize omitted required parameters. Nested selected
parameters use the same grammar.

For a source isomorphism, `source` and `target` in `coreIso` are the complete
underlying objects. `forward` has type `source → target`, and `backward` has the
reverse type. The construction source objects are `coreObject(source)` and
`coreObject(target)`. If the source arrow is a registered presentation comparison,
the two slots retain its exact operation id, complete parameters and opposite
directions. Neither slot is an assertion that two presentations are equal.

The construction's map acts on a supplied point through the common seven-field
`apply` request. In the following schema, `construction_id`, `parameters`, `X`,
`Y`, `comparison_id`, `comparison_parameters`, `domain` and `point_data` are the
values already selected in the formal request, not choices made by the leaf:

```python
action = node(construction_id, *parameters)
comparison = node(
    "coreIso", X, Y,
    node("presentation", comparison_id, comparison_parameters, False),
    node("presentation", comparison_id, comparison_parameters, True),
)
source = node("functorAction", action, node("coreObject", X))
target = node("functorAction", action, node("coreObject", Y))
map_operation = construction_id + "#map"
map_request = {
    "request_id": 30,
    "op": map_operation,
    "args": apply(map_operation, parameters, node("map", action, comparison),
                  domain, source, target, point_data),
}
```

Register that map point action on `<construction id>#input`. Preserve the complete
source comparison and both directions when lowering the declared functor map to
the native engine. Swapping the comparison direction changes the actual source
and target. Dropping its inverse or replacing it by an identity does not implement
the request. The point's generalized domain also remains exactly the supplied one.
The reply has the ordinary computational element representation at `target`; it
cannot select a different target, comparison or parameter dictionary.

Constructed images support the operations of their target category through the
ordinary registered structure. A subsequent method or element operation receives
the full image descriptor, actual result data and all retained dependencies. It
may register on the construction's image form `<id>` or another admitted target
form, including the target category address. All opaque data remain owned by the
session that produced them; a descriptor does not transfer tokens to another
backend. The kernel chooses formal meaning independently of returned data.

The helpers `construction_invocation`, `category_parameter`, `functor_parameter`,
`core_object` and `core_iso` check only their published packet shapes.
`point_invocation` parses the map point request. Missing parameters, missing a
comparison direction, a wrong dispatched construction id or incompatible complete
endpoint framing is malformed. A well-framed wrong result remains computational
data for independent acceptance; a helper never proves inverse laws or a group law.

## Scalars and registered point expressions

| Declared interface | Data representation |
| --- | --- |
| `Nat`, `Int` | JSON integer, e.g. `8` or `-3` |
| Public `Rat` record | `[numerator, denominator]`, e.g. `[-3,7]` |
| `WithBot Nat` | `{"ctor":"none","args":[]}` for bottom; `{"ctor":"some","args":[8]}` for a natural value |
| `Fin n` | Natural number, with its actual endpoint inventory fixing the range |
| Pair | `[left,right]`, using the two declared field forms |
| List or finite subset literal | Array of declared element data |
| Algebraic expression | `element(selected, operationExpression(...))` |
| Native exact real, complex, polynomial, infinite subset or callable | Owned `opaqueData`, or a complete supported public inline form |

The rational record has two data slots; proof slots are absent. Its numerator is
an integer, its denominator a strictly positive natural, and their greatest common
divisor is one. Zero is `[0,1]`. These are representation conditions, so `[1,0]`,
`[2,4]`, a negative denominator or a string numerator is malformed. The generic
scalar-literal validator checks those conditions and discards the checked literal;
it does not certify the result of the requested computation. Structured records
with callable, type-valued or opaque fields remain computational data and are not
reconstructed as mathematical objects or proofs. An engine's normalized rational
uses the existing record codec, without a new `rational` tag. Bottom is the public
optional constructor, not a sentinel integer or JSON null. Exact real data are
not represented by a new floating-point codec.

A registered power retains the full selected ring and the exponent before its operand:

```python
Z5ring = node("obj.rings.integers_mod", 5)
power_expression = element(
    Z5ring, node("operationExpression", "op.rings.pow", [Z5ring, 3],
                 [node("numeral", 2)]))
sqrt_expression = element(
    R, node("point", node("compose", numeral(R, 11),
                          node("mor.sets.real_sqrt"))))
pi_expression = element(R, node("point", node("mor.sets.real_pi")))
i_expression = element(C, node("point", node("mor.sets.complex_i")))
real_as_complex = element(C, node("point", node("compose", pi_expression,
                                               node("incl.sets.reals_complexes"))))
```

Composition is categorical order: first arrow, then second. These expressions
use released operation/morphism ids; no private scalar tag is needed. A value
without a complete public symbolic representation remains an owned native value.
`operationExpression` names an operation row. `mor.sets.divide` is a morphism,
so it uses the common morphism invocation rather than an operation-expression id.

A callable's arrow descriptor contains the complete declaration parameters and
no operands. The same rule applies to operation, binder and application addresses:

```python
Z5 = node("obj.sets.integers_mod", 5)
power_arrow = node("op.rings.pow", Z5ring, 3)
power_request = apply("op.rings.pow", [Z5ring, 3], power_arrow,
                      one, Z5, Z5, numeral(Z5ring, 2))
addition_arrow = node("op.rings.add", Z5ring)
pair_point = node("mediator", numeral(Z5ring, 2), numeral(Z5ring, 4))
addition_request = apply("op.rings.add", [Z5ring], addition_arrow,
                         one, node("objectProduct", Z5, Z5), Z5, pair_point)
```

The request supplies the complete source and target descriptors selected by the
caller; a backend does not choose their presentation from the sample notation.
The inclusion in `real_as_complex` is a public inclusion-row id with its ordered
declaration parameters (empty in this case). It has the same named-arrow framing.

Division's declared source is `M × Units(M)`, not `M × M`:

```python
M = node("functorAction", node("fun.rings.multiplicative_monoid"), Qring)
units = node("obj.sets.units", M)
source = node("objectProduct", Q, units)
denominator = node("admittedPoint", "obj.sets.units", [M],
                   one, Q, units, numeral(Q, 7))
division_request = apply(
    "mor.sets.divide", [M], node("mor.sets.divide", M),
    one, source, Q, [numeral(Q, 3), denominator])
```

The admission wrapper is supplied by the independently interpreted question.
A leaf consumes its original data and selected interface. It does not supply
membership evidence or turn a raw denominator into an admitted unit.

## Constrained points

An independently checked point built with a constrained structure retains five ordered
data fields:

```python
wrapped_point = node(
    "constrainedPoint", actual_constructor_name, original_domain,
    original_data_field_type, complete_selected_target, original_point_data)
```

The first field is the actual constructor's declaration name, not an object id or a
private backend tag. The second is the original generalized domain, which is not
assumed to be a singleton. The third is the complete public descriptor of the original
data-field type; the fourth is the complete selected target object. The fifth is the
original point's actual computational data, including any nested opaque tokens on
their original owning connections. Every field comes from the retained formal input
and its computational data; a leaf does not select a new constructor or target.

The kernel requires a fixed closed nonrecursive structure with exactly one constructor,
no indices, exactly one data field and only `Prop` fields otherwise. It checks that
schema and the actual constructor, domain and full endpoint types. The actual proof
remains in the checked semantic term. There is no proof field on the wire, and a reply
cannot establish the constraint or replace that proof.

`constrained_point` and `Backend.ConstrainedPoint` check the five-field framing and
nonempty constructor name only. They preserve the original data without reconstructing
a proof-bearing value or substituting a formal representative. A later declared
operation consumes these original data at the independently selected interface, with
the same ownership. The wrapper introduces no new admission or operation; ordinary
`valueData` and `opaqueData` reply alternatives are unchanged.

## Vectors, matrices, polynomials and differentials

`obj.sets.vectors` takes `[selected set, dimension]`.
`obj.sets.matrices` takes `[dimension, selected commutative ring]`.
The parameter orders and the required selected structures are different.

A matrix is a nested finite callable. This two by two integer-valued example is
a row graph whose values are column graphs:

```json
[[0,[[0,11],[1,-4]]],[1,[[0,6],[1,9]]]]
```

Every row and column index appears exactly once. `[[11,-4],[6,9]]` is not the
function codec. A row can also be an owned opaque callable. At a nonprimitive
finite domain the inventory is explicit:

```json
{"ctor":"finiteGraph","args":[[0,1],[[0,11],[1,-4]]]}
```

The matrix application address and complete request are:

```python
matrix_object = node("obj.sets.matrices", 2, Qcomm)
vector_object = node("obj.sets.vectors", Q, 2)
matrix_request = apply(
    "obj.sets.matrices#application", [2, Qcomm],
    node("obj.sets.matrices#application", 2, Qcomm), one,
    node("objectProduct", matrix_object, vector_object), vector_object,
    [node("opaqueData", "matrix-owned-here"), [[0, [3, 1]], [1, [7, 1]]]])
```

An actual token comes from an earlier reply on this connection. Example token
strings are not pre-existing data. Polynomial and power-series expressions retain
their selected coefficient object and registered generator. A native coefficient
callable or polynomial may be opaque; a sparse dictionary is not a new wire form.

For a polynomial-coordinate Kähler differential, the published
`mor.sets.kaehler_from_coordinate` takes `[R]`, from the polynomial object at `R`
to `obj.sets.kaehler_polynomials` at the same `R`. Compose the actual polynomial
point with that map, or retain the computed differential as owned data. Its
registered comparison and inverse use ordinary presentation-arrow envelopes.

## Differential values

A differential may be retained as an owned native value or represented through
its published coordinate map. For a selected commutative ring `Qcomm` and an
already supplied polynomial coordinate expression, the complete point syntax is:

```python
polynomial_object = node("obj.sets.polynomials", Qcomm)
coordinate_point = element(polynomial_object, coordinate_expression)
differential_point = node("point", node(
    "compose", coordinate_point,
    node("mor.sets.kaehler_from_coordinate", Qcomm)))
```

The declaration fixes the target module of differentials and all parameters.
When used as a common-apply reply, wrap this expression in
`value_data(element(exact_supplied_target, differential_point))`.
The coordinate is computational data supplied by the implementation; this
framing does not identify it with the derivative of any other polynomial or
supply a derivation law. `opaque_data(token)` is the ordinary alternative for a
native differential without a portable symbolic expression.

## Infinite subsets, spans and binders

A finite-subset literal is an array. It does not enumerate an infinite span.
Infinite subsets may be owned native values, or use the declared predicate/image
interfaces. With complete descriptors `X`, `Y`, a map `f : X → Y`, and a
predicate `p : X → Ω`, the complete field parameter orders are:

```python
image_point = node("powerObjectMap", "pow.sets", "image", [X, Y, f])
subset_point = node("powerObjectMap", "pow.sets", "transpose", [X, p])
membership = node("powerObjectMap", "pow.sets", "member", [X])
terminal = node("powerObjectMap", "pow.sets", "terminal", [X])
truth = node("powerObjectMap", "pow.sets", "truth", [])
units_inclusion = node("objectField", "obj.sets.units", "inclusion", [M])
```

An infinite map can be a registered map, composite, mediator, or owned callable.
A finite sample is not a total graph. The source, target, parameter objects and
actual action remain in every selected descriptor.

Every binder uses the same seven-field `apply` envelope:

| Binder id | Ordered explicit parameters | Argument |
| --- | --- | --- |
| `bind.sets.finite_sum` | `[X, additive commutative monoid, finite-subset point]` | Actual map out of `X` |
| `bind.sets.finite_product` | `[X, commutative monoid, finite-subset point]` | Actual map out of `X` |
| `bind.sets.integral` | `[lower-bound point, upper-bound point]` | Admitted continuous map |
| `bind.sets.limit` | `[limit-point morphism]` | Admitted map at that convergence domain |
| `bind.sets.limit_at_infinity` | `[selected infinity-point morphism]` | Admitted map at that convergence domain |
| `bind.sets.real_series` | `[index object]` | Admitted real summable family |
| `bind.sets.complex_series` | `[index object]` | Admitted complex summable family |
| `bind.sets.power_series_sum` | `[commutative coefficient ring, index object]` | Admitted power-series summable family |

For example, where `admitted_function` is the kernel's original complete
`admittedPoint` packet, an integral retains both bounds and its admitted domain:

```python
bounds = [numeral(R, 2), numeral(R, 5)]
integral_request = apply(
    "bind.sets.integral", bounds, node("bind.sets.integral", *bounds),
    one, admitted_function["args"][4], R, admitted_function)
```

A non-singleton generalized domain replaces `one` with the actual supplied
domain. The admitted wrapper retains the original map, original target, selected
admitted domain and ownership. Infinite maps need no graph enumeration.

## Complete results, projections and lifts

`typedMap(source,target,callable)` retains all three fields. Callable data may be
a finite graph, a released symbolic map or owned opaque data. For example:

```python
from cas_port import map_data, opaque_data, value_data

apex = node("objectProduct", Z, Z)
product_reply = value_data(node(
    "cone", apex,
    map_data(apex, Z, opaque_data("first-projection")),
    map_data(apex, Z, opaque_data("second-projection"))))
```

This complete infinite-product representation needs no carrier enumeration or
new named-object row. A finite symbolic apex supplies `finiteData(apex,keys)`
when a graph requires its actual inventory.

An accepted declared arrow can also fix a complete endpoint that has no named
object row. The endpoint keeps the actual callable and an explicit selector:

```python
from cas_port import endpoint_data, morphism_endpoint

source = endpoint_data(actual_callable, "source")
target = endpoint_data(actual_callable, "target")
callable_data, selector = morphism_endpoint(source)
```

The resulting envelope is `morphismEndpoint(actual_callable,"source")` or
`morphismEndpoint(actual_callable,"target")`. The original callable retains all
ordered parameters and any owning opaque session. Its independently fixed full
arrow signature supplies the endpoint's category and parameters. A consumer
reuses the exact supplied descriptor; it does not infer a new formal object from
the JSON or select another map with a matching carrier. A `typedMap` that already
has actual endpoint fields keeps those fields unchanged.

This endpoint descriptor supplies no point inventory, even when its formal
endpoint is finite. A finite graph needs actual `finiteData(source,keys)` whose
inner descriptor is exactly `source`. An already supplied inventory cannot be
replaced. The endpoint wrapper itself is object data and cannot be used as a
callable. `morphism_endpoint` rejects an omitted field, extra field, or selector
other than the two strings above; contextual validation also checks exact reuse
of the independently selected descriptor.

The operation's declared result type determines which complete record is needed.
A limit/equalizer cone uses `cone(apex,inclusion)`; a colimit/coequalizer cocone
uses `cocone(apex,projection)`. Their complete input diagrams retain both parallel
arrows, including any actual declared zero arrow. An operation returning an Arrow
or a full subcategory of Arrow instead uses the three fields below:

| Declared record | Complete data, in source-to-target order |
| --- | --- |
| Arrow | `arrow(source,target,definingMap)` |
| Subobject, including a kernel returned as a subobject | `arrow(kernelObject,ambient,inclusion)` |
| Quotient, including a cokernel returned as a quotient | `arrow(ambient,quotientObject,projection)` |

At an independently declared full subcategory of Arrow, the existing `subobject`
spelling also accepts the same three ordered fields. This is a compatible record
spelling, not a claim that every defining map is monic. In particular it does not
move a quotient object into the source slot. The predicate of the full subcategory
and every selected parameter remain fixed by the formal request. A plain Arrow
uses `arrow`; neither tag can turn an unrelated object into an Arrow record.

For an actual request Arrow `X → Y`, these are complete computational replies
when its respective operation returns a kernel subobject or cokernel quotient.
`X` and `Y` retain the request's complete descriptors:

```python
K = opaque_data("computed-kernel-object")
Q = opaque_data("computed-cokernel-object")
kernel_reply = value_data(node(
    "arrow", K, X, map_data(K, X, opaque_data("kernel-inclusion"))))
cokernel_reply = value_data(node(
    "arrow", Y, Q, map_data(Y, Q, opaque_data("cokernel-projection"))))
```

Every record supplies both endpoints and its defining map. Native object and map
tokens retain their original session. No reply supplies a proof of monicity,
epicity, factorization or universality. The optional `presentation` field described
in `Port.lean` compares the source endpoint; it does not change the endpoint order
or serve as a comparison of a quotient's target.

`mediator(f,g)` is the two-map mediator at a shared nontrivial domain; two closed
points carry `[leftPoint,rightPoint]`. `arrowHom` selects a complete Arrow's
stored map. `subobjectApex`, `subobjectInclusion` and `constructionLeg` retain
their complete returned receivers. `limitLeg` is only a formal reference; it
cannot replace a returned leg or establish that a computation ran.

For example, `compose(pointArrow, constructionLeg(...))` retains a point followed
by an actual computed projection. A subsequent declared operation or equality
observation receives that full expression as its argument, with the original
declared operation's address as `op`. The leaf can evaluate the projection while
interpreting that argument, using the stored callable and its owning session.
`constructionLeg` itself is not an operation address; the limit id that produced
the cone does not authorize a standalone arbitrary-map `apply` request. This
protocol publishes no generic Hom-set application address. A separately declared
callable's `apply` packet always keeps that callable's original operation id.

Prescribed subobject lifts have four ordered outputs:

| Port | Earlier output prefix | Result |
| --- | --- | --- |
| `<lift>#obj` | `[]` | Actual lifted object `O` |
| `<lift>#hom` | `[O]` | `typedMap(O,X,inclusion)` |
| `<lift>#forward` | `[O,inclusion]` | `typedMap(U(O),K,forward)` |
| `<lift>#backward` | `[O,inclusion,forward]` | `typedMap(K,U(O),backward)` |

Each request has `"parameters":[...]` at the top level, retaining every explicit
non-proof argument of the selected evidence declaration in `lifts[].selection`.
This list remains separate from the inner action's arguments: distinct choices
`L p : MonoLift U` must remain distinguishable even when `U` is independent of `p`.
Use `cas_port.lift_parameters(request)` to read that list, and `lift_input` for the
unchanged ordered request fields. New packets always include the list; only the
historical `liftInput` spelling accepts its omission as an empty list.

`liftInput` also retains the selected lift id, complete action, source Arrow and
base subobject. The explicit-object variant is
`monoLiftInput(liftId, action, X, subobject(K,U(X),i), earlierOutputs)` at the same
`<lift>#input` address. It uses the actual selected `X` without supplying an
unrelated source Arrow. The public `lift_input` Python helper distinguishes the
variants and returns their exact retained fields; it supplies no mathematical
identification or proof. `X` is the source Arrow's source; `K` is the base subobject's apex.
`U(O)` retains the actual `O` and full selected action. Each step receives the
previous step's actual object and inclusion. Completed `liftedSubobject` stores
all four outputs of every step. `createdCone` stores its selected lift, exact
source diagram and complete computed target cone. No reply supplies a proof of
monicity, inverse equations, commutation or universality.

For a creation packet `createdCone(L,D,C)`, `D` is the complete **source-category**
diagram selected before applying the registered creation functor `U`. In either
`constructionApex(limitId,D,createdCone(L,D,C))` or
`constructionLeg(limitId,D,createdCone(L,D,C),j)`, the outer diagram is this same
retained source diagram, not the mapped target diagram. The `limitId` still names
the registered target limit operation that produced `C`.

The target cone `C` is the actual returned cone over the standardized mapped
diagram: apply the registered `U` to `D`, then use the limit row's published
`standardization` comparison and `dataConstructor`. Source and target objects or
arrows must not be identified merely because their wire spellings coincide. The
index `j` is in the declared shape of `D`. A subsequent leg projection denotes
the source construction's leg, obtained through that selected creation action
from the retained target fields. It does not create a canonical replacement leg.
A consumer uses supplied complete typed-map endpoints where present; for a graph
leg, it uses its actual domain inventory and the target endpoint prescribed by
the mapped diagram. Missing endpoint context is not permission to infer an object
from the graph's outputs. Each nested creation packet retains its own lift and
source diagram, so the same rule applies at every layer.

## Compatibility with earlier boundary reports

These rules address the representation questions recorded in the leaf input
reviews of 2026-10-20 and 2026-10-21. They describe the public interface; availability
and correctness of a particular engine implementation are separate questions.

| Earlier boundary | Public form and retained information | Implementation boundary |
| --- | --- | --- |
| Nonintegral rational values | Reduced `[numerator,denominator]`; denominator positive; zero `[0,1]` | A native scalar still needs encoding in that declared type. |
| Irrational real or complex values | Owned `opaqueData`, or `element(selected,point(...))` using published maps such as square root, real/complex constants and the registered real-to-complex inclusion | No new scalar tag or guessed constant is created. `mor.sets.divide` uses its morphism interface on `M × Mˣ`, not an `operationExpression` address. |
| Bottom polynomial degree | `none()` or `some(n)` at the declared `WithBot Nat` result type | An implementation must preserve bottom instead of substituting an integer sentinel. |
| Kähler differential values | Owned native data or the complete coordinate-map point above, at the supplied target descriptor | The engine supplies the actual coordinate or differential value. |
| Matrices | Nested total finite callable graphs at the selected dimensions and coefficient type; owned native matrix data is also available | Each finite row includes its full domain; an omitted column is malformed. |
| Infinite span or subset | Owned native subset, or `powerObjectMap` `image` with `[X,Y,f]`, or `transpose` with `[X,p]`; the set wrapper is `extent(powerId,ambient,subsetData)` | The map or predicate may itself be owned and infinite. A finite generating list alone does not enumerate its span. |
| Binders | Common `apply` with ordered binder parameters, actual generalized domain and supplied callable; `admittedPoint` retains the original map and selected admission context | Bounds and all explicit parameters remain present. Infinite or foreign-session engine support is an implementation constraint. |
| Symbolic product and complete results | `objectProduct(X,Y)`, complete `cone`/`cocone`, `typedMap` legs and owned callables; Arrow records retain both endpoints and their defining map | A retained leg is consumed inside later declared operations and compositions; the creating limit id is not an arbitrary-map application address. |
| Closed points in map positions | `element` as a complete point arrow inside `compose`, `mediator` or `point`; generalized domains stay explicit in common invocations | A scalar cannot replace a function on a non-singleton domain. |
| Composed unlabelled maps | `compose(typedMap(X,Y,f),typedMap(Y,Z,g))` retains the chosen intermediate object `Y` | Bare graphs alone do not specify a structured intermediate endpoint. |
| Presentation and quotient-carrier maps | Named declared maps with all parameters, `presentation(id,parameters,inverse)`, complete `presentationApply`, and typed constituents | A comparison or generator image comes from the published mathematical declaration, not its spelling or endpoint similarity. |
| Polynomial coefficient callables | The declared record retains its support data and full coefficient callable; a native coefficient function may use owned data | A graph only on a finite support is not a total callable on the natural numbers, and this protocol introduces no implicit zero-extension rule. |
| Prescribed restrictions and creation lifts | Complete ordered `liftInput` requests and four retained outputs per restriction step; complete source diagram and target cone for creation | Unsupported engine actions or carriers remain implementation gaps; no law or fresh lift is supplied by a reply. |

The earlier reports already distinguish missing engine routines for some monoids,
unsupported actions and unavailable native dependencies from representation gaps.
The public grammar does not supply a native implementation or grant access to
another process's opaque objects. Named mathematical presentations also require
their published defining data or independently supplied explicit parameters;
a type signature alone does not choose a modulus or generator image.

## Malformed cases and ownership

| Data | Framing failure |
| --- | --- |
| `typedMap(X,Y)` | Callable missing |
| Map declares target `Z` instead of selected target `Y` | Complete endpoint changed |
| Direct-construction request omits a selected category/functor parameter | Full dependent request is incomplete |
| `coreIso` omits its backward map or reverses only one endpoint | Complete comparison framing changed |
| Construction map packet names another `<id>#map` | Dispatched operation identity changed |
| Graph omits or repeats an actual domain key | Incomplete total callable |
| Matrix row omits a column | Incomplete inner callable |
| `opaqueData("")` | Empty token |
| `operationExpression("mor.sets.divide",...)` | Morphism id used as an operation id |
| Cone missing a defining leg | Incomplete result |
| `arrow(source,target)` or `subobject(source,target)` | Defining map missing |
| Three-field Arrow record at an unrelated scalar/object type | Independently fixed record interface absent |
| `subobject` at a plain Arrow type | Declared full-subcategory interface absent |
| Three-field completed `liftedSubobject` | Component outputs absent |
| Private tag, engine source, or proof in place of a declared field | No public representation |

Opaque tokens retain their supplying live connection even inside records,
admissions, symbolic wrappers, maps and structured results. Later operations
consume them only through admitted registrations on that connection. Reconnecting
does not revive them; a foreign session cannot interpret the strings. Portable
inline data contain no nested opaque token. A leaf never supplies the owner,
session identity, mathematical certificate or a semantic override in its reply.

Category-wide registrations use the registered category id and the same complete
data grammar. They cover new objects and returned objects in that exact category
after the kernel's selected structural transport. Exact-form and category-wide
registrations are peers: if both apply, dispatch is ambiguous. There is no hidden
specialization priority or fallback order.

### Separate universal factor

A lift's separate `<lift id>#factor` operation uses the same `<lift id>#input`
registration and the following complete packet:

```json
{"ctor":"liftFactorInput","parameters":["<ordered selected evidence arguments>"],
 "args":["<lift id>","<selected action>","<actual X>",
  "<complete base subobject>",["<O>","<typed hom>","<typed forward>","<typed backward>"],
  "<typed g: U(Y) → K>","<typed f: Y → X>"]}
```

The result is `typedMap(Y, O, callable)`, using the actual cone domain and actual
object output. `Mono i` and `U.map f = g ≫ i` are checked formal inputs, supplied
before dispatch; neither is wire data. Both factor equations remain independent
acceptance obligations. This operation does not add a fifth lift field. Its
full dependent type is exported as the lift's separate `factor` metadata.

`LiftFactorInput.decode` and Python `lift_factor_input` validate the seven-field
packet, exact operation, complete base and four typed prior outputs. Composed
lifts execute the inner factor first, then feed that actual arrow into the
outer factor's base-map slot under the canonical `MonoLift.factor_comp` law.
The original four-field outputs and session ownership survive both requests.
