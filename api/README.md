# Declared computational API

`declared-ports.json` is generated documentation of the public declarations in the
`lean-categories` catalogue. It supplies concrete registration addresses and complete
parameterized signatures alongside the generic wire protocol in
[CasContract/Port.lean](../CasContract/Port.lean). It contains no backend implementation,
mathematical definition body, expected answer, or evidence of backend correctness. The kernel
reads the upstream registry directly; it must not read this document to decide meaning.

[`extension-ports.json`](extension-ports.json) publishes the default catalogue together
with the six modules listed in its `provenance.additionalImports`, including finite
orders, two-element subsets, integer square bounds, cyclic quotients and scalar/form
extensions. To reproduce it, use the already built source revisions in its provenance
with the exporter below, repeat `--import` for every listed module, and select a
separate `--output` path. Its recorded revisions identify the producer checkouts;
this publication supplies declaration metadata and admission addresses only.

[Computational wire examples](wire-examples.md) supplies complete request/reply
framing and parameter order, scalar and matrix forms, infinite subsets and
callables, structured projections, lift fields, malformed cases and ownership.
It contains representation examples, not acceptance assertions or expected answers.

The [whole-domain callable section](wire-examples.md#whole-domain-callable-requests)
specifies the existing common invocation with the original source and its identity
argument. The same public envelopes cover admitted `GroupMorphisms` and
`ModuleMorphisms`, selected monoid operations, and a power object's optional
whole direct-image map. These additions introduce declaration rows and metadata;
they do not introduce a private map-evaluation operation or a new wire constructor.
The [terminal-point invocation section](wire-examples.md#terminal-point-operation-requests)
keeps the nullary operation's actual categorical source argument, and the
[complete-input section](wire-examples.md#complete-expression-inputs-and-returned-data-reuse)
specifies symbolic expression inputs and reuse of actual computational answers.
All nested opaque dependencies retain their live session; a formal description
does not replace returned data or turn it into a portable value.

The [complete method request](wire-examples.md#complete-method-requests) uses the
existing construction envelope with the method id, actual chosen receiver, each
residual structural action's complete descriptor and the final method-functor
descriptor. All selected parameters remain present even when the receiver is
opaque. The method's input registration describes its receiver boundary; a
category-wide registration does not discard the envelope or take over unrelated
unexecuted actions. The generic method decoder checks framing without selecting
the mathematics.

[Backend and registration manifests](manifest.md) specifies the complete `leaves.json`
schema, backend command arguments, process environment and input matching rules.

All registered lift rows are retained. A null `computation` and empty `ports` mean
that the row publishes no computational field declaration; they do not remove its
formal lift. The row's `input` spells its derived address; availability is given by
the actual `inputForms` inventory, not by that spelling alone. A published computation contributes its four public projections in
order: `obj`, `hom`, `forward`, `backward`. Each type closes over every parameter
of the original declaration, including the exact source object, base inclusion and
formal instance parameters. The `selection` signature publishes the evidence
family: a request's top-level `parameters` contains all of that declaration's
explicit non-proof data arguments in order, including choices absent from the
underlying action. `sourceCategories` lists the registered categories
whose complete schema is the exact selected edge's declared source, including
explicit nonstructural actions. This metadata does not add resolution edges or
identify categories by carrier equality. Registration uses the exported `operation` and
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

A power object's optional `directImage` declaration is exported with its complete
signature and public documentation through `entries[].declarations`. It supplies
the full map between power objects, while `image` returns the global image subset
of a whole function. The set instance also publishes the ordinary morphism row
`mor.sets.direct_image`, whose registered operation/input address is obtained from
the admission export. No new `powerObjectMap` field spelling is derived from the
optional metadata. Objects with admission or application fields, including the
group and module hom sets, retain those complete signatures in the same entry
records; the actual `#application` addresses are generated by admission.

Operation entries retain their complete owner, surface name, arity and selected
declaration. The surface name alone selects the explicit binding at an owner;
its signature determines the arity and parameters. Inherited lookup stops at
that binding along each structural path. Surviving bindings may agree through
a checked equality of their whole operation families, universally abstracted
over the full source category, selected structures, source object and all
declaration/route parameters before selecting objects or applying operands.
Required endpoint comparisons and original routes remain in that interpretation.
Definitional equality of those complete typed families is discharged by checked
reflexivity; it needs no extra registry row. Otherwise the same full equation
requires an existing accepted comparison, and absence leaves ambiguity.
The [operation-agreement guide](wire-examples.md#agreement-of-inherited-operations)
states the public rule and its limits. Agreement is interpretation-side evidence,
never a leaf proof field or a priority order for computational registrations.
A leaf implements the operation and selected data supplied by the kernel.

`computationDerivations` publishes the upstream catalogue of proved alternatives for
computing an already fixed mathematical family. Each row retains its stable `id`,
exact `target` and ordered `prerequisites`; a reference includes its owner `kind`,
registered `id`, declaration and complete signature. Each reference's `family` and
`familyType` preserve the checked universe application.
The row retains the target's
`universeParameters` and full `targetType`, the `plan` and `correctness` declaration
signatures, the closed `planApplication`, and its whole-family `correctnessType`.
The exporter checks the original upstream derivation before describing it. Proof
bodies and executable plans are not wire fields supplied by a leaf.

Prerequisite order is the plan's argument order. Neither row order nor that argument
order establishes a preferred implementation. These alternatives describe mathematics
independently of installed leaves. Computational support requires a finite grounded
derivation whose primitive calls have applicable implementations; an unsupported or
ungrounded cycle does not remove the mathematical operation. Derivations retain the
same selected parameters and actual intermediate data as ordinary calls. A leaf
continues to register only the existing operation/input/implementation triple and
may implement a primitive without also registering every operation derived from it.

The additive owner `op.additive_monoids.add`, structural functor
`fun.additive_groups.additive_monoid`, and invertible cell
`cell.additive_groups.carrier` use the existing operation, functor and cell
metadata. Their signatures, exact routes and component operation/input address
are exported through the same inventories. The
[additive wire guide](wire-examples.md#additive-operations-and-their-carrier-comparison)
gives their complete parameters and framing without requiring kernel source.

An object's accepted `functorPresentation` retains its selected functor, argument,
route and identification. The `objectField` selectors `presentation` and
`inversePresentation` expose that identification's `hom` and `inv`, respectively,
at the complete ordered object declaration parameters. A named `refines` row
also exposes `refinement` and `inverseRefinement`: the accepted maps from the
complete structural image `U(X(p))` to the registered base `B(p)` and back.
The original semantic object remains `U(X(p))` when `B(p)` supplies its data.
These arrow descriptors add no operation or registration address; the declared
identification owns their endpoints. Retaining a descriptor does not execute
its map or establish a backend law. [Object-field wire forms](wire-examples.md#registered-object-fields)
give the framing and its Python/Lean helpers.
`categories`, `objects` and `functors` retain registered IDs and public declaration
signatures. Categories also retain their complete category expressions and realizations.
`categoryFamilies` publishes each ordered dependent parameter schema, actual realization,
transport declaration and transport semantics. A registered reindexing functor's `cartesian`
metadata names its derived complete callable address and the canonical cartesian-lift action;
the signature retains the actual base morphism. The
[family-action wire section](wire-examples.md#family-reindexing-and-cartesian-arrows) gives
the three-field cartesian-map descriptor and its ordinary application/result framing.
`constructions` also records each direct construction's surface name,
registered target, full dependent declaration, complete-request input, object-action
operation and map-point operation. `objectActionType` and `mapActionType` are the
closed types of that exact functor's object and morphism projections, abstracted over
all declaration parameters. They preserve the complete source domain and chosen
category/functor dictionaries; no per-category specialization is invented.
The [direct-construction wire section](wire-examples.md#direct-constructions)
specifies their object requests, map point requests and selected-parameter descriptors. `datatypes` projects the public inductive constructor signatures reachable
from those types, recursively through constructor types. Constructor `fields` retain
Lean's declared order after datatype parameters and indicate proof slots. They are
type reference metadata, not a generated JSON codec. The existing protocol's
primitive encodings remain authoritative: for example, `Fin` and modular scalar
points do not become constructor-field arrays. Proof slots are absent from wire data.
The `resultType` is the same public signature with only its result type head
normalized to expose aliases.

`cells` publishes each registered natural transformation and its component type,
with exact source/target routes, invertibility, and the derived complete component
operation/input address. Its selected receiver is an actual argument, not an
inferred carrier; inverse orientation is available only when formally registered.

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
`finiteData` and `finiteGraph` inventories, complete Arrow records (including
subobjects and quotients),
`liftInput` requests, direct-construction object and map requests, selected category/functor
dictionaries, complete core comparison data, and `typedMap` replies. The signature fixes the selected
formal types; the protocol fixes their computational encoding. A well-framed wrong
answer remains possible.

Lift requests retain their five ordered fields and additionally publish the full
`sourceImage` interface as actual data or a typed deferred plan. The forward
request may supply `comparisonImage` or obtain it
from the forward reply's complete source endpoint at the fixed `U(O)` interface.
The backward request requires that image. Completed
`liftStep` and factor contexts retain both images. Python `lift_images` reads this
metadata independently of `lift_input`'s unchanged tuple and `lift_parameters`'s
ordered evidence arguments. Packets omitting both image fields use the documented
legacy recipe form; present metadata never becomes proof of an action's result.
See [the lift wire examples](wire-examples.md) for stage ordering and complete
Arrow versus object image data.

The [constrained-point envelope](wire-examples.md#constrained-points) retains the actual
constructor name, original generalized domain, original data-field type, complete selected
target and original point data, in that order. It is limited to an independently checked
fixed closed nonrecursive one-constructor structure with no indices, exactly one data field
and only proposition-valued remaining fields. The actual formal proof remains in the
checked semantic term; it is never a wire field. Original computational data and opaque
ownership pass through unchanged.

The snapshot records the actual mathematical, protocol and kernel Git revisions
and the existing exporter/admission source digests for reproducibility. Exporting
uses the selected, already built source combination without updating or fetching
`main`. These provenance fields do not change dependency policy or certify a
release. An older snapshot is never relabelled as a new export.

The provenance revisions identify the **producer source**: the clean committed
checkouts actually used when the exporters ran. The later commit containing the
generated snapshot is its **publication revision**. In particular,
`protocolRevision` cannot name that later commit, because committing the snapshot
changes the commit identity. Do not rewrite it to claim a self-referential export.

To publish a reproducible reference, commit and build the selected source tuple,
run the exporter, then commit its unchanged output. Consumers may lock the
snapshot's publication revision. A subsequent dependency-lock or generated-file
commit does not retrospectively change the producer tuple; use the recorded
revisions and source digests to reproduce the export, and the published release
revisions to reproduce the final integration build. Additive mathematical
extension snapshots use the same procedure and a separate output path.

The reusable exporter is [tools/export_declared_ports.lean](../tools/export_declared_ports.lean).
It imports only `LeanCategories.Catalogue`, reads the public registry and public
declaration types/docstrings, and writes the path in `CAS_DECLARED_PORTS_OUTPUT`
(default `declared-ports.json`). Run it with `lake env lean` in an environment with
the current upstream catalogue already built. This documentation export does not
run an implementation or acceptance suite.

The companion [tools/export_admission_addresses.lean](../tools/export_admission_addresses.lean)
is a read-only adapter run in the kernel environment, not a contract dependency. It
asks the actual public `form?` and `operation?` lookups for all registered IDs and
all directly derived application, lift, construction, cartesian-map and image addresses.
Its output records which addresses exist, each form's complete `categoryExpression`, and
its registered `category` ID when one exists. A derived category without its own named row
has `category: null`; it retains the full expression rather than inventing a named category.
Constructor-induced component addresses form an unbounded family over finite constructor
paths, so they are specified by the public
[component-address grammar](wire-examples.md#constructor-induced-components) and the exported
`cells` and `cellConstructors`, rather than enumerated in the finite address arrays.
The adapter does not run
implementations, rank capabilities, choose routes or certify answers.
Before publishing the snapshot, the Python exporter checks every concrete port
published for lifts, constructions, cells and cartesian maps against those actual
admission inventories. A missing operation, missing input form or lost category
context rejects the export and preserves the previous snapshot.

Regenerate the single reference with `just export-api /absolute/path/to/lean-cas-dsl`
when that checkout's manifest and default package directories identify the built
sources. For an explicitly selected source combination or toolchain, invoke the
same exporter directly:

```sh
python3 tools/export_api.py /absolute/path/to/lean-cas-dsl \
  --mathematics /absolute/path/to/lean-categories \
  --packages /absolute/path/to/lake-packages.json \
  --lake /absolute/path/to/toolchain/bin/lake \
  --lean /absolute/path/to/toolchain/bin/lean
```

`--packages` accepts Lake's package override JSON (a `version` and `packages`
array); use `type: "path"` entries with existing directories for locally selected
sources. Relative package paths have Lake's usual kernel-directory base.
`--mathematics` checks that the selected `lean_categories` directory is the stated
checkout, preventing unrelated source from being used as provenance. The selected
`cas_leaf_contracts` package must have the same commit as this exporter checkout.
The executable options are optional; their defaults are `lake` and `lean`.

For an additive mathematical extension, repeat `--import Fully.Qualified.Module`
for its already built public catalogue modules. Both declaration and admission
exports import the same modules. Use `--output /absolute/path/to/extension-api.json`
to write a separate catalogue without changing this contract snapshot or either
exporter source. The mathematical checkout must contain those committed modules,
and the selected build must include them. The resulting provenance records the
module list and both generated probe digests as well as the ordinary source
revisions. New metadata does not add wire encodings or change the protocol.

Before exporting, commit the source combination and build `CasCatalogue.Admission`
and its dependencies with that same package selection and toolchain. The exporter
requires clean source checkouts (the generated `api/declared-ports.json` is exempt),
a kernel manifest, and all selected dependencies already present. A default Git
package must already match its manifest revision; a different local selection needs
a path override. The exporter does not build or check freshness of compiled
artifacts, so rebuilding after any source change is a prerequisite.

Both existing Lean exporters run through `lake env lean`, using temporary path
entries for the selected directories so Lake cannot fetch or switch Git packages.
The wrapper checks revisions, clean sources and input digests before publishing,
and replaces the snapshot only after both fresh exports succeed with unchanged
sources and configuration. A failed export leaves the previous snapshot intact.

The declaration export loads Lean's server-data section (`-DElab.inServer=true`)
so imported public declaration docstrings are included. Ordinary batch module
imports omit that metadata; a null field must not silently stand in for the
published description of a selected presentation. This does not change module
visibility or the mathematical declarations selected for export.
