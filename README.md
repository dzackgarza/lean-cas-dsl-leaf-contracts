# The typed leaf contract of cas-dsl

This repository owns the published, language-neutral computational interface
between the [cas-dsl Lean kernel](https://github.com/dzackgarza/cas-dsl) and
independent category implementations. The [constitution](.specify/memory/constitution.md)
and the [kernel constitution](https://github.com/dzackgarza/cas-dsl/blob/main/.specify/memory/constitution.md)
govern this architecture.

A leaf implements a category or parameterized category family. An operation
registration is a computational port of that interface. One backend executable
can implement several categories. The contract does not define mathematics.

| Owner | Responsibility |
| --- | --- |
| lean-categories | Mathematical declarations and complete typed obligations |
| cas-dsl | One generic Lean kernel, exact selection, public session and independent acceptance |
| This repository | Manifest, invocation/data protocol, failures, lifetime, generated interfaces and typed bindings |
| lean-cas-dsl-leaves | Computational implementations of category interfaces |

The purpose of this interface is to make existing CAS implementations easy
to register and compose. Publish each category's actual signatures and
registration addresses, and provide reusable bindings that handle argument
and result codecs, native-value handles, dispatch and lifecycle. A leaf
author imports an existing engine, binds its native operations to the
declared ports and registers the category version. Use the natural language
of each engine, with the typed public protocol in common.

Establish and freeze this interface with the first real category
implementation, using actual checked Lean runtime calls. Develop category
versions and the common kernel together. For Sage, reuse the existing
Python binding and the native set and cardinality calls. The binding
supplies protocol machinery; the leaf supplies the engine-specific wiring.

The [declared API](api/README.md) and [manifest reference](api/manifest.md)
document the published interfaces. Lean module roots are `CasContract.*`
(namespaces `CasCatalogue`). The existing Python reference binding is
`python/cas_port.py`; its existence does not prescribe a language for new
bindings or leaves.

Contract conformance checks complete invocation and result data, including
dependent fields and actual handles. It does not establish correctness of a
computed answer. The kernel interprets mathematics independently of engines.
A leaf author uses the accepted mathematical interface and released contract,
not kernel source or protected acceptance tests.

Use the compatible shared research toolchain. A release identifies its actual
locked dependencies and generated interfaces; a consumer pins the published
compatible revision. New category versions use the same contract. Tests of the
real codecs and connections are contract evidence, not mathematical delivery.
