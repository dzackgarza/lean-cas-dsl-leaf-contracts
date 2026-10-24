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
A closed connection before a complete reply, an interrupted length or payload, and
a broken request pipe are `unavailable`. Complete invalid headers, invalid UTF-8/JSON,
wrong request identities and invalid reply fields are `malformed` even if the program
then exits. Neither outcome changes the mathematical question or restarts an opaque owner.

Python helpers `object_field`, `point_invocation`, `presentation_invocation`, `admitted_point`,
`constrained_point`, `operation_expression`, `construction_invocation`, `category_parameter`,
`constructed_category`, `cartesian_map`, `construction_field`, `structured_projection_action`,
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

## Whole-domain callable requests

The common `apply` envelope also requests the complete map `f : X → Y`. Its
generalized domain is the original `X`, and its argument is `id_X`:

```python
whole_request = apply(
    operation, declaration_parameters, actual_arrow,
    X, X, Y, node("identity", X, X))
```

`X`, `Y` and `actual_arrow` are the complete supplied descriptors, including
selected structures and actual computational dependencies. The request asks for
the entire composite `id_X ≫ f`. It supplies no representative point, finite
sample, substituted source or new invocation mode. A finite reply supplies the
whole callable at its actual inventory; an infinite reply can be owned native
callable data. For example, complete replies can use:

```python
from cas_port import map_data, opaque_data, value_data

value_data(map_data(X, Y, actual_callable_data))
opaque_data("callable-created-on-this-connection")
```

These are framing alternatives, not pre-existing values. The token must refer to
the callable actually retained by that connection. A later operation consumes
the same returned callable; it cannot replace it with the named formal arrow or
restart its owner. The result retains domain `X`; on a non-singleton domain a
single point of `Y` cannot stand for that callable. The existing scalar convention
for the registered global-point domain remains unchanged.
`point_invocation(request, operation)` reads the same seven fields as for pointwise use.

The exact common parameters and complete-request addresses for derived maps are:

| Declared callable | Operation and complete-request input | Ordered `apply` parameters |
| --- | --- | --- |
| Named morphism | Its published morphism ID | All explicit declaration parameters |
| Registered object application | `<object id>#application` | All explicit application-declaration parameters |
| Natural cell component | `<cell id>#component` | `[declarationParameters,receiver,inverse]` |
| Component through a nonempty constructor path | `component:` followed by compact JSON `[cellId,constructorIds]` | `[declarationParameters,constructedReceiver,inverse]` |
| Family-reindex cartesian map | `<reindex functor id>#cartesian` | `[functorParameters,receiver]` |

Component and cartesian-map parameters preserve a nested ordered array as their
first field; they are not flattened. Complete-request addresses must exist in the
exported `inputForms` inventory, except for the unbounded constructed-component
family governed by its published path grammar. A named mathematical category
uses its registered ID, such as `cat.sets`; a surface name such as `Sets` is not
a registration address. A constructed category with no named row retains its
full `constructedCategory` descriptor and exported category expression; no
category ID is invented for it. Element-operation IDs have their ordinary
compatible object/category input forms, as specified below, and do not acquire
an own-address input form merely by using whole-domain invocation.

## Terminal-point operation requests

A nullary algebraic operation still has a categorical source: its declared
terminal object. Its common invocation retains the actual map from the original
global-point domain to that source. Zero algebraic operands do not remove the
seventh field of `apply` or replace that map with an empty list:

```python
terminal_request = apply(
    operation, declaration_parameters, node(operation, *declaration_parameters),
    original_domain, operation_source, target, accepted_source_comparison)
```

`operation_source`, `target` and `accepted_source_comparison` are supplied by the
caller from the selected declaration and its checked source comparison. The
comparison runs from `original_domain` to `operation_source`. When the caller
supplies an identity, its framing is
`identity(original_domain,original_domain)` with exactly those descriptors.
A leaf must not substitute a chosen singleton, the number zero, another terminal
representation or a new comparison. The dispatched operation remains its ordinary
ID, such as `op.monoids.one`, with all of its selected declaration parameters.

