# Python computation SDK

`cas_port.serve(backend, backend_version, operations)` serves
`cas-computation/2`. `operations` maps published operation addresses to Python
callables. Each callable receives the complete operation argument packet. Its
return value is JSON data or a generator with the suspension contract below.
The SDK supplies framing, negotiation, local exports and continuation storage.
The kernel supplies prepared interfaces, scope authority and result admission.

The project declares its Python dependencies in `pyproject.toml` and locks them
in `uv.lock`. A provider can start with
`uv run --frozen --project CONTRACT_ROOT python PROVIDER_SCRIPT`, with
`CONTRACT_ROOT/python` on `PYTHONPATH`. Its computation environment must contain
the declared SDK dependencies. The public packet helpers in `cas_port` retain
the operation-specific input and output grammar.

`functor_map_invocation(packet, functor_id)` and
`action_map_invocation(packet, action_address)` read the existing seven-field
`apply` packet both for an original source action and for later use of its actual
returned map. Later use retains the complete returned `typedMap` in the arrow
slot, the same published operation and ordered parameters, its unchanged source
and target, and the new generalized argument. Derived actions keep their complete
canonical action descriptor in the parameter slot. The kernel retains the
original selected registration; a parsed packet supplies no selection or owner
authority. The helpers preserve callable and symbolic result data without
interpreting it or replacing it with the original action recipe.

An ordinary handler can call `cas_session.request_input()` for its exact input
address. Native-export handlers receive that address in their published context.
`cas_session.ComputationError(kind, message)` preserves an external computation's
error fields. `cas_session.UnsupportedOperation(operation)` reports the consumed
operation as unsupported. Both failure paths revoke that request's new leases.

`cas_port.read_frame(source)` and `write_frame(value, target)` also accept binary
streams. Their default streams are standard input and standard output.

## Category interfaces

`api = cas_port.load_interfaces("declared-ports.json")` reads the generated
category interface, with its original provenance. It performs no network access
or computation. `api.category("cat.groups")` selects that exact category id.
`category.signatures` contains its complete native category and realization
signatures; `category.families("object")`, `families("morphism")`,
`families("operation")`, `families("method")` and the other published kinds
provide direct maps by exact id. Overloaded surface names are metadata, not
Python lookup priorities.

Each `category.family(kind, id)` has `signatures`, `metadata`, `details`
and its published `operations`. Parameters keep their order, dependent type,
binder visibility and proof status; result signatures retain selected
structures, universes, comparison data, laws and permitted choices. The native
`api.datatypes` and `api.type_aliases` retain the generated type closure.
None of those records is a serializer or a proof supplied by a provider.

Limit-family `details` include both the unchanged raw cone operation and its
separate native universal subfamily. `universal.precedingFields` records the
original earlier cone slot, and `universal.fields` retains native data and law
positions. Creation-lift `details` retain the fixed comparison template, original
raw cone/universal inputs and every native `LiftsToLimit` field. The shared
`family.call` helper uses those actual exported addresses with the existing
dependent request packet; it does not infer an owner or comparison from the
result's type. See [native universal data](wire-examples.md#native-universal-data).

`cas_port.created_cone(packet)` reads exactly the original selected lift,
complete source diagram and complete target cone. Nested envelopes and scoped or
owned data are preserved unchanged. The parser supplies no construction selection
or universal-property proof.

For an object or morphism family, `family.construct(parameters)` builds its
existing `{"ctor": id, "args": parameters}` descriptor. Supply every complete
ordered argument descriptor prescribed by the declaration; the SDK does not
recover a structure from a carrier. `category.select(parameters)` builds the
existing selected-category descriptor. Category constructors are distinct:
`api.category_constructors["ctor.arrow"].construct([category.select(parameters)])`
builds the category of arrows, not an object in the original category.
The constructor checks the published argument count and category framing;
the kernel checks the full dependent types and selected structures.

