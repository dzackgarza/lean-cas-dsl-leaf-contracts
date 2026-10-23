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

Python helpers `point_invocation`, `admitted_point`, `operation_expression`,
`typed_map` and `object_product` parse public envelopes. `value_data`, `opaque_data`
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
when a graph requires its actual inventory. A kernel/equalizer returns
`cone(apex,inclusion)`; a cokernel/coequalizer returns `cocone(apex,projection)`.
The complete input diagram retains both parallel arrows, including any actual
declared zero arrow. Arrow objects return `arrow(source,target,map)`; subobjects
return `subobject(apex,ambient,inclusion)`.

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

`liftInput` also retains the selected lift id, complete action, source Arrow and
base subobject. `X` is the source Arrow's source; `K` is the base subobject's apex.
`U(O)` retains the actual `O` and full selected action. Each step receives the
previous step's actual object and inclusion. Completed `liftedSubobject` stores
all four outputs of every step. `createdCone` stores its selected lift, exact
source diagram and complete computed target cone. No reply supplies a proof of
monicity, inverse equations, commutation or universality.

## Malformed cases and ownership

| Data | Framing failure |
| --- | --- |
| `typedMap(X,Y)` | Callable missing |
| Map declares target `Z` instead of selected target `Y` | Complete endpoint changed |
| Graph omits or repeats an actual domain key | Incomplete total callable |
| Matrix row omits a column | Incomplete inner callable |
| `opaqueData("")` | Empty token |
| `operationExpression("mor.sets.divide",...)` | Morphism id used as an operation id |
| Cone missing a defining leg | Incomplete result |
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