The result uses the existing `valueData` or owned `opaqueData` interface for the
point at `target`. The ordinary scalar convention applies when this is the
registered global-point domain. A request at a different generalized domain
still retains that domain's full callable interface. It is not collapsed to
one scalar by the nullary nature of the algebraic operation.

A retained symbolic nullary point may also occur inside a complete expression
using the existing five-field descriptor:

```python
terminal_point = node(
    "operationPoint", operation, declaration_parameters, accepted_source_comparison,
    original_domain, selected_object)
```

Here `selected_object` is the complete selected structure that fixes the point's
carrier. The original source comparison, domain and ordered parameters remain
attached. This is point data, not a new operation address. Its operation row must
be nullary. The alternative
`operationExpression(operation,declaration_parameters,[])` is an algebraic
expression with no operands, and is meaningful only within its complete selected
element interface; it is not an empty common-invocation argument.

## Complete expression inputs and returned-data reuse

The argument of an invocation can be the entire released expression, including
its `element`, `operationExpression`, `point`, `operationPoint`, `pointView`,
`admittedPoint`, composition or mediator envelopes. A request need not have
evaluated every nested expression in a separate earlier port call. The handler
consumes the actual supplied expression at its declared selected parameters and
endpoints. An arrow descriptor contains parameters only; an
`operationExpression` additionally contains its actual operands. Neither is
retyped as the other to fit an engine API.

After a computation, subsequent inputs instead retain its **actual returned
data**, including every required structured field and every nested opaque token.
A descriptor of the mathematical operation is not permission to recompute its
formal representative and substitute that for the returned data. Complete
expressions may mix ordinary symbolic inputs with retained computational
operands; each opaque dependency keeps its original live owner. A callable or
point wrapped in a larger expression, endpoint, admission or result does not
become portable merely because the outer envelope is ordinary JSON.

The same rules govern successive point applications, whole-map applications,
terminal operations and operations on structured results. Only admitted
registrations on the existing owning connection can consume its tokens; a
missing registration reports `noImplementation`, and a lost connection reports
`unavailable` rather than reviving them on a new process. Portable inline data remain
reusable by compatible admitted implementations. No returned data or packet
changes the independently fixed mathematical question.

## Family reindexing and cartesian arrows

The `categoryFamilies` metadata publishes each accepted family's actual realization,
transport, transport semantics and ordered dependent parameter schema. A reindexing functor
publishes its full declaration signature and source and target fibre expressions. Its object
action uses the existing functor-action descriptor; its whole-morphism action uses the existing
`map` descriptor with that complete selected functor action. Neither action drops the base
morphism or reconstructs it from two parameter names.

For a registered reindexing action `F` along `φ : p → q` and an original receiver `X` in
the fibre at `q`, the cartesian arrow in the total category is described by:

```python
arrow = node("cartesianMap", reindex_functor_id, declaration_parameters, original_receiver)
```

`declaration_parameters` contains every explicit argument of that registered functor
declaration in order, including the actual base map and all of its selected parameters.
`original_receiver` is the complete original object, with any computational ownership retained.
The mathematical caller fixes the arrow by the accepted family transport and Mathlib's
`CoGrothendieck.cartesianLift`: its source is the total object over `p` with fibre value
`φ*X`, and its target is the original total object over `q` with value `X`. No equality of
underlying carriers supplies those selections.

Only accepted `familyReindex` functor entries derive the callable operation and input address
`<reindex_functor_id>#cartesian`. The exported functor's `cartesian` record gives that address,
the family identifier and the canonical action signature. Applying this arrow uses the ordinary
seven-field `apply` request at that address, with the same descriptor as its arrow field and
the exact source, target and generalized domain supplied by the caller. Replies use the ordinary
`valueData`, `opaqueData` or declared map/result interface; this adds no proof or backend-defined
category. Missing or extra descriptor fields, a mismatched reindex action, omitted declaration
parameters or changed selected endpoints are malformed.