`family.field(selector, parameters)` uses `objectField` for a map that the
object actually declares, including the chosen presentation or refinement in
either direction. It preserves the complete ordered parameters.
`family.call(input_form, arguments, operation=address)` describes one of that
family's published operations. Omit `operation` only when its own id is the
published address. Immediate functor object/map actions and other declared
ports appear in `details` and `operations`. The caller supplies the exact
input-form address and complete existing request packet. The kernel prepares
the selected mathematical application and chooses its realization.
`api.call(address, input_form, arguments)` provides the same helper for any
published address. Neither helper invokes an engine synchronously.

For a supplied scoped reference, use
`result = family.result(cas_session.proxy(reference))`.
`result.project(index)` and `result.apply(arguments)` delegate to the actual
scoped proxy's existing graph calls; use them in `suspend` or `deferred_data`.
Projection indexes are the kernel's ordered computational field indexes, which
exclude proof fields. Native datatype field lists do not define those indexes
or a wire codec. The dependent result role is supplied and checked by the
kernel. Capture `result.value` explicitly when it is needed after suspension.
Access after a gateway expires or without its declared capture fails.

Derived category expressions are accessible by their exact exported expression
through `api.category_expression(expression)`. Families with no fixed owner
remain in `api.generic_families` under their typed `(kind, id)`; no category is
guessed. Regenerating the accepted catalogue updates these views without a
hand-maintained family table. Publication of a signature establishes no backend
availability or acceptance of its computations.

## Connection

The process writes this frame before it reads an invocation:

```json
{"op":"ready","protocol":2,"contract":"cas-computation/2",
 "features":["scoped-values/2","deferred/2","suspend-resume/2","export-capture-frames/2",
             "routine-observations/1"],
 "backend":"diagnostic name","backend_version":"diagnostic version"}
```

The kernel sends `{"op":"hello","protocol":2,"contract":"cas-computation/2"}`.
The SDK acknowledges with the same fields and `"status":"ok"`. Computation
starts after that acknowledgement. Frames use an ASCII decimal UTF-8 byte length,
a newline and the complete JSON payload. Standard output carries frames;
standard error carries diagnostics.

An ordinary invocation has exactly `protocol`, `request_id`, `op`, `input`,
`args` and `scope_id`. Request IDs increase on the connection. The operation and
input are published addresses. Without negotiated routine observations, a successful immediate response has exactly
`request_id`, `status`, `value` and `exports`. `status` is `ok`. An unsupported
operation returns `request_id`, `status:"unsupported"` and the exact `op`.
A handler exception returns `request_id`, `status:"error"`, `kind` and `message`.

### Routine observations

A peer advertising `routine-observations/1` supports the optional hello
field `"routine_observations":true`. The kernel requests that field only
when advertised; the peer echoes it in its acknowledgement. A base hello
omitting the field keeps the original exact response grammar.

With the option acknowledged, each successful immediate, deferred, or
suspended response has one additional field, `routines`: an ordered JSON
array of exact inert observation records:

```json
{"role":"entrypoint","module":"backend.module","qualified_name":"handler",
 "code_sha256":null,"source":null,"documentation":null}
```

The SDK records the actual invoked callable, including the callable used for
an export invocation. Where Python source is present, `source` is an
object with `path`, positive `first_line`, `sha256` of the file observed
during the invocation, and its relevant source `text`. `code_sha256`
fingerprints the callable's actual Python code object when available.
`documentation` is its own docstring, not a guessed link. Missing
source, code or documentation is represented by null.

An implementation can invoke an actual delegated engine routine via
`cas_session.invoke_routine(routine, *args, **kwargs)`. It calls the same
callable with the given arguments and, if observations were negotiated,
records that actual delegated call with role `delegated`. There is no
claimed decomposition of a fused routine. The initial handler invocation
is recorded when it is called; a resumed generator contributes only any
delegated calls performed during that resume, not another fictitious call
to its entrypoint.

These fields supply observation only. They are never mathematical
certificates, declarations, implementations, authority tokens or
instructions. They may not add an operation, input form, owner, or
unpublished role. Errors, unsupported responses and disposal
acknowledgements retain their original exact fields.

## Values and exports

