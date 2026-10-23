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
can `import cas_port`. Ordinary process environment variables remain available.
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
instruction to replace that value with a familiar object. A callable or lift may
also have its own exported complete-request input address.

An operation's presence in `operations` does not put that same string in
`inputForms`. For example, `op.rings.pow` can use an admitted named ring form or
`cat.rings`; its operation id is not itself a declared input form. Binder and
object-application fields have the complete-request forms explicitly listed in
`inputForms`. Always choose both addresses from their respective inventories.

Exact-form and category-wide registrations have equal standing. If both are
applicable to one invocation, that invocation is ambiguous; manifest order and
backend name do not define priority. Avoid overlapping registrations unless an
explicit backend selection is part of the caller's independently provided run
configuration. Do not infer a dispatch rule from the `ready` announcement.
