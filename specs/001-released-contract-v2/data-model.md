# Data Model: Released contract, protocol 2

Wire grammar is in [contracts/protocol-2.md](contracts/protocol-2.md). This file states the
entities, their fields, their validation and their states.

## Manifest (`leaves.json`)

| Entity | Fields (all required) | Validation |
| --- | --- | --- |
| Manifest | `backends`, `registrations` | No other field |
| Backend | `name`, `command`, `args` | `name` unique; `args` strings |
| Registration | `operation`, `input`, `backend`, `preferredRoutes` | Addresses admitted by the catalogue; `backend` declared |
| Preferred route | `name`, `receiver`, `route` | `route` nonempty; a surviving route of `name` on `receiver` |

## Generated category interface (`api/declared-ports.json`, key `categoryInterfaces`)

Field names are those of `categoryInterfaceVersion: 1` (research R8). Each entry MUST hold the
content below.

| Content | Meaning |
| --- | --- |
| Identity | Typed `(kind, id)` of the category or derived expression |
| Object constructors | Object constructors with complete dependent signatures |
| Morphism constructors | Morphism constructors with endpoints |
| Operations | Operations at their actual domains, with input forms and result layouts |
| Functor actions | Immediate functor object and morphism actions, each with `structural` |
| Dependencies | Parameters, permitted choices, selected structures, comparisons, callable and lazy fields, subsequent uses |

`categoryConstructors` (constructors of categories) and `genericEntries` (families with no fixed
owner) are separate keys.

## Session entities (SDK)

| Entity | Fields | Lifetime |
| --- | --- | --- |
| Proxy | one public reference packet | One gateway frame |
| Gateway frame | request ID, scope ID, capture map | Expires on return, error or suspension |
| Export | token, handler, ordered captures | Until `$cas.discard` of its request or EOF |
| Continuation | token, generator, ordered captures | One resume |
| NoImplementation | `operation`, `input` | Value sent to a generator |
| Unknown | `reason` | Raised by a predicate handler |

## Continuation states

`suspended → resume_reserved → resuming → retired` (runtime contract §6). A retired token is
never reissued in its process.

## Strata

`invalid`, `semanticAmbiguity`, `noImplementation`, `ambiguousRealization`, `unavailable`,
`malformed`, `internal`.

## Test records

| Record | Fields | Location |
| --- | --- | --- |
| Run log | every frame and SDK log line of the run | `tests/logs/<timestamp>-<rev>.log` |
| Timing record | `run`, `revision`, `environment`, `input`, `setup_s`, `call_s`, `teardown_s` | `tests/timing/records.jsonl` |
