# Contract: `cas-computation/2` frames

This file indexes the frames and the value constructors that tasks T003–T013 bring into
`api/python-sdk.md`, `api/kernel-service.md` and `CasContract/Port.lean`. The requirement in the
last column states the exact fields of each frame and each rule; a field that it does not list is
malformed (constitution RC8). The kernel's [runtime contract][KR] governs.

| Frame | Direction | Requirement |
| --- | --- | --- |
| ready | leaf → kernel | FR-002 |
| hello | kernel → leaf | FR-002, FR-013 |
| hello ack | leaf → kernel | FR-002 |
| request | kernel → leaf | FR-003 |
| invoke export | kernel → leaf | FR-007 |
| resume | kernel → leaf | FR-010 |
| discard | kernel → leaf | FR-008 |
| ok | leaf → kernel | FR-006, FR-013 |
| suspended | leaf → kernel | FR-010, FR-013 |
| unsupported | leaf → kernel | FR-011 |
| error | leaf → kernel | FR-011 |
| disposed | leaf → kernel | FR-008 |

## Value constructors

| Constructor | Written by | Requirement |
| --- | --- | --- |
| `inputRef(path)` | leaf | FR-005 |
| `resultRef(index)` | leaf | FR-005 |
| `scopeRef(slot)` | kernel and leaf | FR-005, FR-010 |
| `opaqueData(token)` | leaf | FR-006, FR-007 |
| `deferredData(calls, template)` | leaf | FR-009 |
| `noImplementation(op, input)` | kernel only | FR-010 |
| `some(true)`, `some(false)`, `none` | leaf | FR-012 |
| value forms of issue #14 | leaf and kernel | FR-025 |

[KR]: https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/001-categorical-research-language/contracts/computational-runtime.md
