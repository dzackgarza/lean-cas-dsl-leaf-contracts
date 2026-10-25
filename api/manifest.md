# Backend and registration manifest

A leaf package contains `leaves.json` at its root. This document is the complete
JSON interface read by `CasContract.Registration`; no kernel source is needed to
declare or launch a backend.

The [JSON Schema](manifest.schema.json) describes the same field types for editor
validation. Catalogue admission is the separate semantic check described below.
For example:

```json
{
  "backends": [
    {
      "name": "example-engine",
      "command": "python3",
      "args": ["backend/leaf.py"]
    }
  ],
  "registrations": [
    {
      "operation": "meth.cardinality",
      "input": "obj.sets.fin",
      "backend": "example-engine"
    }
  ]
}
```

## Fields

| Location | Field | JSON type | Required | Meaning |
| --- | --- | --- | --- | --- |
| Root | `backends` | Array of backend objects | No; defaults to `[]` | Programs available to this leaf package. |
| Root | `registrations` | Array of registration objects | No; defaults to `[]` | Computational registrations to be checked against the public catalogue. |
| Backend | `name` | String | Yes | Local backend identity referenced by registrations. Use a distinct name for each program. |
| Backend | `command` | String | Yes | Executable to start. An executable name is found through the process environment; an explicit path may also be supplied. |
| Backend | `args` | Array of strings | No; defaults to `[]` | Ordered arguments passed verbatim to the executable. |
| Registration | `operation` | String | Yes | Exact public operation or derived callable-port address. |
| Registration | `input` | String | Yes | Exact public input-form address accepted by that operation. |
| Registration | `backend` | String | Yes | `name` of a backend in this same manifest. |

Only these fields carry meaning. Additional fields are ignored, including fields
named `priority`, `capabilities`, `result`, `timeout`, `cwd` or `env`. They cannot
change admission, select mathematical structure, alter a result representation,
or override another registration. A missing optional array differs from `null`:
`null` is not an array and is malformed. Numeric command arguments must be written
as strings. Missing required fields and fields of the wrong JSON type are malformed.

The manifest parser reads these fields; admission then checks that each operation
and form exists, that the operation accepts the form, and that the named backend
is declared. The generated [declared API reference](README.md) publishes those
addresses. A syntactically valid registration may therefore still be rejected.
An unrecognized address does not create a new operation or form.

## Process and port

The program runs with the manifest's directory as its working directory. In the
example, `backend/leaf.py` is relative to that directory. The executable and
arguments are passed directly to process creation: there is no implicit shell,
shell quoting, environment-variable substitution or `~` expansion. A Python
script may itself select an installed engine from its inherited environment. A
manifest does not specify an alternate working directory or per-backend environment.

The kernel adds this package's `python` directory to `PYTHONPATH`, so Python leaves
can `import cas_port`. It locates the package through the host's Lake manifest:
path dependencies use their declared `dir`; Git dependencies use the configured
`packagesDir` (default `.lake/packages`) and any package `subDir`. When running in
this package's own checkout, the manifest's root `name` identifies that checkout.
An externally overridden contract dependency can be selected by setting
`CAS_LEAF_CONTRACT_PATH` to the absolute checkout directory containing
`python/cas_port.py`. This host environment setting takes precedence over the
manifest for the contract package only; it is not a field in `leaves.json`.
A missing contract package fails startup instead of using an unrelated working
directory as the contract checkout.

Ordinary process environment variables remain available.
The optional `CAS_SAGE_PYTHON` and `CAS_GAP_PYTHON` selectors identify engine Python
interpreters where configured by the host; the backend must explicitly use them
if it launches an engine subprocess. They do not expand inside manifest strings.

The process first writes the length-framed `ready` announcement described in
[CasContract/Port.lean](../CasContract/Port.lean). It then reads requests and writes
replies on the same live standard-input/standard-output connection. Standard
output contains protocol frames only; diagnostics can go to standard error.
Announcement capabilities do not add registrations. A program is started when
an admitted registration first needs it, and its connection may own opaque data
that later requests reuse.

One backend may implement many registrations. The `op` of each request is the
exact admitted operation address, while `args` retains that operation's complete
public input representation. The request does not contain the manifest's backend
name or a second replacement operation name. See [wire examples](wire-examples.md)
for the framing, `apply` packet, structured data and failure replies.

## Matching and overlap