The common invocation's parameters are exactly
`[declaration_parameters, original_receiver]`. Its first field is the entire
ordered functor-parameter array. To request the whole cartesian arrow, use its
complete source as both domain and source, and `identity(source,source)` as the
argument; the target remains the original total object.

`Backend.CartesianMap` and Python `cartesian_map` check the three-field framing. The kernel
validates it against the retained formal application, rather than treating the descriptor as
an authority to choose a family, transport or cartesian lift. The receiver's owner and all owners
carried by the declaration parameters remain available to subsequent computations.

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

### Constructor-induced components

Each constructor layer uses its published `functorialAction`, `comparisonAction`,
`identityComparison`, and `compositionComparison`. The left and right endpoints are the
composites of the individually mapped route edges. To obtain the induced comparison,
first invert the left route-expansion comparison, then apply `comparisonAction`, then
apply the right route-expansion comparison. Empty routes use `identityComparison`;
successive edges use `compositionComparison`. Repeat inside-out through the retained
constructor path. These are the accepted declarations exported under `cellConstructors`
in `api/declared-ports.json`; identity or composition preservation is never assumed to
hold by definitional equality.

An accepted constructor's `comparisonAction` acts on the complete registered comparison.
For a nonempty constructor path, retain that path in outermost-to-innermost order:

```python
constructors = [outer_constructor_id, inner_constructor_id]
base = node("cellComponent", cell_id, declaration_parameters, constructed_receiver, False)
component = node("constructedCellComponent", constructors, base)
address = component_address(cell_id, constructors)
request = {
    "op": address,
    "args": apply(address, [declaration_parameters, constructed_receiver, False],
                  component, domain, constructed_source, constructed_target, point_data),
}
reply = value_data(result_point_data)
```

The operation and complete-input address are `component:` followed by compact JSON
`[cell_id, constructors]`. The nested component uses the **constructed receiver**,
whose complete type and both endpoints are fixed by those declared comparison actions.
It is not sent to the unconstructed cell's `<cell id>#component` port. An empty path
uses the original four-field component and original address.

Every constructor must publish the required comparison action. Changing a constructor,
its order, a full declaration parameter, receiver, or orientation changes the declared
request. The current constructor comparison actions consume an accepted invertible
comparison in both orientations; a noninvertible cell is available only at its ordinary
unconstructed component address. No graph or
identity representation is presumed. Nested opaque data retain their owning connection.
`constructed_cell_component`, `component_address` and `Backend.ConstructedCellComponent`
provide framing and canonical addresses; they supply no mathematical evidence.

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
| Accepted category-constructor application | `node("constructedCategory", constructor_id, ordered_argument_descriptors)` |
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

A `constructedCategory` retains the full accepted constructor application even
when its resulting category has no separately registered name. The exported
`categoryConstructors` metadata gives every argument's kind in order and the actual
`semantics` declaration with its dependent type. Category arguments use `category`
or another `constructedCategory`; object and functor arguments use their existing
complete descriptors. For example, the core of the already selected category is
`node("constructedCategory", "ctor.core", [groups])`. A constructor id, argument
count, argument kind, or complete dictionary that differs from the formal caller's
selection is malformed. Shared carriers and identical printed names do not identify
different category structures.

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

### Selected operation bindings

An operation row binds its surface name at its complete selected owner category.
The name is the binding key; arity and numerical parameters belong to that one
binding's signature. An explicit binding stops inherited lookup along that
structural path. An incompatible arity does not authorize a different farther
binding. Surviving inherited bindings are compared as complete operation
families by the formal caller, as specified below. A leaf does not choose among
them by carrier equality or engine class. These are mathematical selection
rules applied before dispatch.

The resulting request still names the selected operation ID and its full
parameters. The published `op.monoids.mul` and `op.monoids.one` take the selected
monoid as their parameter; their source interfaces are respectively the product
of its carrier with itself and the registered global-point source. A group
inherits these through its selected forgetful structure. An explicitly selected
ring multiplication remains its ring operation binding. The unit operation
does not declare arbitrary numeral literals for a monoid.

