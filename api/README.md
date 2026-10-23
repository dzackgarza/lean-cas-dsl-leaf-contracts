# Declared computational API

`declared-ports.json` is generated documentation of the public declarations in the
`lean-categories` catalogue. It supplies concrete registration addresses and complete
parameterized signatures alongside the generic wire protocol in
[CasContract/Port.lean](../CasContract/Port.lean). It contains no implementation,
mathematical definition body, expected answer, or correctness evidence. The kernel
reads the upstream registry directly; it must not read this document to decide meaning.

[Computational wire examples](wire-examples.md) supplies complete request/reply
framing and parameter order, scalar and matrix forms, infinite subsets and
callables, structured projections, lift fields, malformed cases and ownership.
It contains representation examples, not acceptance assertions or expected answers.

[Backend and registration manifests](manifest.md) specifies the complete `leaves.json`
schema, backend command arguments, process environment and input matching rules.

All registered lift rows are retained. A null `computation` and empty `ports` mean
that the row publishes no computational field declaration; they do not remove its
formal lift. The row's `input` spells its derived address; availability is given by
the actual `inputForms` inventory, not by that spelling alone. A published computation contributes its four public projections in
order: `obj`, `hom`, `forward`, `backward`. Each type closes over every parameter
of the original declaration, including the exact source object, base inclusion and
formal instance parameters. `sourceCategories` lists the registered categories
whose structural edges contain the exact selected edge; it does not identify
categories by carrier equality. Registration uses the exported `operation` and
`input` addresses, not the Lean declaration name.

`entries` includes every registered row, its public registration metadata and the
signatures/docstrings of all declarations it names. This includes methods and
properties (which reference registered functors/classifiers), named morphisms,
binders, literals, graph/subset forms, element operations and limits/colimits.
For a limit row, `standardization` names the checked comparison from a supplied
diagram to its declared presentation and `dataConstructor` names the complete
dependent constructor whose non-propositional fields are the ordered result
ports. Both signatures are exported when present. No shape name selects a
different hidden constructor or comparison. An object's `components` publishes
its finite arity and indexed projection signatures; these retain the exact
object parameters when a map argument is destructured. A power object's `point`
publishes the chosen point of the terminal source of `truth`. Global points use
that declaration; a leaf copies the request's domain descriptor without assuming
that the terminal source has a particular numeral or representation.
`categories`, `objects` and `functors` retain registered IDs and public declaration
signatures. `datatypes` projects the public inductive constructor signatures reachable
from those types, recursively through constructor types. Constructor `fields` retain
Lean's declared order after datatype parameters and indicate proof slots. They are
type reference metadata, not a generated JSON codec. The existing protocol's
primitive encodings remain authoritative: for example, `Fin` and modular scalar
points do not become constructor-field arrays. Proof slots are absent from wire data.
The `resultType` is the same public signature with only its result type head
normalized to expose aliases.

`typeAliases` additionally covers public Type-valued declarations occurring in the
reference. The exporter applies each declaration to its complete generic parameters
and normalizes that type expression, closes it over those parameters, and follows
its referenced datatype constructors. This exposes existing public types hidden by
aliases without evaluating operational computations or proof propositions. An
opaque or unreduced type has `representation: "abstract"` and a null
`normalizedType`; no constructors are guessed. These fields are type reference
metadata, not additional wire encodings. No operational declaration value,
constructor body or proof is exported, reconstructed or certified.

Wire shapes are fixed by `CasContract/Port.lean`: named objects and ordered
parameters, constructor data slots, callable graphs or owned opaque callables,
`finiteData` and `finiteGraph` inventories, complete Arrow/subobject values,
`liftInput` requests and `typedMap` replies. The signature fixes the selected
formal types; the protocol fixes their computational encoding. A well-framed wrong
answer remains possible.

The snapshot records exact mathematical and protocol source revisions and the
exporter digest for reproducibility. They are not dependency pins or accepted
releases: every invocation consumes current own-organisation `main` first and
regenerates the documentation from that resolved input. An older snapshot is not
silently relabelled as current.

The reusable exporter is [tools/export_declared_ports.lean](../tools/export_declared_ports.lean).
It imports only `LeanCategories.Catalogue`, reads the public registry and public
declaration types/docstrings, and writes the path in `CAS_DECLARED_PORTS_OUTPUT`
(default `declared-ports.json`). Run it with `lake env lean` in an environment with
the current upstream catalogue already built. This documentation export does not
run an implementation or acceptance suite.

The companion [tools/export_admission_addresses.lean](../tools/export_admission_addresses.lean)
is a read-only adapter run in the kernel environment, not a contract dependency. It
asks the actual public `form?` and `operation?` lookups for all registered IDs and
all structurally derived application, lift and image addresses. Its output records
which addresses exist and their full registered category IDs. It does not run
implementations, rank capabilities, choose routes or certify answers.

Regenerate the single reference with `just export-api /absolute/path/to/lean-cas-dsl`.
This uses that checkout's existing latest-main `just probe` surface for both
exporters, records the resolved revisions and source digests, and writes the
snapshot only after both exports succeed against the same mathematical revision.
The supplied kernel checkout must have its corresponding current dependencies built.
