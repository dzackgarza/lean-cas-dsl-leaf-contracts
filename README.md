# The leaf contract of lean-cas-dsl

The [kernel constitution](https://github.com/dzackgarza/lean-cas-dsl/blob/main/.specify/memory/constitution.md)
and its [mathematical execution model](https://github.com/dzackgarza/lean-cas-dsl/blob/main/specs/architecture.md)
own the separation of concerns and the design of leaves. This repository is one part of the `lean-cas-dsl` kernel: the interface a
computational leaf is written against, published on its own so that a leaf depends on nothing else
of the kernel.

| Package | Depends on | Owns |
| --- | --- | --- |
| `lean-categories` | Mathlib | all mathematics, including the semantic registry (the catalogue) |
| `lean-cas-dsl-leaf-contracts` (this) | `lean-categories` | the shape of a leaf's manifest (`CasContract.Registration`), the backend port protocol (`CasContract.Port`), and the failure strata (`CasContract.Failure`) |
| `lean-cas-dsl-leaves` | nothing | a manifest `leaves.json` of registrations, and the programs it names; no Lean |
| `lean-cas-dsl` | `lean-categories`, this | the kernel's resolution and reading of statements, the language, the acceptance suite, the harness |

* **A leaf is data.** A leaf is `leaves.json` at the root of its package: the backend programs it
  runs, and for each registration the catalogue operation it computes, the input form it accepts
  and the backend that computes it. The optional `preferredRoutes` selects surviving
  source bindings under C6; it asserts no equality or mathematical law. The kernel
  admits each registration and preference against the catalogue, or reports why it does not.
* **Implement the prescribed category interface.** The generated category view and
  `cas_port.load_interfaces` expose object and morphism constructor families,
  operations at their declared domains, immediate functor actions, and complete
  dependent signatures. Category constructors are separate. A provider may reuse
  its private engine objects, algorithms and control flow while supplying every
  selected parameter, field, comparison and callable required by that interface.
  Public calls use the released protocol and retain their actual owners; another
  provider's private representation is never a required input.
* **Registration and answers are computational claims and data.** The kernel checks a leaf's
  declaration against the published contract and may invoke it. It consumes outputs for subsequent
  computations and acceptance observations, never as authority for mathematical definitions,
  laws, semantic placement or acceptance truth. Contract conformance does not certify correctness.
  Required structure may be supplied as data or callable operations suitable for the object;
  completeness does not require enumerating infinite objects or functions. The abstract obligation
  model belongs upstream; this package owns concrete invocation and representation protocols.
* **The contract is the type at the firewall.** It fixes the type a leaf's computation must meet
  and nothing else. On the leaf side anything goes that meets it. Only answers cross, and an answer
  is checked against the formal side, the permanent acceptance suite of `lean-cas-dsl`, never
  believed.
  Structured answers retain all declared computational fields, including defining maps.
  They do not become proved identifications with the formal construction: its identity,
  structure and operations remain independently authoritative. Runtime does not require a
  proof that a backend returned the correct universal object; well-formed wrong answers are
  judged by acceptance.
* **Kernel-owned.** Changes here are kernel changes: made with `lean-cas-dsl` and merged to
  `main`, which `lean-cas-dsl` tracks. A leaf never changes this contract to fit itself.
* **No mathematics.** Which operations and forms exist, and what they denote, is `lean-categories`'
  catalogue. This package reads it and declares none.
* **Tests of the contract, not of answers.** The tests here check this repository's product, the
  codecs and the SDK, with a real leaf process against a real protocol peer (constitution RC12,
  RC13). The permanent acceptance suite is `lean-cas-dsl`'s. Nothing here, and so nothing a leaf
  can reach, contains or names it.

The [declared API reference](api/README.md) publishes the complete registered declaration
signatures, computational port addresses and generic wire-shape references.
The [manifest reference](api/manifest.md) specifies every backend command and registration
field, defaults, process paths and matching behavior.

Module roots: `CasContract.*` (namespaces `CasCatalogue`, shared with the kernel). The Python
reference implementation of the port protocol is `python/cas_port.py`; the kernel puts it on every
program's `PYTHONPATH`. The [Python SDK](api/python-sdk.md) specifies native v2
startup, exports, scoped proxies and captured generator suspension. Its runtime
dependencies are declared in `pyproject.toml` and locked in `uv.lock`.

Every `require` tracks `main`. `just test-ci` builds on Mathlib's prebuilt cache and runs the
kernel-axiom audit of this repository's own code (`AxiomAudit.lean`); the commit and push tiers
compile nothing.

The committed Lake manifest records the exact dependency revisions used by this
source candidate. Use that lock when reproducing its build; `lake update` selects
new dependency revisions and is a new integration. The declaration snapshot
records the committed sources that produced it, separately from the later commit
publishing that snapshot; see [API provenance](api/README.md).