Use an exact named input form for a specialized implementation or the registered
category address for an implementation of all admitted values of that category.
Category-wide inputs retain each value's complete descriptor; they are not an
instruction to replace that value with a familiar object. A callable, registered
presentation comparison or lift may also have its own exported complete-request
input address.

An operation's presence in `operations` does not put that same string in
`inputForms`. For example, `op.rings.pow` can use an admitted named ring form or
`cat.rings`; its operation id is not itself a declared input form. Binder and
object-application fields have the complete-request forms explicitly listed in
`inputForms`. Registered comparisons likewise expose their own complete-request
form: a registration for `cmp.f9.translation` on input `cmp.f9.translation` receives
that comparison's `presentationApply` packet. It does not implement an arbitrary
other comparison. Admitted endpoint-form registrations remain peers of this own
request form. Choose both addresses from their respective inventories or the public
constructor-induced component address family. The latter uses the canonical
`component_address(cell_id, constructors)` encoding of an invertible exported cell
and a finite path of exported constructors with comparison actions. It cannot be
exhaustively listed in the finite JSON arrays.

A directly applied construction exports object operation `<construction id>` and
map point operation `<construction id>#map`; both use the complete request input
`<construction id>#input`. Its object image has the separate input form
`<construction id>` at the registered target category, so inherited target
operations can accept that full image. These are projections of the registered
construction's full dependent functor signature, not new per-category operation
rows. A leaf must support the selected categories, functors and all other parameters
in each request it accepts. A supported object action does not imply a supported
map point action or a later target operation. Use the exported construction and
admission inventories for concrete addresses and the
[direct-construction protocol](wire-examples.md#direct-constructions) for their data.

A registered functor exports object operation `<functor id>`, morphism-action
operation `<functor id>#map`, and complete-request input `<functor id>#input`.
These addresses project the two actions of its existing full dependent declaration.
The object action also retains its admitted source-object and source-category input
forms; these registrations are peers of the complete-request form. An overlap is
ambiguous. The morphism-action request retains the original complete source arrow
and both already computed image endpoints, with every ordered functor parameter.
It can request the whole map or apply it to a supplied generalized point through
the existing `apply` record. See [registered functor actions](wire-examples.md#registered-functor-actions).
Providing one action does not provide the other or a later target operation.

The shared executor materializes the registered action before an unrelated target
consumer needs its data. A self-contained returned packet is usable by another
admitted consumer; a nested opaque dependency keeps its supplying live session.
The registration never authorizes a consumer to infer a category, reconstruct a
source functor, relabel an opaque owner or change selected image endpoints.
The actual operation and input inventories are generated from the compatible built
kernel and contract sources; these address rules are not a substitute for that export.

Classifier forgetting and constructor-induced actions have a canonical derived
address family. The object operation is `action:` followed by compact JSON of the
complete registered edge identity; its map and input addresses append `#map` and
`#input`. The identity is `{"classifierForget":id}` or
`{"constructorMap":[constructor_id,inner_identity]}`, where an inner identity may
also be `{"functor":id}`. Bare functor roots are rejected: they use the existing
functor addresses above. Every constructor must publish `functorialAction`, and all
nested identities must be registered. Only the canonical spelling is admitted.

These derived actions accept their own complete request input. Actual declaration
parameters stay in the nested complete action descriptor carried by each request;
the registration identity cannot replace that data. The finite `edgeActions`
inventory reports currently derived addresses, while the recursive family permits
further registered constructor nesting. `categoryConstructors[].functorialAction`
publishes the actual constructor action signature or `null` when absent. See
[derived structural actions](wire-examples.md#derived-structural-actions).

A registered natural cell exports the point operation `<cell id>#component` and
complete input of the same address. The common `apply` request retains the
component's declaration parameters, complete selected receiver, direction, and
both actual endpoints. An inverse direction is available only for a cell declared
invertible. This registration does not cover another cell or turn a comparison
into an identity based on shared carriers. See the exported `cells` inventory and
[natural cell component protocol](wire-examples.md#natural-cell-components).

Exact-form and category-wide registrations have equal standing. If both are
applicable to one invocation, that invocation is ambiguous; manifest order and
backend name do not define priority. Avoid overlapping registrations unless an
explicit backend selection is part of the caller's independently provided run
configuration. Do not infer a dispatch rule from the `ready` announcement.