`cas_session.proxy(reference)` retains a public reference received in the active
request. `inputRef(path)` can also name a position in its original argument
packet. The kernel checks that the position is a complete prepared value.
`scopeRef(slot)` names a slot supplied in this request. `resultRef(index)` names
an earlier child result in the same deferred group.

`Proxy.reference()` returns the active reference packet. `Proxy.project(field)`
builds `{"op":"$cas.project","args":{"value":reference,"field":field}}`.
`Proxy.apply(arguments)` builds the corresponding `$cas.apply` call with ordered
`arguments`. These calls are descriptions for the kernel to execute. They
perform no synchronous callback on the provider channel.

`cas_session.export(handler, captures)` stores the actual callable in this
process and returns its `opaqueData` packet. `captures` is the explicit ordered
list of public proxies on which the export depends. The SDK adds the token and
capture references to this response's `exports` array. The kernel retains their
actual roles and owner dependencies.

`$cas.invoke_export` has exactly `protocol`, `request_id`, `op`, `scope_id`,
`token`, `captures` and `context`. The capture array is exactly
`[scopeRef(0), ..., scopeRef(c-1)]` in the export's declared capture order.
The invocation scope starts with those retained reference/role pairs; context
slots follow them. The SDK calls the handler stored at that token. The
handler receives the complete current context:

- `kind:"published"` has `operation`, `input` and `args`. `args` is the complete
  seven-field `apply` packet. Its whole `typedMap` arrow contains this token in
  the callable position.
- `kind:"dependent"` has `prepared_role`, `parameters`, `bindings`, `arguments`,
  `argument_layouts` and `result_layout`. Binding slots are unique and ordered.
  Arguments and argument layouts have the same arity. The kernel checks all
  remaining prepared layout and role associations before dispatch.

Each invocation gateway binds the original declared proxy occurrences to its
fresh capture slots. Repeated and nested invocations have separate binding maps.
Proxy objects hold no mutable current address. The gateway expires on return,
error or suspension, including in a copied Python context. An undeclared retained
proxy has no binding. A suspension explicitly captures every proxy needed after
resume from the current frame, in its new capture order.

## Generator suspension

A generator yields `cas_session.suspend(calls, captures)`. `calls` is a finite
nonempty list. Each member is an ordinary `{op,input,args}` call or a graph
projection/application control. A call can use only earlier `resultRef` indexes.
`captures` declares every proxy occurrence the generator needs after resume.
Repeated capture addresses are rejected; distinct addresses stay distinct.

The SDK stores the generator and writes:

```json
{"request_id":73,"status":"suspended","continuation":"local-token",
 "captures":[{"ctor":"scopeRef","args":[9]}],
 "calls":[{"op":"$cas.project","args":{
   "value":{"ctor":"scopeRef","args":[9]},"field":0}}],"exports":[]}
```

The kernel executes the child calls, then sends a fresh request:

```json
{"protocol":2,"request_id":74,"op":"$cas.resume",
 "continuation":"local-token","scope_id":"fresh-scope",
 "captures":[{"ctor":"scopeRef","args":[0]}],
 "results":[{"ctor":"scopeRef","args":[1]}]}
```

The capture array has the original capture arity. Its entries name slots from
zero in capture order. Results follow those slots in child order and have the
original call arity. The SDK consumes the continuation token, rebinds only its
declared proxy occurrences, and sends the ordered child proxies into the same
generator with Python's `send`. It does not repeat the handler's initial call.
The generator can return JSON data or yield another explicit suspension with a
new token. Access to an undeclared old proxy fails before another call is built.

`deferred_data(calls, result)` remains the complete nonadaptive group form.
Return that packet directly. The kernel executes the group and resolves its
final template at the original prepared result interface.

## Disposal

`$cas.discard` has exactly `protocol`, `request_id`, `op` and
`discard_request_id`. It closes suspended generators and revokes export tokens
introduced by that earlier request. It preserves resources introduced by other
requests. The acknowledgement is
`{"request_id":75,"status":"ok","disposed":true}`. Disposal is idempotent.
A consumed continuation token cannot resume again. Tokens are never reissued
during this process lifetime. Clean EOF closes remaining suspended generators.

