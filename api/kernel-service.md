# Kernel-mediated computational services

A leaf handler may compute through published constructors and operations without
choosing their implementations. It returns a deferred program directly as the
normal successful reply's `value`. The shared kernel service interprets that
program before ordinary computational result decoding.

`deferredData` and `resultRef` are computational control forms. They create no
mathematical constructor, operation, category, equality or proof. The formal
question remains fixed independently of the program and its results.

## A constructor followed by another published operation

This complete reply requests an existing group construction and then its published
multiplicative-monoid action:

```json
{
  "request_id": 70,
  "status": "ok",
  "value": {
    "ctor": "deferredData",
    "args": [
      [
        {"op": "con.automorphisms", "input": "con.automorphisms#input",
         "args": {"ctor": "con.automorphisms",
                  "args": [{"ctor": "category", "args": ["cat.groups", []]}],
                  "receiver": {"ctor": "coreObject", "args": [
                    {"ctor": "obj.groups.cyclic", "args": [5]}]}}},
        {"op": "fun.groups.monoid", "input": "fun.groups.monoid#input",
         "args": {"ctor": "fun.groups.monoid", "args": [],
                  "receiver": {"ctor": "resultRef", "args": [0]}}}
      ],
      {"ctor": "resultRef", "args": [1]}
    ]
  }
}
```

This framing example prescribes no computed group or monoid. The final actual
data must satisfy the original call's independently fixed result interface. It
does not establish that the returned construction equals the object originally
requested. A well-framed wrong answer remains possible.

The equivalent Python builders retain supplied packets:

```python
from cas_port import deferred_call, deferred_data, result_ref

def node(tag, *args):
    return {"ctor": tag, "args": list(args)}

calls = [
    deferred_call("con.automorphisms", "con.automorphisms#input", {
        "ctor": "con.automorphisms",
        "args": [node("category", "cat.groups", [])],
        "receiver": node("coreObject", node("obj.groups.cyclic", 5)),
    }),
    deferred_call("fun.groups.monoid", "fun.groups.monoid#input", {
        "ctor": "fun.groups.monoid", "args": [], "receiver": result_ref(0),
    }),
]
program = deferred_data(calls, result_ref(1))
# A registered handler returns program directly, without a value_data wrapper.
```

Every call has exactly `op`, `input` and `args`. The addresses select a published
interface; they do not select a backend or authorize a leaf to declare the result
type. `args` keeps that interface's existing complete request grammar, including
all selected parameters and endpoints. The kernel derives and checks the full
result interface from the registered declaration and actual request.

## Public interface families

The node grammar covers the existing published operation families. Each keeps its
ordinary request and result contract, with the same checks after reference
resolution.

| Published family | Required retained data |
| --- | --- |
| Methods | Construction-invocation envelope with the exact method id, chosen receiver, ordered complete residual-action descriptors and final method-functor descriptor; the declared result interface. |
| Properties | Exact registered declaration, selected receiver/form and the property's existing complete request and result interface. |
| Element operations, named morphisms, object applications and binders | Complete `apply` data where prescribed: original generalized domain, argument, whole callable, parameters and endpoints. |
| Functor and direct-construction object/map actions | Actual source object or complete original source arrow, full functor parameters, and both selected image endpoints around a map action. |
| Classifier-forget and constructor-induced edge actions | Canonical recursive action identity, complete nested parameter descriptor, actual source and image data. |
| Natural-cell components, including constructor-induced components | Selected cell, constructor path, parameters, direction, receiver and endpoints. |
| Cartesian reindex maps | Registered family action, original base morphism, full parameters and receiver. |
| Presentation comparisons | Selected comparison, direction, complete parameters, actual endpoints and original point data. |
| Ordinary limits and colimits | Full registered diagram constructor and ordered defining maps; complete declared construction result data. |
| Prescribed lift fields and factors | Selected lift/evidence parameters, complete source/action/base data, prior actual outputs and defining/factor maps. |

