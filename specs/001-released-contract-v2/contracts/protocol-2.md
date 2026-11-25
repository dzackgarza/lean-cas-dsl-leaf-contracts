# Contract: `cas-computation/2` frames

This is the design that tasks T003–T013 bring into `api/python-sdk.md`, `api/kernel-service.md`
and `CasContract/Port.lean`. Each frame has exactly the listed fields; any other field is
malformed. The kernel's [runtime contract][KR] governs.

| Frame | Direction | Fields | Requirement |
| --- | --- | --- | --- |
| ready | leaf → kernel | `op:"ready"`, `protocol:2`, `contract:"cas-computation/2"`, `features`, `backend`, `backend_version` | FR-002 |
| hello | kernel → leaf | `op:"hello"`, `protocol`, `contract`; `routine_observations:true` only when advertised | FR-002, FR-013 |
| hello ack | leaf → kernel | the hello fields and `status:"ok"` | FR-002 |
| request | kernel → leaf | `protocol`, `request_id`, `op`, `input`, `args`, `scope_id` | FR-003 |
| invoke export | kernel → leaf | `protocol`, `request_id`, `op:"$cas.invoke_export"`, `scope_id`, `token`, `captures`, `context` | FR-007 |
| resume | kernel → leaf | `protocol`, `request_id`, `op:"$cas.resume"`, `continuation`, `scope_id`, `captures`, `results` | FR-010 |
| discard | kernel → leaf | `protocol`, `request_id`, `op:"$cas.discard"`, `discard_request_id` | FR-008 |
| ok | leaf → kernel | `request_id`, `status:"ok"`, `value`, `exports` (+ `routines`) | FR-006 |
| suspended | leaf → kernel | `request_id`, `status:"suspended"`, `continuation`, `captures`, `calls`, `exports` (+ `routines`) | FR-010 |
| unknown | leaf → kernel | `request_id`, `status:"unknown"`, `op`, `reason` | FR-012 |
| unsupported | leaf → kernel | `request_id`, `status:"unsupported"`, `op` | FR-011 |
| error | leaf → kernel | `request_id`, `status:"error"`, `kind`, `message` | FR-011 |
| disposed | leaf → kernel | `request_id`, `status:"ok"`, `disposed:true` | FR-008 |

## Value constructors

| Constructor | Written by | Meaning |
| --- | --- | --- |
| `inputRef(path)` | leaf | Position in the original request |
| `resultRef(index)` | leaf | Earlier node of the same deferred group |
| `scopeRef(slot)` | kernel and leaf | Slot of the current scope |
| `opaqueData(token)` | leaf | Provider-local exported value |
| `deferredData(calls, template)` | leaf | Deferred program as an `ok` value |
| `noImplementation(op, input)` | kernel only | Resume slot of a child with no realization |

## Resume slots

For $c$ captures and $n$ children, `captures` is `scopeRef(0)`…`scopeRef(c-1)` and `results[j]`
is `scopeRef(c+j)` or `noImplementation(op_j, input_j)`.

[KR]: https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/001-categorical-research-language/contracts/computational-runtime.md