```python
monoid_multiplication = node("op.monoids.mul", selected_monoid)
monoid_unit = node("op.monoids.one", selected_monoid)
```

These arrow descriptors have no operand fields. Invoke them using common
`apply` with the exact supplied source and target descriptors. Registration uses
a supported selected monoid-object form or `cat.monoids`; neither operation ID
is itself an invented input form. The generated inventories settle which
concrete addresses exist in the selected release.

#### Agreement of inherited operations

The formal caller may establish that two surviving bindings agree by checking
equality of their **entire universally abstracted operation families**. The
comparison includes the complete source category and its chosen structure,
every dependent source, route and declaration parameter, and a variable source
object. These variables are fixed independently before the whole morphisms are
compared. No particular object or operand has yet been substituted. Each
morphism retains its actual operand domain and result interface. Unresolved
variables, a selected numerical parameter, or agreement at sampled operands
cannot stand for this universal context.

When common endpoints require registered comparisons, their actual directed
components are composed into the operation families before checking equality.
The two original operation IDs, routes and these transports remain part of the
interpretation. An equality of carriers does not supply that transport or
identify independently selected algebraic structures.

If the complete typed families are definitionally equal, Lean's checked
reflexivity proof at that exact equality type is sufficient. No additional
operation-agreement registry row is required. Otherwise an existing accepted
comparison must establish the same whole-family equality with its actual
transports; without it the surviving bindings remain ambiguous. Several
possible transports remain distinct unless the accepted coherence or checked
whole-family equality identifies their resulting operations. None is selected
by owner name, declaration ID, route length or registry order.

After this check, the formal caller instantiates the witness at the exact
selected context. Precomposition through a structural functor retains that
functor and every parameter. It does not drop a nonidentity presentation or
replace a prescribed structural map. For example, the whole multiplication of
a ring agrees with the whole multiplication of its selected multiplicative
monoid; the monoid obtained through the ring's additive group instead carries
the ring's addition. Merely sharing a carrier does not identify these operations.

All of this agreement stays on the interpretation side. Requests still carry
their ordinary declared operation, full parameters, actual arrows, endpoints
and computational arguments. Replies supply only their declared result data.
There is no agreement tag, proof field, certificate, alternative endpoint choice
or leaf-supplied assertion. Agreement of mathematical operations also does not
rank competing computational registrations or certify any returned answer.