The [complete method request](wire-examples.md#complete-method-requests) keeps its
whole selected computation visible. A node uses the existing method operation id
and admitted input form; its `args` is
`{"ctor":method_id,"args":[residual_action_1,...,method_functor],"receiver":actual_input}`.
Every descriptor includes all ordered explicit data parameters. At a fully
transported method-owner input, the residual list is empty and the final functor
descriptor remains. The receiver keeps the chosen registration form; the method's
published shape fixes any formal Core wrapping without adding a wire wrapper.
An explicitly admitted source-composite implementation owns its supplied residual
actions. An unrelated target-category implementation receives their actual results
through the shared executor.

References inside those descriptor parameters are resolved with their original
typed dependencies, just like references in the receiver. A kernel may explicitly
permit legacy raw receiver data only after checking an empty residual route and
no explicit computational method parameters. This is not a parser fallback or
permission to reconstruct absent parameters from the receiver.

Use the compatible exported declarations and admission addresses for each concrete
call. Object, category and ordinary constructor descriptors can be typed input or
result data without being executable operation addresses themselves.

This protocol does not claim that every generic kernel path is implemented merely
because constructor or functor examples pass. A required uncovered
declaration-to-invocation path remains kernel work. A missing native implementation
remains a computational gap. Neither changes mathematical availability.

## Typed dependencies and exact endpoints

Nodes are indexed from zero in array order. A call can reference only earlier
nodes; the final result template may reference any completed node. References can
occur inside ordinary public records, parameter arrays, diagrams and callable
frames. They denote complete results, not arbitrary field projections. Existing
published construction-field and defining-map interfaces remain the way to select
such data.

For example, after object-action calls at `X` and `Y` occupy nodes zero and one,
the whole map call can retain those selected image results:

```python
from cas_port import map_data

# functor_id, parameters, X, Y and f_data are the independently selected inputs.
FX, FY = result_ref(0), result_ref(1)
map_operation = functor_id + "#map"
map_call = deferred_call(map_operation, functor_id + "#input", node(
    "apply", map_operation, parameters,
    node("map", node(functor_id, *parameters), map_data(X, Y, f_data)),
    FX, FX, FY, node("identity", FX, FX),
))
```

References resolve to actual results **with their typed dependencies**. Copying
only their JSON is insufficient. The kernel checks every referenced value at its
declared role, including parameters and complete endpoints. It retains the actual
computational provenance and supplying live session. Equal JSON does not merge
independently owned results, and a final result supplied by backend B does not
acquire the returning leaf A's owner.

A template may assemble several results into a complete public record. Separate
opaque dependencies stay separate; they cannot be flattened to one arbitrary
owner or erased to make a later call dispatch. Their next consumption requires an
admitted implementation or representation bridge compatible with those owners.
A complete self-contained result without opaque dependencies remains portable.
New opaque literals supplied by the program's authoring leaf remain owned by that
live connection. A program cannot choose an owner through a serialized field.

A called implementation may itself return a deferred program. The same shared
service resolves it in a fresh reference scope before completing the outer node.
The program is never handed to an unrelated consumer as a recipe. A literal nested
`deferredData` inside a request/result template is malformed; express those
dependencies as nodes or let a called implementation return its own service reply.
`resultRef` is valid only in its own service program.

## Framing, failures and authority

The [JSON Schema](deferred.schema.json), Lean `DeferredData.decode` and Python
`deferred_computation` describe the control structure. The schema cannot express
the dynamic index bound; the decoders additionally enforce backward-only references.
They do not prove registry membership, parameter types, functor laws, result
equality, live-session validity or computational correctness.

| Case | Required treatment |
| --- | --- |
| Missing/extra control fields, self/forward/out-of-range reference or malformed reserved reference | Malformed service program. |
| Unknown or inadmissible operation/input pairing, or wrong parameter/role/endpoint after resolution | Reject the computational request; do not reinterpret the original mathematical question. |
| Valid published request with no implementation or compatible bridge | Computational gap. |
| Foreign, expired or lost opaque owner | Unavailable computation. |
| Well-framed but mathematically wrong returned data | Retain as untrusted computational data for independent checking. |

The constructor-centered implementation model lets a producer request existing
target constructors and retain their defining maps and selected comparisons. The
kernel interprets and composes those computations. A leaf need not implement an
interpreter for unrelated categorical recipes.

Native adaptations and optional private imports of other implementations are
permitted. Those choices have no semantic standing. Source isolation is a useful
diagnostic arrangement, not a rule on leaf internals, and optional shared code does
not close a missing generic kernel service.

This executable division reuses established prior art:
[Sage's functor API](https://doc.sagemath.org/html/en/reference/categories/sage/categories/functor.html)
separates object and morphism actions under common application machinery, while
[CAP's functor API](https://homalg-project.github.io/CAP_project/CAP/doc/chap5_mj.html)
supplies selected source and range images around a morphism action. Here formal
definitions and laws remain upstream. The deferred protocol is an engineering
mechanism for invoking existing published computational interfaces.
