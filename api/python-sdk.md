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

An ordinary handler can call `cas_session.request_input()` for its exact input
address. Native-export handlers receive that address in their published context.
`cas_session.ComputationError(kind, message)` preserves an external computation's
error fields. `cas_session.UnsupportedOperation(operation)` reports the consumed
operation as unsupported. Both failure paths revoke that request's new leases.

`cas_port.read_frame(source)` and `write_frame(value, target)` also accept binary
streams. Their default streams are standard input and standard output.
The [explicit v1 bridge](v1-bridge.md) uses the same framing and SDK lease rules.

## Connection

The process writes this frame before it reads an invocation:

```json
{"op":"ready","protocol":2,"contract":"cas-computation/2",
 "features":["scoped-values/2","deferred/2","suspend-resume/2","export-capture-frames/2"],
 "backend":"diagnostic name","backend_version":"diagnostic version"}
```

The kernel sends `{"op":"hello","protocol":2,"contract":"cas-computation/2"}`.
The SDK acknowledges with the same fields and `"status":"ok"`. Computation
starts after that acknowledgement. Frames use an ASCII decimal UTF-8 byte length,
a newline and the complete JSON payload. Standard output carries frames;
standard error carries diagnostics.

An ordinary invocation has exactly `protocol`, `request_id`, `op`, `input`,
`args` and `scope_id`. Request IDs increase on the connection. The operation and
input are published addresses. A successful immediate response has exactly
`request_id`, `status`, `value` and `exports`. `status` is `ok`. An unsupported
operation returns `request_id`, `status:"unsupported"` and the exact `op`.
A handler exception returns `request_id`, `status:"error"`, `kind` and `message`.

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