This is the public specification in
[`operation-agreement.md` at the pinned mathematics revision](https://github.com/dzackgarza/lean-categories/blob/4acd7aff0350c5a84ce695e42eaadfd583ac343d/LeanCategories/Catalogue/Registry/operation-agreement.md).
The complete rules needed to consume the wire interface are given above; a
leaf does not need to implement the comparison procedure.

#### Additive operations and their carrier comparison

The selected additive monoid exposes its full binary addition through
`op.additive_monoids.add`, with ordered declaration parameters `[M]` for the
complete selected additive monoid `M`. Its source is the product of that
monoid's carrier with itself and its target is the same selected carrier.
Registration uses a compatible object form or `cat.additive_monoids`; the
operation ID itself is not a new input form.

`fun.additive_groups.additive_monoid` forgets the inverses of the actual selected
additive group while retaining its addition and zero. It has no explicit
declaration parameters. Its object-action request uses the existing functor
request with `args: []` and the actual group as `receiver`. Its retained image
and addition descriptor therefore have the ordinary forms:

```python
additive_monoid = node(
    "functorAction", node("fun.additive_groups.additive_monoid"), selected_group)
addition_arrow = node("op.additive_monoids.add", additive_monoid)
```

The invertible cell `cell.additive_groups.carrier` compares the two set-carrier
routes of that same additive group: the existing route through groups and the
route through its additive monoid. Both components act as the identity on its
carrier; their exact selected endpoints and route data remain present. This
set-level comparison does not identify addition with another multiplicative
structure. The complete component data use:

```python
carrier_comparison = node(
    "cellComponent", "cell.additive_groups.carrier", [], selected_group, False)
```

For common `apply`, the operation and complete-request input address are
`cell.additive_groups.carrier#component`, and the ordered parameters are
`[[],selected_group,inverse]`. `False` has the displayed forward direction;
`True` selects its inverse. The original generalized domain, actual argument
and exact comparison endpoints stay in the same seven-field invocation.
Neither this cell nor the additive operation adds a wire constructor.

#### Automorphism multiplication convention

When the supplied selected monoid is the underlying monoid of `Aut(X)`, it
retains the multiplication of that complete automorphism group. For two
automorphisms `a` and `b`, their forward maps satisfy
`forward(a * b) = forward(b) ≫ forward(a)`. Thus, on a selected set-valued
action, `(a * b)(x) = a(b(x))`. Categorical composition `f ≫ g` applies `f`
first and `g` second. The forward and backward projections of `a` are its
actual `hom` and `inv`; the unit is the identity automorphism. This order is
part of the declared mathematical interface and must be preserved when a
native permutation or automorphism API uses a different composition convention.

This convention is the existing general `forward_mul` statement in the public
mathematical interface `CasCatalogue.Algebra.AutomorphismArrows`, published in
`lean-categories` revision `4ea82e7cf6f5fd75234fd2ce18255a45ad851379`.
It holds for the complete selected category and object. The request still uses
the ordinary selected-monoid operation and common `apply` frame; no finite
sample, permutation carrier, or additional automorphism operation is implied.

### Admitted group and module morphisms

The published hom-set objects retain all selected structures:

| Object | Ordered parameters | Application address |
| --- | --- | --- |
| `obj.sets.group_morphisms` (`GroupMorphisms`) | `[G,H]`, the two selected groups | `obj.sets.group_morphisms#application` |
| `obj.sets.module_morphisms` (`ModuleMorphisms`) | `[R,M,N]`, the selected ring and both modules over it | `obj.sets.module_morphisms#application` |

Their `inclusion` fields retain the entire underlying function. Their admission
declarations bundle that same function only after the formal caller establishes
its complete homomorphism or linearity law. This uses the existing
`admittedPoint(objectId,parameters,domain,originalFunctionObject,selectedHomObject,
actualOriginalFunction)` envelope. The domain and original function-object
descriptor come from the supplied request; a leaf does not replace them with a
chosen singleton or a graph sample. No law, predicate claim or proof is wire data.

An application request takes the actual admitted morphism and actual argument
as the two ordered product components, and preserves the carrier endpoints of
the selected groups or modules. Its arrow descriptor contains the same ordered
parameters as the application declaration. Infinite function data may be owned
callables. Neither admission nor application changes which connection owns
the original function. Implementations may use the published application input
address or another compatible admitted form such as `cat.sets`; no additional
group- or module-specific wire constructor is introduced.

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

An explicit inventory must agree with any independently fixed domain inventory;
it cannot shorten a matrix row or omit an index. For a structured map whose
source is a supplied computational object, that source must already carry its
inventory, for example `finiteData(source,keys)`. Repeating `keys` in a
`finiteGraph` checks agreement with that source; it does not replace its source
descriptor. A source without a usable inventory requires an owned or symbolic
callable. A function-valued record field with no independently fixed inventory
can instead carry its inventory in the `finiteGraph` itself.

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

The optional `PowerObjectEntry.directImage` is a different complete interface:
for `f : X → Y` it gives the whole map `𝒫(X) → 𝒫(Y)`. The published set instance
has the ordinary morphism address `mor.sets.direct_image`, with ordered
parameters `[X,Y,f]`:

```python
PX = node("obj.sets.power_set", X)
PY = node("obj.sets.power_set", Y)
direct_image_arrow = node("mor.sets.direct_image", X, Y, f)
direct_image_request = apply(
    "mor.sets.direct_image", [X, Y, f], direct_image_arrow,
    original_domain, PX, PY, actual_subset_family)
```

The supplied subset family has the original domain and target `𝒫(X)`; the reply
retains that domain and target `𝒫(Y)`. Whole-map invocation instead uses `PX` as
the domain and `identity(PX,PX)` as the argument. This is an ordinary named
morphism and ordinary `apply` request. It does not add a `powerObjectMap` field
spelling. The earlier `powerObjectMap(...,"image",[X,Y,f])` is the global subset
containing the image of all of `X`; replacing a supplied subset family with that
global subset would change the request. No finiteness or injectivity of `f` is
required by the public direct-image declaration.

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

Here `objectProduct` is the **returned apex field**, not merely a source-type
annotation on a callable. Its two factors must each have the complete public
object interface of the selected category. A factor can reuse an actual object
already supplied in the request, including its retained action and native data.
Each `typedMap` above uses the exact returned `apex` as its source and the actual
corresponding request factor as its target. The reply includes both projections;
returning just `objectProduct(X,Y)` does not implement the product operation.

The complete result remains available as
`constructionApex(limitId,diagram,completeCone)` and each actual projection as
`constructionLeg(limitId,diagram,completeCone,index)`. The diagram and complete
cone remain attached when an apex or projection is reused. An operation on the
apex consumes its actual returned object representation; a composition with a
projection consumes that stored map. An implementation registers the subsequent
declared operation on an admitted input form or the selected category. It does
not invent `apply` under the creating limit id. The projection example below
shows how a later operation receives the retained map in its argument.

A portable apex may have projections that are owned by a live connection.
Projecting that apex does not make its portable object data session-specific;
the complete result still retains the connection required by those projections.
If an apex factor or its object data itself contains an opaque token, its later
uses retain that same owner. No projection discards the complete parent result.

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
stored map. `subobjectApex`, `subobjectInclusion`, `constructionField` and `constructionLeg` retain
their complete returned receivers. `limitLeg` is only a formal reference; it
cannot replace a returned leg or establish that a computation ran.

To transport a complete comparison through a foundational projection, use
`structuredProjectionAction(constructedCategory, field)` as the action of an existing
`map(action, comparison)` descriptor. `constructedCategory` retains the accepted constructor
and all ordered typed arguments. `field` is exactly `source`, `target` or `inclusion`;
surface `obj()` is encoded as `source`. The actual accepted Arrow or full-subcategory
semantics fixes the projection functor and its type; a constructor identifier alone cannot
authorize it. Source and target act on the corresponding components of an arrow comparison;
inclusion retains the underlying arrow comparison. Both directions of a presented result
remain available, with all their owners. The descriptor is not an operation address and
supplies no naturality or inverse proof. `Backend.StructuredProjectionAction` and Python
`structured_projection_action` check its two-field framing and declared field spellings;
the kernel independently checks the complete selected action.

For example, `compose(pointArrow, constructionLeg(...))` retains a point followed
by an actual computed projection. A subsequent declared operation or equality
observation receives that full expression as its argument, with the original
declared operation's address as `op`. The leaf can evaluate the projection while
interpreting that argument, using the stored callable and its owning session.
An arbitrary ordered data-port projection has the framing
`constructionField(limitId, sourceDiagram, completePacket, k)`. Here `k` is a
natural-number index into the accepted `dataConstructor`'s non-Prop ports in
declaration order, including its object ports. A data-port index differs from a
diagram-object index: one independent defining map can determine several cone
legs. `constructionField` retains the complete returned cone, cocone or
`createdCone` packet and the original source diagram, so projection preserves
creation and presentation context. Its fixed formal field and expected type
come from the accepted constructor; a missing port or incompatible field is
malformed. `Backend.ConstructionField` and `construction_field` parse these four
fields without proving a comparison or universal law. This descriptor adds no
operation or registration address and can be consumed through the existing
object, map and complete-result interfaces at its declared field type.

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
all four outputs of every step. Each retained `liftStep` also has the same top-level
`parameters` list as its four field requests, so evidence-family choices absent from
the action parameters survive later result consumption. `createdCone` stores its selected lift, exact
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
