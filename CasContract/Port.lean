/-
Copyright (c) 2026 Dzack Garza. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import CasContract.Failure
public import Lean.Data.Json

@[expose] public section

/-!
# The backend port (`specs/leaf-registration.md`, "A registration is data")

The kernel owns this protocol; a leaf owns the program behind its port, in whatever language its
engine needs. Only data crosses it: the kernel's encoding of an input goes out, and JSON comes
back, which the kernel decodes in the operation's declared result form or rejects. No Lean crosses
it in either direction.

A backend is a child process speaking length-prefixed JSON frames (the ASCII decimal byte length,
a newline, the UTF-8 payload; a Python reference implementation is this package's
`python/cas_port.py`, on the `PYTHONPATH` of every program the kernel starts). It first announces
itself (`{op: "ready", backend, backend_version, capabilities}`; nothing in the announcement is
believed or consulted), then answers requests `{request_id, op, args}` with
`{request_id, status, value}`, where `op` is a registration's operation id and `args` the encoded
input. Which operations are called on it is the admitted registrations' (`CasCatalogue.Admission`).

`status: "ok"` carries `value`. `status: "error"` carries string `kind` and `message`
and reports an unavailable computation. `status: "unsupported"` carries the exact dispatched
`op` and reports `noImplementation`. Unknown statuses and mismatched request identities are
malformed. The frame length contains only nonempty ASCII decimal digits. Request data such as
zero, false and an empty array are preserved verbatim. Complete worked request/reply forms and
malformed examples are published in `api/wire-examples.md`.
Loss of the connection before a complete reply, including an interrupted frame or a broken
request pipe, is unavailable. A complete invalid frame or reply remains malformed.

## Kernel-mediated computations requested by a leaf

A handler may return a successful reply whose value is
`{"ctor":"deferredData","args":[[<calls in dependency order>],<result template>]}`.
Each call is exactly `{"op":<published operation address>,"input":<published input form>,
"args":<that operation's existing complete request template>}`. A template can contain
`{"ctor":"resultRef","args":[<zero-based earlier call index>]}` in a typed data slot.
Call arguments may refer only to prior calls; the final template may refer to any call in
that program. The kernel resolves each reference to the actual typed result and retained
dependencies, checks its exact role, parameters and endpoints, and dispatches through the
ordinary published interface. It derives the result interface from the registered declaration
and selected request. Neither `op` nor `input` selects a backend or supplies result-type authority.

These are computational control forms, interpreted only within a service reply. They are not
mathematical constructors and do not reach a target consumer as recipes. A called implementation
may itself return a deferred reply; the same shared service interprets it in its own reference
scope before completing that node. A literal nested `deferredData` in a template is malformed.
Only ordinary published data constructors and scoped `resultRef` occur in templates.

The service permits published constructors and operations across the existing operation families,
not merely replay of the current functor action. Every family retains its existing full request
and result contract, including complete diagrams, callable endpoints, selected actions, evidence
parameters and structured defining maps where required. The public guide lists these families.
An object/category/data-constructor descriptor is an input or result form; it is not an executable
operation address unless the published interface gives it one. A missing required generic
declaration-to-request implementation remains kernel work; this grammar does not establish that
such coverage is complete.

Each node result retains its actual supplier and all nested computational dependencies. A final
result from another backend is not restamped as owned by the leaf that returned the program.
References preserve separate owners; resolving a template does not flatten or erase mixed opaque
dependencies. The kernel must arrange an admitted computation or representation bridge before
such dependencies can be consumed together. Portable data remain portable. New opaque literals
supplied by the returning leaf retain that leaf's live session; no field in a program chooses an
owner. A missing implementation or bridge is a computational gap, an unavailable owner remains
unavailable, and malformed control/type/parameter/endpoint framing is rejected. A well-framed
wrong result remains computational data; it neither changes the original formal question nor
establishes equality to the requested object or correctness of its construction.

A leaf may implement a published functor by requesting existing constructors of its target and
retaining the corresponding maps and selected comparisons. The kernel owns their interpretation
and composition. Native adaptations and optional imports of other implementations are permitted;
they have no semantic standing and do not replace a missing generic kernel service. Source
isolation is a diagnostic choice, not a restriction on leaf internals.

## The wire encoding of inputs and answers

The kernel's codec (`CasCatalogue.Codec`) fixes one structural encoding, derived from each form's
inductive type; a leaf reads and writes exactly this, and nothing else:

* a named input object of the catalogue is sent at its parameters,
  `{"ctor": <object id>, "args": [<parameters>]}`; a parameter that is itself a named object is
  encoded the same way;
* a natural number or an integer is a JSON number; a list is a JSON array; a `Multiset` or a
  `Finset` is a list of its elements;
* a record (one constructor, no indices: a pair, a point of `Fin n`, a subtype) is the JSON array
  of its data fields, or that field alone when it has exactly one (a point of `Fin n` is its
  number, a pair is `[x, y]`);
  a wholly inline scalar literal must also satisfy its declared representation constraints.
  In particular a rational is `[<integer numerator>,<natural denominator>]`, with a strictly
  positive denominator and relatively prime numerator and denominator; zero uses `[0,1]`.
  A zero denominator or a nonreduced pair is malformed representation. These literal checks
  discard the checked value and do not certify the answer to the requested computation.
  Records containing callable, type-valued or opaque fields retain their data-only interface;
  no law-bearing structured output is reconstructed through this scalar rule;
* a finite callable may be a graph, a list of pairs `[x, f x]`, including every
  point of its actual computational domain exactly once. A primitive finite
  codec may supply this inventory from its declared data parameters. Otherwise
  `{"ctor":"finiteGraph","args":[<actual domain point inventory>,<graph>]}`
  supplies the inventory explicitly. Inventory points have the declared public
  point-data shape, are distinct, and are untrusted computational data; their
  inclusion does not prove that the carrier is the mathematical one requested.
  The graph must contain exactly those keys once, with outputs in its declared
  codomain representation where an actual codomain inventory is supplied.
  An infinite callable uses its owning opaque-session representation.
  This encoding recurses through all public constructor data fields, including
  both function fields of an equivalence. Direct literal decoding establishes
  its declared constraints; structured computational answers instead frame all
  data slots without reconstructing mathematical values, laws or proof fields.
  Function encoding preserves the complete independently selected public types.
* the set of members of a subset, where a set is expected, is
  `{"ctor":"extent","args":[<power object id>,<ambient set descriptor>,<subset data>]}`; for a
  finite-subset literal the subset data is the literal's list of elements, so `{1, 2, 3} ⊆ ℕ`
  as a set is `{"ctor":"extent","args":["pow.sets",{"ctor":"obj.sets.naturals","args":[]},[1,2,3]]}`;
* the apex of a limit the kernel has already had computed is
  `{"ctor":"constructionApex","args":[<limit id>,<diagram>,<the computed cone>]}`, the diagram in
  the encoding above and the cone as the backend returned it; it may be used wherever an object
  descriptor is required;
* `{"ctor":"finiteData","args":[<complete object descriptor>,<actual point inventory>]}`
  retains an object's complete descriptor and supplies its finite computational
  carrier inventory. It may be used wherever an actual object descriptor is
  required, including either endpoint of a `typedMap`. For a finite graph at a
  symbolic apex, a domain inventory is required; the kernel never enumerates the
  authoritative requested construction's carrier to replace or certify an answer.
  The inventory's mathematical correctness remains an independent acceptance
  question. Opaque objects and callables retain their owning live sessions.

* any other constructor application is `{"ctor": <constructor>, "args": [<data fields>]}`, the
  constructor spelled by its short name within its type (`finite`, `aleph0`, `some`, `true`);
* a proof field is never on the wire;
* a morphism of a concrete category is its graph, a list of pairs `[x, f x]` of points;
  a registered named morphism may instead be encoded as
  `{"ctor": <morphism id>, "args": [<explicit parameters>]}`. Its declaration fixes the
  parameter types and endpoints; this permits named arrows on infinite carriers without
  enumerating a graph. The kernel checks the instantiated endpoints against the requested arrow;
* a registered inclusion uses `{"ctor": <inclusion id>, "args": [<explicit parameters>]}`.
  Its public declaration fixes its complete source, target and dependent parameter order.
  The id does not assert a carrier identification or omit the actual inclusion map;
* a released callable operation uses the same declaration-application form
  `{"ctor": <callable address>, "args": [<all explicit declaration parameters>]}`.
  This includes an element-operation id, a binder id, and `<object id>#application`.
  It denotes the arrow before application: operands belong in the common `apply` request's
  argument field, never in this arrow descriptor. For example, `op.rings.pow` has the selected
  ring and natural exponent as its ordered parameters. `operationExpression` additionally
  supplies operands and therefore describes an element expression instead of this arrow;
* a map a registered object row declares as a field, its admission `inclusion` `D ↪ B`
  (`Mˣ ↪ M`), its `constants` `R → R[[t]]`, or either direction of its accepted
  `functorPresentation` or named `refines` comparison, is
  `{"ctor":"objectField","args":[<object id>,<field>,[<explicit parameters>]]}`; its endpoints are
  the ones the field's declaration gives at those parameters. The field `presentation`
  selects `functorPresentation.identification.hom`; `inversePresentation` selects its `inv`.
  The fields `refinement` and `inverseRefinement` select `refines.identification.hom` and
  `refines.identification.inv`, respectively. If the named object is `X(p)`, its accepted
  refinement route is `U`, and its registered base is `B(p)`, these maps have directions
  `U(X(p)) → B(p)` and `B(p) → U(X(p))` in the route's target category.
  Each identification is instantiated at the object's complete ordered declaration parameters,
  retaining the registered functor, selected argument and structural route. These descriptors
  retain the selected callable; forming one does not execute it or establish a backend law.
  The semantic object remains `U(X(p))` when a computation uses the representation `B(p)`;
* the mediator `⟨f, g⟩ : X → A × B` of two maps out of a domain other than `1` is
  `{"ctor":"mediator","args":[<f>,<g>]}`, each map in its morphism encoding; a mediator of two
  closed points may retain those two complete point arrows in the same mediator descriptor.
  When only its point value is required by an application, the ordered point data are `[x, y]`;
* a map of a registered power object (`pow.sets`) named by its field: `member` (`X × 𝒫 X → Ω`),
  `terminal` (`X → 1`), `transpose` (the subset `1 → 𝒫 X` a predicate `X → Ω` classifies, the
  predicate given as its map encoding), `image` (the subset `1 → 𝒫 Y` that is the image of a
  map `X → Y`, the map given as its encoding), or `truth` (`1 → Ω`), is
  `{"ctor":"powerObjectMap","args":[<power object id>,<field>,[<explicit parameters>]]}`;
* the action of a registered functor on an arrow may be represented as
  `{"ctor":"map","args":[{"ctor":<functor id>,"args":[<explicit parameters>]},<arrow>]}`.
  Structural classifier-forget edges use
  `{"ctor":"classifierForget","args":[<registered classifier id>,
  [<ordered actual classifier declaration arguments>]]}`; a registered
  constructor's derived action uses
  `{"ctor":"constructorMap","args":[<registered constructor id>,<inner edge descriptor>]}`.
  These descriptors name the actual registered edge; they do not invent a functor row.
  The arrow uses its source-category encoding. The registered functor and its exact parameters
  determine the resulting arrow and endpoints. Composition is
  `{"ctor":"compose","args":[<first arrow>,<second arrow>]}` in categorical order
  (first, then second); both arrows are checked at their shared endpoint. Accepted presentation
  changes retain their actual comparison arrows in this composition, never an endpoint rename;
* a diagram, the input of a registered limit or colimit, is registered on the form of its
  category (`"input": "cat.sets"`) and sent using its registered diagram constructor with
  the complete ordered explicit arguments. For the corresponding declared constructors these
  are `{"ctor": "pair", "args": [X, Y]}` or `{"ctor": "cospan", "args": [f, g]}`,
  objects and arrows in their own encodings. The registered declaration supplies the
  constructor; a shape label does not select a hardcoded Mathlib construction.
  A retained parallel-arrow diagram is `{"ctor":"parallelPair","args":[f,g]}`.
  Its cone or cocone has one defining arrow, so the reply is respectively
  `{"ctor":"cone","args":[<apex>,<inclusion>]}` or
  `{"ctor":"cocone","args":[<apex>,<projection>]}`. The two arrows in the request
  are retained exactly, including a registered trivial or zero arrow where the
  mathematical declaration specifies one; a shape label does not replace an arrow.

A registered method uses the same construction-invocation envelope, with its own
method id as the dispatched `op` and `ctor`:
`{"ctor":<method id>,"args":[<residual action descriptor>,...,
<selected method-functor descriptor>],"receiver":<chosen input data>}`.
The final argument is always the complete descriptor
`{"ctor":<method's registered functor id>,"args":[<ordered explicit parameters>]}`,
including when there are no residual actions or explicit parameters. Earlier arguments
are the selected residual structural actions, in composition order from the chosen receiver
toward the method owner. They use the existing functor, `classifierForget` and
`constructorMap` descriptor grammar, retaining every nested parameter at its declared
position. This is one ordered list of complete descriptors, not a flattened parameter list.

The receiver is the complete actual input at the chosen registration boundary. An
explicitly admitted source-composite implementation may receive that source receiver and
its residual action descriptors. A registration at the method owner's category receives
the actual transported receiver after the shared actions have executed; its residual list
is empty. Category-wide registration does not make a target consumer responsible for
unexecuted source actions. The published `MethodEntry.shape` fixes the final formal argument.
For an iso-invariant method it applies the formal Core wrapping to that receiver; it does
not introduce another registration input or an extra `coreObject` wire wrapper. Thus
`meth.cardinality` at a set input retains the actual set data. An independently selected
receiver whose own declared form is Core still keeps that form's complete data.

The kernel fixes and checks the method, the complete residual action applications, their
ordered parameter occurrences, the final functor application, source and target dictionaries,
and result interface before using a reply. Every computational dependency of the receiver
and every descriptor parameter belongs to this whole request and retains its original live
owner. Equal carriers, recoverable-looking formal parameters or private runtime handles do
not justify omitting data from the request. The reply uses the method's independently
declared complete result interface; it supplies no route, parameter replacement or law.

`ConstructionInvocation.decodeMethod` and Python `method_invocation` check the envelope,
nonempty descriptor sequence, existing descriptor grammar and the final independently
supplied functor id. They return the unchanged complete request; they do not establish
registry membership, parameter types, route order, formal applicability or live ownership.

The uniform complete request is the primary method interface. A raw receiver-only request
is permitted solely by an explicit kernel compatibility rule that has checked both an empty
residual route and zero explicit computational parameters of the selected method functor.
This subset carries no omitted selected data. A generic decoder never infers that rule from
receiver bytes or falls back to raw data after a malformed complete request. This method
convention does not change property requests or direct functor/construction action requests.

A registered functor's object action receives
`{"ctor": <functor id>, "args": [<ordered explicit declaration arguments>],
"receiver": <source object data>}`. The registered declaration determines the argument
types, source and target, including dependent parameters. The kernel checks those types and
endpoints; a backend cannot choose the functor or its parameters. The result is decoded in
the declared target form.

A `FunctorEntry` additionally exposes its morphism action at `<functor id>#map` and
the complete-request input `<functor id>#input` for either action. Existing object-action
registrations on admitted source-object or source-category forms remain peers of that
complete-request registration; overlap is ambiguous. The two action addresses project the
already registered functor, not new mathematical rows. Supplying its object action does not
advertise its morphism action or any subsequent operation on the target category.

The morphism action uses the existing seven-field `PointInvocation`:
`{"ctor":"apply","args":["<functor id>#map",[<ordered explicit parameters>],
{"ctor":"map","args":[{"ctor":<functor id>,"args":[<the same parameters>]},
{"ctor":"typedMap","args":[<actual X>,<actual Y>,<actual f>]}]},
<original domain>,<actual F(X)>,<actual F(Y)>,<original argument>]}`.
The kernel first executes or reuses the selected object actions at `X` and `Y`. Their
actual returned images, including every retained dependency, are the outer source and
target. Both are required even if the functor preserves the underlying carrier. The inner
map retains the complete source-category endpoints and the original callable `f`.
Core comparisons and Arrow-valued endpoints retain their existing complete data forms.
The invocation id and action id must select this same functor, and both ordered parameter
arrays must agree exactly. The formal caller independently checks their full declaration
signature and the actual source and target categories; parsing supplies none of these laws.

To obtain the whole map `F(f)`, the original domain is the actual `F(X)` and the argument
is `{"ctor":"identity","args":[<actual F(X)>,<actual F(X)>]}`. The same request form
also applies the map to an already selected generalized point, retaining its actual domain
and argument. For the whole-domain request a reply is ordinary callable data at the fixed
`F(X)` and `F(Y)`: a `typedMap` retaining both exact image descriptors, or an owning opaque
callable under the existing result rules. For a point request the reply instead has the
declared point-data interface at `F(Y)`. A result cannot choose replacement endpoints.

The shared executor interprets composed object and morphism actions through these registered
primitives and retains their actual returned data. A later target-category operation receives
that data in its admitted input form; it need not interpret the source functor's recipe or
private representation. A complete self-contained reply with no nested opaque dependency
is portable to another admitted consumer. Retained input/action provenance alone does not
make such a reply session-owned. Conversely, `valueData` does not make nested opaque data
portable: every such dependency keeps its supplying live connection, as do any actual
parameters required by the subsequent request. A descriptor never transfers an opaque owner.
An absent implementation or representation bridge is a computational gap; a foreign or
expired owner remains unavailable. Neither changes the formal functor or its laws.

Classifier forgetting and registered category-constructor actions use the same executable
boundary. Their stable identity is one of `{"classifierForget":<classifier id>}` or
`{"constructorMap":[<constructor id>,<inner identity>]}`; an inner identity may also be
`{"functor":<functor id>}`. Each constructor must publish its actual `functorialAction`,
and every nested classifier/functor id must be registered. Their object-operation address is
`action:` followed by the compact JSON of that complete identity. The map and complete-input
addresses append `#map` and `#input`. Only this canonical spelling is admitted. A bare
`{"functor":...}` root is rejected because a `FunctorEntry` already has its own addresses.
These are computational projections of existing edges, not new mathematical rows or tags.

The identity omits parameters only for registration. The actual object invocation is the
existing construction frame `{"ctor":<object address>,"args":[<complete action descriptor>],
"receiver":<actual source object>}`. Its one argument is the existing `classifierForget`
or `constructorMap` wire descriptor, retaining every actual parameter at its original nested
position. The map invocation uses `apply(<map address>,[<complete action descriptor>],
map(<that same descriptor>,typedMap(X,Y,f)),domain,F(X),F(Y),argument)`. The selected image
packets, original typed source arrow and generalized argument obey the same rules as a
registered functor's map action above. Address identity, both occurrences of the complete
descriptor and the full independently selected formal action must agree. The derived action
accepts only its own complete-input address. Constructor nesting is an address family, so a
finite exported inventory is not an exhaustive enumeration of its possible applications.

A directly applied `ConstructionEntry` exports the object operation `<construction id>`,
the map point operation `<construction id>#map`, and the complete request input
`<construction id>#input`. The image form uses `<construction id>` in the construction's
registered target category. These addresses project the one registered dependent functor;
they are not per-category mathematical rows. Its full signature fixes the selected
parameters, complete source category and target. Direct constructions are not inherited
along a receiver's structural routes.

The object request is the same complete object-action frame:
`{"ctor":<construction id>,"args":[<ordered explicit parameters>],
"receiver":<complete source object data>}`. A retained action descriptor omits `receiver`,
`{"ctor":<construction id>,"args":[<ordered explicit parameters>]}`, and its formal image is
`{"ctor":"functorAction","args":[<action descriptor>,<complete source object data>]}`.
Every explicit data parameter remains in declaration order. A selected category parameter is
`{"ctor":"category","args":[<registered category id>,[<ordered parameters>]]}` and a
selected functor parameter is
`{"ctor":"functor","args":[<registered functor id>,[<ordered parameters>]]}`.
An accepted category-constructor application, including one with no separate named
category row, is `{"ctor":"constructedCategory","args":[<constructor id>,
[<ordered constructor argument descriptors>]]}`. Its argument kinds and order are
the published `ConstructorEntry.signature`; its complete category is the application
of the published `semantics`. Category arguments recursively use `category` or
`constructedCategory`; object and functor arguments use their existing complete forms.
The kernel checks each full declared dictionary, including chosen category structures and
functor source and target, before dispatch. Equal carriers do not identify those selections.

When that declared source is a core category, its object data is
`{"ctor":"coreObject","args":[<complete underlying object data>]}`. A selected source
isomorphism retains both complete underlying endpoints and both directed maps:
`{"ctor":"coreIso","args":[<source object data>,<target object data>,
<forward morphism data>,<backward morphism data>]}`. The forward map runs from source to
target and the backward map in the opposite direction. A registered comparison uses its
ordinary `presentation(id,parameters,false)` and `presentation(id,parameters,true)` arrow
descriptors in those slots. The formal caller already fixes and checks the isomorphism;
these packets provide data and do not ask a backend to supply an inverse law or a proof.
`Core` is preserved as the actual declared source; it is not replaced by the underlying
category or by a carrier set.

Applying the construction's actual map to a supplied point uses `PointInvocation` under
`<construction id>#map`. Its `parameters` are the same complete ordered construction
parameters; its `arrow` is `{"ctor":"map","args":[<action descriptor>,
<complete source arrow data>]}`. Its `source` and `target` are the corresponding complete
constructed images, and its `domain` and `argument` retain the original generalized point.
The operation in the packet equals the dispatched `<construction id>#map`. Both directions
of a core comparison remain in the source arrow even when only the forward mapped arrow is
being applied. Replies use the ordinary declared computational point-data interface at the
fixed constructed target. No reply determines that target or changes the selected comparison.

The constructed image inherits operations solely from its registered target and selected
structural maps. Those operations receive the complete constructed descriptor and every
actual computed dependency, including opaque session ownership. An object action, map point
action, and later target operation are distinct computations. Providing one does not advertise
implementations of the others. Ordinary declared morphism families may take constructed images
as their typed parameters or endpoints, using these same descriptors and full parameter order.

An object whose independently declared type is an Arrow or a full subcategory of
Arrow uses the complete record
`{"ctor":"arrow","args":[<source object>,<target object>,<defining map>]}`.
The selected result type, including its full parameters, fixes the record interface.
All three computational fields are retained; the map runs from the first endpoint
to the second and is checked at those exact computational endpoint descriptors.
The record does not change which category's operations apply to the value.

For a subobject or a kernel presented as a subobject, the fields are the kernel
object `K`, its ambient object `X`, and the inclusion `K → X`. For a quotient or a
cokernel presented as a quotient, they are the ambient object `Y`, the quotient
object `Q`, and the projection `Y → Q`. The computed object is therefore the first
slot for a kernel and the second slot for a cokernel; endpoint order always follows
the defining map. A reply never supplies monicity, epicity or a universal-property
proof. Those properties belong to the independently fixed formal construction.

The existing `{"ctor":"subobject","args":[<source>,<target>,<defining map>]}`
spelling remains supported for a declared full subcategory of Arrow, with exactly
the same three data slots. Its historical name supplies no assertion of monicity
and does not reverse quotient endpoints. It is not a representation of an
incompatible ordinary object or a plain Arrow without that declared refinement.
Neither spelling can choose the predicate defining the formal full subcategory.

The stored map of a complete Arrow record may be described by
`{"ctor":"arrowHom","args":[<complete arrow object data>]}`. The receiver must
have the independently fixed Arrow record interface. The result is that object's
actual stored defining map, at its exact full source and target. This does not
permit an arbitrary field projection, a new operation, or a different choice of
endpoints. The stored defining map is the third argument of the complete record.

A returned refined Arrow record may additionally supply a source-side presentation
`"presentation":{"hom":<morphism data>,"inv":<morphism data>}`. As for cones below,
`hom` runs from the independently fixed requested source to the returned source,
and `inv` runs in reverse. For a subobject, the source is its apex and the target
is its ambient object. This existing field does not instead compare a quotient's
second endpoint. The full other endpoint must remain the independently requested
one. Inverse equations and commutation squares are correctness obligations for
acceptance; the computational boundary does not prove them to identify returned
data with mathematics. These fields contain ordinary morphism data, no proof or
assertion of equality. Required missing fields or maps with incompatible declared
endpoints are malformed. A complete well-formed wrong answer remains computational
data and reaches acceptance.

For subsequent computations the complete context may be encoded as
`{"ctor":"objectPresentation","args":[<complete requested functorAction descriptor>,
<complete returned Arrow record>]}`. The first argument is independently reconstructed
from the exact registered functor, ordered parameters and original receiver. The second retains
all returned data and any presentation maps above. The first argument fixes formal meaning;
the second remains opaque computational data. This envelope establishes no isomorphism or
universal property. Further functor actions and defining-map projections carry complete context
without using the answer to determine formal structure or operations.

Every lift request additionally has a top-level `"parameters":[...]` field containing
all explicit non-proof data arguments of the selected `LiftEntry.evidence` declaration,
in its declaration order. This list is independent of the action descriptor's parameters:
a selected family `L p : MonoLift U` can depend on `p` even when `U` does not. The public
`lifts[].selection` metadata publishes that declaration and complete signature. Computed
parameters retain their actual data and session owner. The four returned fields and the
ordered `args` below are unchanged; the parameter list contains no proof or certificate.
Historical `liftInput` packets without this member decode as an empty parameter list;
new requests always include it, and explicit `monoLiftInput` and `liftFactorInput`
packets require it even when empty. A leaf checks the list against its declared selection.

A registered subobject lift's public `MonoLiftComputation` has four callable fields:
`obj`, `hom`, `forward`, and `backward`. Their concrete port addresses are
`<lift id>#obj`, `<lift id>#hom`, `<lift id>#forward`, and `<lift id>#backward`, each
registered on `<lift id>#input`. These addresses expose only the published fields of
`LiftEntry.computation`; they create no mathematical operations or laws. A request is
`{"ctor":"liftInput","parameters":[<ordered selected evidence arguments>],
"args":[<exact lift id>,<selected inner action descriptor>,
<complete source Arrow>,<current complete base subobject>,[<earlier actual outputs>]]}`.
An explicitly selected lift at `X` and `i : K → U(X)` uses the same addresses
and the variant
`{"ctor":"monoLiftInput","parameters":[<ordered selected evidence arguments>],
"args":[<exact lift id>,<selected inner action descriptor>,
<actual source object X>,<current complete base subobject>,[<earlier actual outputs>]]}`.
This request retains exactly the declared inputs; it does not invent an Arrow out
of `X`. Both variants have the same four result types and ordered data dependency.

The field order is fixed. `obj` sees an empty output prefix; `hom`, `forward`, and
`backward` see respectively one, two, and three actual preceding outputs. The full
selected action parameters, original Arrow endpoints and map, actual base apex and
inclusion, and session ownership survive every request. No reply chooses the lift.

New executions additionally retain top-level complete image interfaces; the five ordered
arguments above are unchanged. `"sourceImage":<data>` is present in every field
request. For `liftInput` it retains the complete selected Arrow-image interface,
including both image endpoints and its mapped callable. For `monoLiftInput` it
retains the object-image interface `U(X)` fixed by the base inclusion's target.
These positions may hold actual retained data or a typed deferred plan under the
complete public interface. Only an actual producer receipt establishes execution
history; a well-framed image descriptor alone does not assert a separate action call.
`"comparisonImage":<data>` is absent for `obj` and `hom` requests, optional for
`forward` (preceding output prefix length two), and required for `backward`.
When supplied to `forward`, it fixes the actual image endpoint `U(O)`. When
omitted, the forward reply's complete typed map supplies that endpoint at the
independently fixed formal object `U(O)`; its target must still match the retained
base object `K`. The exact returned source then supplies `comparisonImage` for
the backward request and completed step. This is a field-produced endpoint, not
evidence that a separate object-action operation ran.
These fields retain their own session ownership. A supplied `null`, a comparison
image without a source image, or image metadata at the wrong stage is malformed.

Packets omitting both image fields retain the legacy recipe format: image
endpoints are the declared `functorAction(action, object)` descriptors, and a
transported Arrow uses those descriptors with `map(action, callable)`. This
compatibility mode is chosen by field absence, never by comparing token bytes or
guessing whether an action was executed. A metadata-bearing packet is checked at
the independently selected full interfaces. During execution its fields must also
match the exact retained request and image occurrences; a standalone framing decode
does not establish any execution history or mathematical equality.

The object reply is ordinary object data. Each map reply is
`{"ctor":"typedMap","args":[<actual domain data>,<actual codomain data>,<callable data>]}`.
For object output `O`, source Arrow `X → Y`, and base subobject `K → U(X)`, the map
endpoints are `O → X`, `U(O) → K`, and `K → U(O)`, in that order. `U(O)` uses the
preselected `comparisonImage` or the forward reply's source endpoint in the new
form, or the complete selected inner action descriptor applied to the actual
object output in the legacy form. In the new
form the base's ambient retains the actual `sourceImage` source object. Callable
data may be opaque on infinite carriers; it is not enumerated or converted to a Lean
morphism. Finite graphs use their actual domain and codomain descriptors. Missing fields
or incompatible declared endpoints are malformed. Well-framed mathematically wrong
objects or maps remain wrong data, to be tested by the independent permanent assertions;
no inverse, monicity, factorization or universal-property proof is requested from a leaf.

The separate canonical `MonoLiftFactorComputation` supplies the universal factor
at `<lift id>#factor`, also registered on `<lift id>#input`. It has the request
`{"ctor":"liftFactorInput","parameters":[<ordered selected evidence arguments>],
"args":[<exact lift id>,<selected inner action descriptor>,
<actual source object X>,<complete base subobject K → U(X)>,
[<object output>,<typed inclusion output>,<typed forward output>,<typed backward output>],
<typed base map g : U(Y) → K>,<typed cone f : Y → X>]}`.
The result is a `typedMap` from the cone's actual domain `Y` to the actual object
output `O`. The formal caller supplies and checks `Mono i` and
`U.map f = g ≫ i` before dispatch; neither proof is wire data. The factor must
satisfy both `U.map factor ≫ forward = g` and `factor ≫ hom = f`, as tested by
independent acceptance. A framed wrong factor remains computational data.
This is a separate computation, with no fifth field added to the four lift
outputs and no permission to substitute a comparison isomorphism for the factor.
The factor request may carry the same top-level `sourceImage` and
`comparisonImage` together, retaining the actual `U(X)` and `U(O)` used by its
completed four-field computation. Its seven ordered arguments are unchanged;
omitting both image fields selects the same legacy recipe framing.
Internally derived cone and action inputs may be typed deferred plans. A complete
factor implementation need not install or invoke every internal `U#obj` or
`U#map` through the kernel: it may use the public kernel service or private
implementation reuse. The selected full interfaces and seven ordered arguments
remain the same.

For a composed lift, the kernel factors through the inner action and then the
outer action. The actual returned first factor is the next request's base map;
its formal source equation supplies that request's compatibility proof. The
canonical public `MonoLift.factor_comp` identifies this staged computation with
the composite factor. All selected parameters, complete four-field outputs and
opaque ownership remain attached to the subsequent request. No kernel extension
or extra composite registration is needed for another prescribed stage.

The kernel encodes a completed prescribed lift for subsequent computations as
`{"ctor":"liftedSubobject","args":[<original complete base subobject reply>,
<complete original source Arrow>,[<prescribed lift ids in route order>],
[<completed steps in route order>]]}`. Each step is
`{"ctor":"liftStep","parameters":[<ordered selected evidence arguments>],
"args":[<exact lift id>,<selected inner action descriptor>,
<complete source Arrow for this step>,<actual base subobject for this step>,
[<object output>,<typed inclusion output>,<typed forward output>,<typed backward output>]]}`.
Each step retains the same evidence-family parameters as its four field requests;
they are not inferred from the inner action or reconstructed from the returned object.
Each new completed step also retains both top-level `sourceImage` and
`comparisonImage`, with the complete transported Arrow as `sourceImage`. The next
forward-route source is exactly that actual Arrow; the comparison maps use the
actual `comparisonImage` endpoint. Historical steps without both fields retain
their recipe framing. The selected formal plan fixes every interface independently
of these data, and runtime validation compares each field with its retained stage.
Execution runs in reverse route order. Its next base is the subobject formed from the
preceding step's actual object and inclusion outputs, with its actual source ambient;
it never repeats the initial base packet for later steps. All four actual fields are
retained, including both comparison directions. A three-field `liftedSubobject` packet
without component outputs is incomplete and cannot claim completed execution. Formal
meaning, the selected route, and the complete source/base types remain independently fixed.

A named object's registered generator arrow is
`{"ctor":"generator","args":[<registered named set object id>,
[<ordered explicit generator declaration arguments>]]}`. The declaration and its full
signature own the endpoint and any index; this descriptor does not introduce a new arrow row.
A selected structured object's carrier reaches that set only along its registered structure.

Closed points at selected named objects use
`{"ctor":"element","args":[<exact selected object descriptor>,<arithmetic data>]}`.
The descriptor includes every ordered parameter and must equal the independently selected
endpoint. Arithmetic data has only `ctor` and ordered `args`: `numeral` takes one natural
number, `generator` takes no argument or one natural index, `add` and `mul` take two data
expressions, and `neg` takes one. These tags invoke existing registered language operations;
they do not contain Lean source or choose an object by its carrier.

The general published operation expression is
`{"ctor":"operationExpression","args":[<registered operation id>,
[<full ordered selected declaration parameters>],[<ordered operand expressions>]]}`
inside that same exact selected-object envelope. The public operation signature fixes
operand types, arity, chosen structure and result. These fields come from the retained
formal construction, not a guessed arithmetic name. Existing short arithmetic tags remain
portable input encodings; operations such as power use this general encoding. The kernel
serializes the expression and checks its formal trace and types without reimplementing
the operation or requiring an input-expression roundtrip through law-bearing Lean values.
The leaf lowers the declared operation to its native engine at those selected parameters.
Transport retains its actual registered action; nonidentity maps cannot be discarded.
An operand that is a closed point `1 ⟶ X` formed some other way (a registered named
morphism such as a constant, a composite of a point with a map, a product mediator, an
admitted point) is `{"ctor":"point","args":[<that point's morphism encoding>]}`, the encoding
this section gives morphisms. Its endpoints are the operand's declared ones.

A closed point forwarded through an accepted carrier-preserving structural view uses
`{"ctor":"pointView","args":[<complete target functorAction object descriptor>,
<complete source element envelope>,<exact generalized-point domain descriptor>]}`.
The kernel checks the complete registered source-object action, its selected target and the
independently retained formal point's carrier identification. It forwards the actual original
computational data and every nested opaque owner without reconstructing the backend answer
as a formal point. The domain must equal the independently fixed source
of the original and requested generalized point. This describes only an admitted forward
carrier identification; it cannot recover a structure from its carrier or choose a new
domain. Nonidentity point maps retain their actual morphism action and composition instead.

A nullary registered operation's point, with its actual terminal-source comparison, uses
`{"ctor":"operationPoint","args":[<registered operation id>,
[<ordered explicit declaration parameters>],<complete accepted presentation-arrow data>,
<exact original generalized-domain descriptor>,<complete selected target object descriptor>]}`.
The kernel instantiates that same operation at the complete parameters, checks the actual
registered comparison from its global-point source to the operation's declared source, and
reconstructs its point at the independently fixed target and original generalized domain.
Any supported raw-map reconstruction must be checked against the actual instantiated operation;
an unsupported reconstruction is a computational gap. This envelope supplies no proof, chooses
no structure from a carrier, and cannot replace the operation's source with another terminal.

A registered comparison's point application is requested under that comparison id, with
`{"ctor":"presentationApply","args":[<ordered parameters>,<inverse boolean>,
<exact source descriptor>,<exact target descriptor>,<input point data>]}`. The reply uses the
ordinary `valueData` or `opaqueData` alternatives at the exact target. Inline data have the
declared computational result interface; opaque data retain their owning live connection.
The kernel checks the public framing against the independently selected target and retains
the actual computational data for subsequent operations. This structural check does not
establish the mathematical correctness of the returned value; independent acceptance compares
the observed computation with its meaning.

Every released morphism or callable operation may instead use the common point-invocation
envelope under its original registered operation id:
`{"ctor":"apply","args":[<operation id>,[<ordered full parameters>],
<actual arrow descriptor>,<generalized-point domain>,<complete source object>,
<complete target object>,<input point data>]}`. The kernel fixes these fields from the
published signature and retained composition before dispatch; the first field must equal
the outer request's `op`. A point has its original generalized domain, rather than an
assumed singleton. The arrow may include registered actions, compositions or selected
comparison maps; none is replaced by an endpoint rename. This invokes the declared map
on the supplied computational point, without first obtaining its graph on an infinite carrier.

The same envelope requests an entire callable `f : X → Y` by taking the original
generalized domain to be `X` and the argument to be
`{"ctor":"identity","args":[<complete X>,<complete X>]}`. The source is the same
complete `X`, the target is the complete `Y`, and the actual arrow field remains `f`.
This is the ordinary composition `id_X ≫ f`, with all of `X` retained; it is not a
request to evaluate at a representative point. The reply supplies complete `X → Y`
callable data: a total finite graph at its actual domain, a complete supported
symbolic callable, or an owned opaque callable. A scalar cannot replace a
callable on a non-singleton domain.
The operation ID and full parameters remain those of the declared callable;
identity is the argument descriptor, not a new operation or registration address.

A published `BinderEntry.operation` is addressed by its existing binder id. A published
`ObjectEntry.application` is addressed by `<object id>#application`. These are concrete
addresses of existing callable metadata, not new semantic rows. An application address is
admitted only when that exact object exports the field. Its complete ordered declaration
parameters, source and target are fixed from that field's actual signature. Binder inputs
retain the actual admitted map and the selected bound/range parameters; the caller does not
substitute another formally equivalent sum or product. For these binder and object-application
fields, a registration may use the exported complete-request address itself as its input form,
or a supported declared source-object form. An operation address is not automatically an input
form: for example, `op.rings.pow` registers on a compatible published ring-object form or
`cat.rings`, not on an invented input form `op.rings.pow`. The generated `inputForms` inventory
lists these concrete registration addresses. Constructor-induced component addresses additionally
follow the declared finite-path grammar below.

An independently admitted point retains its original computational data as
`{"ctor":"admittedPoint","args":[<published object id>,[<full ordered parameters>],
<original generalized domain>,<original target object>,<selected admitted target>,
<actual original point data>]}`. The kernel fixes the category and the actual public
admission declaration, checks the original and admitted formal endpoints, and keeps the
formal admission evidence on the interpretation side. The wrapper supplies no proof.
Computations consume the original point data under the selected target's interface;
they do not substitute the canonical admitted formal value or certify backend membership.
Opaque data keep their original owning connection through the wrapper.

A point of an independently fixed constrained structure may retain its original data as
`{"ctor":"constrainedPoint","args":[<actual constructor name>,
<original generalized domain>,<original data-field type descriptor>,
<complete selected target object>,<actual original point data>]}`.
The kernel requires a fixed closed nonrecursive structure with one constructor and no
indices, exactly one data field, and only proposition-valued remaining fields. It checks
the actual constructor, the original data-field type, the complete selected target and
the original generalized domain against the retained checked semantic term. The actual
formal proof stays in that term; no proof, predicate claim or certificate is sent on the wire.
The request passes through the original point data with every nested opaque value's actual
owner. It does not substitute a canonical formal representative, reconstruct the backend
data as a proof-bearing value, or establish that a computational answer satisfies a predicate.
This is input framing for an existing checked construction, not a new admission or operation.

The reply is `{"ctor":"valueData","args":[<declared computational result data>]}` or
`{"ctor":"opaqueData","args":[<nonempty connection-local token>]}`. Its mathematical
result and interface remain the independently fixed target at the same generalized domain.
Inline data retain every component required by the published result contract. An opaque
token refers to computational data or a callable implementation, never a Lean term or proof.
The kernel retains the actual connection identity and supplying backend with the token;
the reply cannot choose that owner. Later declared operations consume the same returned
data. An opaque token is usable only on its original live connection and only through an
admitted registration for the requested operation and form. A lost connection is unavailable;
it is not restarted to reinterpret the token. Another implementation cannot be sent an
unknown token, and a token cannot add operations or change their formal meaning. Portable
inline data remain available to other admitted implementations under their declared contracts.

This common encoding applies equally to subsequent operations on returned values and to
callable components of complete structured results. It does not require eagerly enumerating
an infinite carrier, proving algebraic laws, or treating a returned value as the canonical
mathematical answer. Well-framed but wrong data remain possible and are observed by acceptance.

When a published callable's actual declared source is the public binary product
`Prod X Y`, its full source descriptor may use
`{"ctor":"objectProduct","args":[<full X descriptor>,<full Y descriptor>]}`.
The caller establishes the selected product and ordered endpoints before dispatch;
this concrete descriptor adds no semantic row and requires no named-source lookup.
A generalized point of that source carries the two ordered component data in a
JSON array. An observation such as the published equality characteristic map has
`X = Y`, but this framing does not identify or replace either component's data.
The existing complete callable form may admit that request without a separately
registered named product object. Product or equality laws are not certified by
the descriptor or the returned data. A complete symbolic product descriptor may also be
used as a returned cone or cocone apex under its declared object-data interface; that
apex needs no separate named-object registration.

A computational observation of a truth value (the published target `obj.sets.truth_values`)
uses `valueData` containing a JSON boolean. This is an implementation's answer, not a term
inhabiting the proposition, a decidability proof, or a certificate. A characteristic map,
including the published equality map, is invoked on the supplied computational arguments
through the same `apply` envelope. The consumer compares its observed boolean with the
independently fixed expected boolean. A non-singleton generalized domain still requires
its declared pointwise data or callable representation; one boolean cannot stand for an
arbitrary truth-valued function. No observation changes the formal proposition.

A complete accepted structural functor action may be carried as
`{"ctor":"functorAction","args":[<exact edge descriptor>,<complete selected source object>]}`.
The complete selected functor and formal source are established independently of backend
data. The computational source is retained alongside that context; it is not reconstructed
as a law-bearing mathematical object. For a registered constructive
functor whose result is in the registered subobjects category, its apex or inclusion
is described by `{"ctor":"subobjectApex","args":[<complete constructed subobject data>]}` or
`{"ctor":"subobjectInclusion","args":[<complete constructed subobject data>]}`. The receiver
may be complete `functorAction`, `objectPresentation`, or `liftedSubobject` data. Its full
subobjects category and formal selected structure remain fixed independently, while complete
computational ambient, apex and inclusion fields are retained and validated in their declared
forms. A presented receiver retains its full computational context; a lifted receiver retains
the complete source construction, prescribed registered lifts in order, and their full selected
structure and defining maps. Computational projections read those returned fields; formal
projections derive from the independent construction. These are
categorical data descriptions, with exact expected types checked independently; they do not
name a new limit, supply a proof or choose a lift.

Formal reference descriptors for a registered limit or colimit use
`{"ctor":"limitApex","args":[<registered limit id>,<complete diagram>]}` or
`{"ctor":"limitLeg","args":[<registered limit id>,<complete diagram>,<index>]}`.
Their formal interpretation instantiates the registered mathematical presentation and
projects its apex or leg. These descriptors contain no proof and assert no comparison with
another apex. They do not establish that required external computation ran, and cannot
replace an actual returned computational apex or defining map during result reuse.

The defining leg of a complete returned construction may instead use
`{"ctor":"constructionLeg","args":[<registered limit id>,<complete diagram>,
<complete returned cone or cocone envelope>,<exact typed index>]}`. The index is data at
the actual diagram's declared object type. Computational projection reads the returned leg;
formal projection derives its map from the authoritative construction independently. Complete
defining-map data is retained, without requiring a proof that the backend's cone is universal.
A different apex's leg cannot be replaced by the canonical leg or identified by cardinality. This is the existing registered
universal construction's defining-map projection, not a new mathematical operation.

A projection of an ordered data port uses
`{"ctor":"constructionField","args":[<registered limit id>,<complete source diagram>,
<complete returned cone, cocone or createdCone packet>,<natural-number data-port index>]}`.
The index counts the registered `dataConstructor`'s non-Prop ports in declaration order,
including object ports. It is not a diagram-object index and is not interchangeable with
`constructionLeg`'s typed leg index. The full fixed source diagram and returned packet remain
present through creation lifts and subsequent computations. The formal caller determines the
exact field and its complete expected type; the packet cannot choose another field or prove a law.
This is a data projection, with no new operation or registration address. The helpers
`Backend.ConstructionField` and `construction_field` validate its four-field framing only.

`constructionLeg` is arrow data, not an operation address. In subsequent computations it
may occur inside `compose`, `point`, `map`, a mediator, or a complete argument supplied to
an already declared operation (including equality). That invocation keeps the consuming
operation's original registered id and full input form; the creating limit id does not
become an arbitrary-map `apply` operation. If a declared callable supplies an `apply`
request, its original address also remains the outer `op` and the first `apply` field.
No standalone generic Hom-set application address is declared by this protocol. A leaf
may evaluate the retained leg as part of consuming these ordinary public data without
creating or registering an additional operation.

For a returned construction carried through an accepted creation lift, the complete cone
envelope inside `constructionLeg` is
`{"ctor":"createdCone","args":[<registered lift id>,<complete source diagram>,
<complete returned target cone envelope>]}`.
The formal source construction is derived from accepted creation independently of the returned
target data. The computational envelope retains the exact lift, diagram and all target fields;
it supplies no universal-property proof, guessed identification or named source-apex recovery.
It cannot select a different formal lift, diagram or source structure.

`{"ctor":"zero","args":[<source object>,<target object>]}` requires the category's
actual zero-morphism structure. `identity` has the same endpoints syntax and requires equal
endpoints. Every constructed value is checked at its exact expected type.

A registered natural transformation component is
`{"ctor":"cellComponent","args":[<cell id>,[<ordered declaration parameters>],
<complete selected receiver>,<inverse boolean>]}`. The component is exactly `NatTrans.app`
at that receiver. False selects the forward component; true requires an invertible cell and
selects its inverse. All source and target parameters come from that full declaration.
A point application uses the common seven-field `apply` request, with operation
`<cell id>#component`, parameters `[<ordered declaration parameters>,<receiver>,<inverse>]`,
and the complete `cellComponent` arrow. Its own operation address is also its complete input
address. The public API exports the exact component type and both oriented routes. A cell's
id, an equal carrier, or its role in resolution is not permission to replace its action by
an identity. Wrong but well-framed point data remains a possible answer.

A constructor-induced component retains its entire accepted constructor path as
`{"ctor":"constructedCellComponent","args":[[<constructor ids>],<cellComponent>]}`.
The nonempty constructor list is ordered outermost to innermost. In this enclosing form,
the nested component's receiver is the complete constructed receiver; its type is the one
obtained by the registered constructors' `comparisonAction` declarations. It is not an
argument of the base cell's unconstructed port. The operation and input address are both
`component:` followed by compact JSON `[<cell id>,[<constructor ids>]]`. An empty path uses
the existing `<cell id>#component` address and four-field `cellComponent` form. Parameters,
orientation, seven-field point application and ordinary result/ownership rules are unchanged.
The constructor comparison actions require an invertible registered cell in either orientation.
Only registered comparison actions determine the derived source, target and actual map.

An arrow of a registered presentation comparison is
`{"ctor":"presentation","args":[<comparison id>,[<ordered explicit parameters>],
<inverse boolean>]}`. False selects its forward arrow; true selects its inverse.
The registered comparison fixes both endpoints and the actual isomorphism. A structural
functor's action on this arrow uses the same `map` envelope as any other arrow.

Computational application of that comparison uses its original registered id as the
outer request's `op`, with
`{"ctor":"presentationApply","args":[[<ordered explicit parameters>],
<inverse boolean>,<actual source descriptor>,<actual target descriptor>,<point data>]}`.
All five fields are required. False applies the forward comparison; true applies
its inverse, and the ordered endpoint descriptors follow that selected direction.
The point data and any nested opaque ownership are retained. This is an invocation
of the registered comparison, not a new operation or a claim that it is the identity.
A registration may use that comparison's own exported input address for the complete
request, or an admitted endpoint form. Both are peers when applicable; overlap is
ambiguous. The complete-request address does not authorize a different comparison.

A callable component may always include its complete actual endpoints as
`{"ctor":"typedMap","args":[<source descriptor>,<target descriptor>,<callable data>]}`.
Consumers compare both complete descriptors with the already selected computational endpoints,
then validate the callable at those endpoints. This form applies to defining maps in ordinary
Arrow objects and (co)limits as well as the four prescribed-lift ports. Opaque callable fields
may be nested inside public records; the owning live connection is retained recursively.

An endpoint whose full object is fixed by a declared arrow need not have a separate named
object registration. Its public data is
`{"ctor":"morphismEndpoint","args":[<actual callable data>,"source"]}` or the same
two-field record with `"target"`. The complete independently selected arrow signature fixes
the endpoint and its category parameters. The callable retains all its ordered parameters and
any opaque owner. An already framed `typedMap` retains its actual endpoint fields instead of
replacing them with this wrapper. The wrapper is object data, supplies no point inventory,
and is not itself callable. Reuse is checked against the retained complete descriptor and
formal context; parsing it does not reconstruct an arrow or choose a mathematical object.
`finiteData` may supply an actual inventory for this exact descriptor under the usual rules.

A category-wide registration uses its registered category id as `input` and accepts the same
complete public representation of values in that exact category. For a limit this is its
diagram. A method keeps its complete invocation envelope above, including the actual receiver
and final method-functor descriptor; the category input describes that receiver, not permission
to omit selected parameters. Other applicable operations retain their own complete request
grammar. Structural transport is fixed before dispatch. Exact-form and category-wide
registrations have equal standing: overlapping applicable registrations are ambiguous, with
no implicit specialization order.

An answer is a value of the operation's declared result form in this encoding. The answer of a
limit is its cone, `{"ctor": "cone", "args": [<apex>, <leg>, ...]}`, and of a colimit its cocone,
`{"ctor": "cocone", "args": [<apex>, <leg>, ...]}`: the apex is complete object data in the
declared category, and each leg is a morphism. The apex may be unnamed, including a complete
symbolic product when its declared interface supports that form; it need not be a named
object row. The kernel decodes every answer against its declared computational data form,
retaining every required field and exact map endpoint, or rejects it as malformed.
It does not build a formal cone from the returned data:
formal commutation and universal-property proofs remain with the independent construction.
Correctness of the returned legs is judged by acceptance.

The registered limit's `dataConstructor` publishes the complete dependent constructor whose
ordered non-propositional fields are these result ports. Its `standardization`, when supplied,
publishes the comparison from a general diagram to that declared presentation. The kernel
consumes those typed declarations, including for creation-lift transport. A shape name alone
neither chooses a result constructor nor supplies a comparison. Both signatures are included
in `api/declared-ports.json` alongside the operation's full original signature.

A structured reply may additionally carry map data relating the independently declared
presentation of the requested diagram to the returned presentation:

```json
{"ctor":"cone","args":["<apex>","<legs>"],
 "presentation":{"hom":"<graph>","inv":"<graph>"}}
```

The same envelope is permitted for a cocone. `hom` runs from the independent presentation's
apex to the returned apex; `inv` runs in the reverse direction. Both use the declared
category's morphism encoding. These are computations, never proofs or a certificate. The
kernel checks their declared forms and endpoints without proving their inverse equations,
compatibility with defining legs or universality. Those are correctness questions for acceptance.
Missing required defining maps or ill-formed data are malformed. A well-formed wrong computation
does not change the formal construction, requested diagram or mathematical question.
-/

open Lean

namespace CasCatalogue.Backend

/-- A declared map field of a registered object, with its complete ordered parameters.
Presentation fields select the accepted `ObjectEntry.functorPresentation` identification
in the indicated direction. Refinement fields select `ObjectEntry.refines.identification`
from the full structural image to the registered base, or its inverse. Framing does not
establish the field, its endpoint types, execution of the map, or a backend law. -/
structure ObjectField where
  object : String
  field : String
  parameters : Array Json

def ObjectField.encode (map : ObjectField) : Json :=
  Json.mkObj [("ctor", toJson "objectField"), ("args", Json.arr #[
    toJson map.object, toJson map.field, Json.arr map.parameters])]

def ObjectField.decode (json : Json) : Except String ObjectField := do
  unless (← json.getObjValAs? String "ctor") == "objectField" do
    throw "an object field requires the objectField envelope"
  let #[object, field, parameters] ← (← json.getObjVal? "args").getArr?
    | throw "an object field requires its object id, field and ordered parameters"
  let object ← object.getStr?
  if object.isEmpty then throw "an object field has no registered object id"
  let field ← field.getStr?
  unless #["inclusion", "constants", "presentation", "inversePresentation",
      "refinement", "inverseRefinement"].contains field do
    throw "an object field requires a published map field selector"
  return { object, field, parameters := ← parameters.getArr? }

/-- One endpoint of an independently retained complete arrow. This is object data;
the descriptor supplies neither a formal arrow nor an enumeration of its endpoint. -/
structure MorphismEndpoint where
  callable : Json
  source : Bool

def MorphismEndpoint.encode (endpoint : MorphismEndpoint) : Json :=
  Json.mkObj [("ctor", toJson "morphismEndpoint"),
    ("args", Json.arr #[endpoint.callable, toJson (if endpoint.source then "source" else "target")])]

def MorphismEndpoint.decode (json : Json) : Except String MorphismEndpoint := do
  unless (← json.getObjValAs? String "ctor") == "morphismEndpoint" do
    throw "a declared endpoint requires the morphismEndpoint envelope"
  let #[callable, selector] ← (← json.getObjVal? "args").getArr?
    | throw "a declared endpoint requires its complete callable and endpoint selector"
  let selector ← selector.getStr?
  unless selector == "source" || selector == "target" do
    throw "a declared endpoint selector must be source or target"
  return { callable, source := selector == "source" }

/-- A computational callable together with its complete actual endpoint descriptions.
These endpoints are compared with the independently selected request by its consumer;
parsing this record establishes no map law or mathematical equality. -/
structure TypedMap where
  source : Json
  target : Json
  callable : Json

def TypedMap.encode (map : TypedMap) : Json :=
  Json.mkObj [("ctor", toJson "typedMap"),
    ("args", Json.arr #[map.source, map.target, map.callable])]

def TypedMap.decode (json : Json) : Except String TypedMap := do
  unless (← json.getObjValAs? String "ctor") == "typedMap" do
    throw "a computational map requires the typedMap envelope"
  let args ← (← json.getObjVal? "args").getArr?
  let #[source, target, callable] := args
    | throw "a computational map requires its complete source, target and callable"
  return { source, target, callable }

/-- Actual image interfaces of the selected stage. Absence of both fields selects
the historical recipe framing. A forward reply may supply its own image endpoint;
that field alone does not assert that a separate object action ran. -/
structure LiftImages where
  sourceImage? : Option Json := none
  comparisonImage? : Option Json := none

def LiftImages.fields (images : LiftImages) : List (String × Json) :=
  (images.sourceImage?.toList.map fun data => ("sourceImage", data)) ++
    (images.comparisonImage?.toList.map fun data => ("comparisonImage", data))

/-- Validate the explicit metadata mode and its stage, without resolving typed
references or claiming that supplied data resulted from an execution. -/
def LiftImages.decode (json : Json) (outputCount : Nat) : Except String LiftImages := do
  let sourceImage? := (json.getObjVal? "sourceImage").toOption
  let comparisonImage? := (json.getObjVal? "comparisonImage").toOption
  if sourceImage? == some Json.null || comparisonImage? == some Json.null then
    throw "lift image metadata must contain data rather than null"
  if sourceImage?.isNone && comparisonImage?.isSome then
    throw "a comparison image requires the actual selected source image"
  if sourceImage?.isSome then
    if outputCount < 2 && comparisonImage?.isSome then
      throw "a comparison image is unavailable before the forward stage"
    if outputCount >= 3 && comparisonImage?.isNone then
      throw "the comparison image is required after the forward result"
  return { sourceImage?, comparisonImage? }

/-- Either complete source context for the four existing lift fields. The source
is an actual object when `originalArrow` is false, and a complete Arrow otherwise. -/
structure LiftInput extends LiftImages where
  originalArrow : Bool
  lift : String
  action : Json
  source : Json
  base : Json
  outputs : Array Json
  /-- All explicit non-proof arguments of the selected evidence declaration. -/
  parameters : Array Json := #[]

def LiftInput.encode (input : LiftInput) : Json :=
  Json.mkObj ([("ctor", toJson (if input.originalArrow then "liftInput" else "monoLiftInput")),
    ("parameters", Json.arr input.parameters),
    ("args", Json.arr #[toJson input.lift, input.action, input.source, input.base,
      Json.arr input.outputs])] ++ input.toLiftImages.fields)

/-- Check only public framing and field order. Mathematical endpoint types and
laws remain the independent caller's responsibility. -/
def LiftInput.decode (json : Json) (operation : String) : Except String LiftInput := do
  let tag ← json.getObjValAs? String "ctor"
  unless tag == "liftInput" || tag == "monoLiftInput" do
    throw "a lift request requires its declared complete source context"
  let #[identity, action, source, base, earlier] ← (← json.getObjVal? "args").getArr?
    | throw "a lift request requires id, action, source, base and preceding outputs"
  let lift ← identity.getStr?
  if lift.isEmpty then throw "a lift request requires its exact registered id"
  let outputs ← earlier.getArr?
  let order := #["obj", "hom", "forward", "backward"]
  let some index := order.findIdx? (fun field => operation == lift ++ "#" ++ field)
    | throw "the dispatched operation differs from the selected lift field"
  unless outputs.size == index do
    throw "the lift request omits or changes the actual preceding output prefix"
  let images ← LiftImages.decode json outputs.size
  let baseTag ← base.getObjValAs? String "ctor"
  unless (baseTag == "arrow" || baseTag == "subobject") &&
      (← base.getObjVal? "args" >>= Json.getArr?).size == 3 do
    throw "the lift request requires its complete base subobject"
  if tag == "liftInput" then
    unless (← source.getObjValAs? String "ctor") == "arrow" &&
        (← source.getObjVal? "args" >>= Json.getArr?).size == 3 do
      throw "the prescribed lift requires its complete original source Arrow"
    if let some image := images.sourceImage? then
      unless (← image.getObjValAs? String "ctor") == "arrow" &&
          (← image.getObjVal? "args" >>= Json.getArr?).size == 3 do
        throw "the prescribed source image requires its complete transported Arrow"
  let parameters ← match json.getObjVal? "parameters" with
    | .ok data => data.getArr?
    | .error _ =>
        if tag == "liftInput" then pure #[]
        else throw "an explicit lift request requires its ordered selection parameters"
  return { images with
    originalArrow := tag == "liftInput"
    lift, action, source, base, outputs, parameters }

/-- The separate universal-factor request retains all four actual lift outputs
and both input maps. The public record contains no proof or certificate field. -/
structure LiftFactorInput extends LiftImages where
  lift : String
  action : Json
  source : Json
  base : Json
  outputs : Array Json
  baseMap : TypedMap
  cone : TypedMap
  /-- Same selected evidence-family data arguments used for the four lift fields. -/
  parameters : Array Json := #[]

def LiftFactorInput.encode (input : LiftFactorInput) : Json :=
  Json.mkObj ([("ctor", toJson "liftFactorInput"), ("parameters", Json.arr input.parameters),
    ("args", Json.arr #[
    toJson input.lift, input.action, input.source, input.base, Json.arr input.outputs,
    input.baseMap.encode, input.cone.encode])] ++ input.toLiftImages.fields)

def LiftFactorInput.decode (json : Json) (operation : String) : Except String LiftFactorInput := do
  unless (← json.getObjValAs? String "ctor") == "liftFactorInput" do
    throw "a factor request requires its complete selected lift context"
  let #[identity, action, source, base, earlier, baseMap, cone] ←
      (← json.getObjVal? "args").getArr?
    | throw "a factor request requires seven ordered fields"
  let lift ← identity.getStr?
  unless !lift.isEmpty && operation == lift ++ "#factor" do
    throw "the dispatched factor differs from the selected lift"
  let outputs ← earlier.getArr?
  unless outputs.size == 4 do
    throw "a factor request requires exactly the four existing lift outputs"
  let images ← LiftImages.decode json outputs.size
  for output in outputs.extract 1 4 do discard <| TypedMap.decode output
  let baseTag ← base.getObjValAs? String "ctor"
  unless (baseTag == "arrow" || baseTag == "subobject") &&
      (← base.getObjVal? "args" >>= Json.getArr?).size == 3 do
    throw "a factor request requires its complete base subobject"
  return { images with
    lift
    action
    source
    base
    outputs
    parameters := (← (← json.getObjVal? "parameters").getArr?)
    baseMap := (← TypedMap.decode baseMap)
    cone := (← TypedMap.decode cone) }

/-- A cartesian arrow fixed by an accepted registered family-reindex action.
All selected declaration parameters, including the actual base map, remain ordered.
The descriptor supplies no cartesianness proof or choice of transport. -/
structure CartesianMap where
  reindex : String
  parameters : Array Json
  receiver : Json

def CartesianMap.encode (map : CartesianMap) : Json :=
  Json.mkObj [("ctor", toJson "cartesianMap"), ("args", Json.arr #[
    toJson map.reindex, Json.arr map.parameters, map.receiver])]

def CartesianMap.decode (json : Json) : Except String CartesianMap := do
  unless (← json.getObjValAs? String "ctor") == "cartesianMap" do
    throw "a cartesian arrow requires the cartesianMap envelope"
  let #[reindex, parameters, receiver] ← (← json.getObjVal? "args").getArr?
    | throw "a cartesian arrow requires its reindex action, ordered parameters and receiver"
  let reindex ← reindex.getStr?
  if reindex.isEmpty then throw "a cartesian arrow has no registered reindex action"
  return { reindex, parameters := ← parameters.getArr?, receiver }

def CartesianMap.address (map : CartesianMap) : String := map.reindex ++ "#cartesian"

/-- A data-port projection of a complete registered universal construction.
The index counts the accepted data constructor's non-Prop fields in declaration order;
it is not a diagram-object or cone-leg index. The full packet retains creation provenance. -/
structure ConstructionField where
  limit : String
  diagram : Json
  construction : Json
  index : Nat

def ConstructionField.encode (field : ConstructionField) : Json :=
  Json.mkObj [("ctor", toJson "constructionField"), ("args", Json.arr #[
    toJson field.limit, field.diagram, field.construction, toJson field.index])]

def ConstructionField.decode (json : Json) : Except String ConstructionField := do
  unless (← json.getObjValAs? String "ctor") == "constructionField" do
    throw "a construction data field requires the constructionField envelope"
  let #[limit, diagram, construction, index] ← (← json.getObjVal? "args").getArr?
    | throw "a construction data field requires its limit, diagram, complete packet and port index"
  let limit ← limit.getStr?
  if limit.isEmpty then throw "a construction data field has no registered limit id"
  return { limit, diagram, construction, index := ← index.getNat? }

/-- A selected category dictionary, identified by its registered declaration and every
ordered explicit parameter. The semantic caller checks the complete category structure;
this descriptor never selects a category from equality of object carriers. -/
structure CategoryParameter where
  category : String
  parameters : Array Json

def CategoryParameter.encode (parameter : CategoryParameter) : Json :=
  Json.mkObj [("ctor", toJson "category"), ("args", Json.arr #[
    toJson parameter.category, Json.arr parameter.parameters])]

def CategoryParameter.decode (json : Json) : Except String CategoryParameter := do
  unless (← json.getObjValAs? String "ctor") == "category" do
    throw "a selected category requires the category envelope"
  let #[category, parameters] ← (← json.getObjVal? "args").getArr?
    | throw "a selected category requires its registered id and ordered parameters"
  let category ← category.getStr?
  if category.isEmpty then throw "a selected category has no registered id"
  return { category, parameters := ← parameters.getArr? }

/-- An actual application of a registered category constructor, retaining all arguments.
The caller validates the accepted signature, semantics and complete selected category.
This representation does not require an additional named row for the resulting category. -/
structure ConstructedCategory where
  constructor : String
  arguments : Array Json

def ConstructedCategory.encode (category : ConstructedCategory) : Json :=
  Json.mkObj [("ctor", toJson "constructedCategory"), ("args", Json.arr #[
    toJson category.constructor, Json.arr category.arguments])]

def ConstructedCategory.decode (json : Json) : Except String ConstructedCategory := do
  unless (← json.getObjValAs? String "ctor") == "constructedCategory" do
    throw "a constructed category requires the constructedCategory envelope"
  let #[constructor, arguments] ← (← json.getObjVal? "args").getArr?
    | throw "a constructed category requires its registered constructor and ordered arguments"
  let constructor ← constructor.getStr?
  if constructor.isEmpty then throw "a constructed category has no registered constructor id"
  return { constructor, arguments := ← arguments.getArr? }

/-- A foundational projection action at a complete accepted constructed category.
The caller checks the actual constructor semantics and projection type. This is
action data for `map`, not a new registered operation or a projection theorem. -/
structure StructuredProjectionAction where
  category : Json
  field : String

def StructuredProjectionAction.encode (action : StructuredProjectionAction) : Json :=
  Json.mkObj [("ctor", toJson "structuredProjectionAction"), ("args", Json.arr #[
    action.category, toJson action.field])]

def StructuredProjectionAction.decode (json : Json) : Except String StructuredProjectionAction := do
  unless (← json.getObjValAs? String "ctor") == "structuredProjectionAction" do
    throw "a structured projection action requires the structuredProjectionAction envelope"
  let #[category, field] ← (← json.getObjVal? "args").getArr?
    | throw "a structured projection action requires its complete category and field"
  discard <| ConstructedCategory.decode category
  let field ← field.getStr?
  unless #["source", "target", "inclusion"].contains field do
    throw "a structured projection action requires source, target or inclusion"
  return { category, field }

/-- A selected registered functor with its complete ordered declaration parameters.
Its full formal source and target, including their category dictionaries, are checked
by the caller. This framing supplies no functor or category laws. -/
structure FunctorParameter where
  functor : String
  parameters : Array Json

def FunctorParameter.encode (parameter : FunctorParameter) : Json :=
  Json.mkObj [("ctor", toJson "functor"), ("args", Json.arr #[
    toJson parameter.functor, Json.arr parameter.parameters])]

def FunctorParameter.decode (json : Json) : Except String FunctorParameter := do
  unless (← json.getObjValAs? String "ctor") == "functor" do
    throw "a selected functor requires the functor envelope"
  let #[functor, parameters] ← (← json.getObjVal? "args").getArr?
    | throw "a selected functor requires its registered id and ordered parameters"
  let functor ← functor.getStr?
  if functor.isEmpty then throw "a selected functor has no registered id"
  return { functor, parameters := ← parameters.getArr? }

/-- The actual component of a registered natural transformation, at its complete
selected receiver. Inverse selection requires the registered invertibility property;
no computational field supplies that property or changes the component's endpoints. -/
structure CellComponent where
  cell : String
  parameters : Array Json
  receiver : Json
  inverse : Bool

def CellComponent.encode (component : CellComponent) : Json :=
  Json.mkObj [("ctor", toJson "cellComponent"), ("args", Json.arr #[
    toJson component.cell, Json.arr component.parameters, component.receiver,
    toJson component.inverse])]

def CellComponent.decode (json : Json) : Except String CellComponent := do
  unless (← json.getObjValAs? String "ctor") == "cellComponent" do
    throw "a natural component requires the cellComponent envelope"
  let #[cell, parameters, receiver, inverse] ← (← json.getObjVal? "args").getArr?
    | throw "a natural component requires its id, parameters, receiver and direction"
  let cell ← cell.getStr?
  if cell.isEmpty then throw "a natural component has no registered cell id"
  return { cell, parameters := ← parameters.getArr?, receiver, inverse := ← inverse.getBool? }

/-- A component induced through a complete ordered path of registered constructors.
The nested receiver has the derived constructed type, fixed by the formal caller. -/
structure ConstructedCellComponent where
  constructors : Array String
  component : CellComponent

def ConstructedCellComponent.address (value : ConstructedCellComponent) : String :=
  if value.constructors.isEmpty then value.component.cell ++ "#component"
  else "component:" ++ (Json.arr #[toJson value.component.cell, toJson value.constructors]).compress

def ConstructedCellComponent.encode (value : ConstructedCellComponent) : Json :=
  if value.constructors.isEmpty then value.component.encode
  else Json.mkObj [("ctor", toJson "constructedCellComponent"),
    ("args", Json.arr #[toJson value.constructors, value.component.encode])]

def ConstructedCellComponent.decode (json : Json) : Except String ConstructedCellComponent := do
  unless (← json.getObjValAs? String "ctor") == "constructedCellComponent" do
    throw "an induced component requires the constructedCellComponent envelope"
  let #[constructors, component] ← (← json.getObjVal? "args").getArr?
    | throw "an induced component requires its constructor path and complete component"
  let constructors ← (← constructors.getArr?).mapM Json.getStr?
  if constructors.isEmpty || constructors.any String.isEmpty then
    throw "an induced component requires a nonempty path of registered constructor ids"
  return { constructors, component := ← CellComponent.decode component }

/-- Complete source data of the actual `Core` object selected by a construction.
The surrounding declared functor fixes the ambient category, independently of data. -/
structure CoreObject where
  receiver : Json

def CoreObject.encode (object : CoreObject) : Json :=
  Json.mkObj [("ctor", toJson "coreObject"), ("args", Json.arr #[object.receiver])]

def CoreObject.decode (json : Json) : Except String CoreObject := do
  unless (← json.getObjValAs? String "ctor") == "coreObject" do
    throw "a core object requires the coreObject envelope"
  let #[receiver] ← (← json.getObjVal? "args").getArr?
    | throw "a core object requires one complete receiver"
  return { receiver }

/-- Both directed maps of an independently selected formal isomorphism, with its
ordered complete endpoints. Parsing retains data only; no inverse equation, map law,
or formal isomorphism is established by a backend's packet. -/
structure CoreIso where
  source : Json
  target : Json
  forward : Json
  backward : Json

def CoreIso.encode (comparison : CoreIso) : Json :=
  Json.mkObj [("ctor", toJson "coreIso"), ("args", Json.arr #[
    comparison.source, comparison.target, comparison.forward, comparison.backward])]

def CoreIso.decode (json : Json) : Except String CoreIso := do
  unless (← json.getObjValAs? String "ctor") == "coreIso" do
    throw "a core comparison requires the coreIso envelope"
  let #[source, target, forward, backward] ← (← json.getObjVal? "args").getArr?
    | throw "a core comparison requires both complete endpoints and both directions"
  return { source, target, forward, backward }

/-- Existing object-action envelope, also used for complete registered method
requests. Direct constructions use their ordered explicit parameters; methods use
ordered residual action descriptors followed by the complete method-functor descriptor.
The selected public operation determines the argument convention and input forms.
Its full dependent declaration determines parameters, source and target. -/
structure ConstructionInvocation where
  construction : String
  parameters : Array Json
  receiver : Json

def ConstructionInvocation.encode (request : ConstructionInvocation) : Json :=
  Json.mkObj [("ctor", toJson request.construction),
    ("args", Json.arr request.parameters), ("receiver", request.receiver)]

/-- Check object-action framing and the dispatched construction identity only.
The caller independently checks the registered signature and selected dictionaries. -/
def ConstructionInvocation.decode (construction : String) (json : Json) :
    Except String ConstructionInvocation := do
  if construction.isEmpty then throw "a construction invocation has no registered id"
  unless (← json.getObjValAs? String "ctor") == construction do
    throw "the construction invocation differs from the dispatched operation"
  let parameters ← (← json.getObjVal? "args").getArr?
  let receiver ← json.getObjVal? "receiver"
  return { construction, parameters, receiver }

/-- Validate the public identity grammar only. Registry membership and the actual
constructor's functorial action remain independent kernel checks. -/
partial def checkActionIdentity (identity : Json) : Except String Unit := do
  let fields ← identity.getObj?
  match fields.toList with
  | [("functor", .str id)] | [("classifierForget", .str id)] =>
      if id.isEmpty then throw "an action identity has an empty registered id"
  | [("constructorMap", .arr #[.str id, inner])] =>
      if id.isEmpty then throw "an action identity has an empty constructor id"
      checkActionIdentity inner
  | _ => throw "an action identity requires one complete published edge descriptor"

/-- Canonical computational address of a non-FunctorEntry edge. This encoder does
not admit an edge or confer mathematical meaning on its string identifiers. -/
def actionAddress (identity : Json) : Except String String := do
  checkActionIdentity identity
  if (identity.getObjVal? "functor").isOk then
    throw "a bare registered functor uses its own published operation address"
  return "action:" ++ identity.compress

def actionIdentity (address : String) : Except String Json := do
  unless address.startsWith "action:" do throw "a derived action requires its action address"
  let identity ← Json.parse (address.drop 7).toString
  unless (← actionAddress identity) == address do
    throw "a derived action address must use its canonical compact identity"
  return identity

/-- Read registration identity without removing any parameter from the request.
The complete original descriptor is retained by the invocation decoder. -/
partial def descriptorActionIdentity (descriptor : Json) : Except String Json := do
  let id ← descriptor.getObjValAs? String "ctor"
  let parameters ← (← descriptor.getObjVal? "args").getArr?
  if id == "classifierForget" then
    let #[.str classifier, .arr _] := parameters
      | throw "classifier forgetting requires its id and ordered actual parameters"
    if classifier.isEmpty then throw "classifier forgetting has an empty registered id"
    return Json.mkObj [("classifierForget", toJson classifier)]
  if id == "constructorMap" then
    let #[.str constructor, inner] := parameters
      | throw "a constructor action requires its constructor and complete inner action"
    if constructor.isEmpty then throw "a constructor action has an empty registered id"
    return Json.mkObj [("constructorMap", Json.arr #[toJson constructor,
      ← descriptorActionIdentity inner])]
  if id.isEmpty then throw "a functor action has an empty registered id"
  return Json.mkObj [("functor", toJson id)]

/-- Check the complete method envelope against the dispatched method and its
independently selected registered functor. Earlier descriptors retain the residual
actions in composition order; the final one is the complete method-functor application.
Parsing checks grammar and identity only. The kernel separately checks the full
selected route, declaration parameters, categories, result interface and live owners.
This decoder never interprets raw receiver data as a compatibility fallback. -/
def ConstructionInvocation.decodeMethod (methodId functorId : String) (json : Json) :
    Except String ConstructionInvocation := do
  if functorId.isEmpty then throw "a method invocation has no selected functor id"
  let request ← ConstructionInvocation.decode methodId json
  let some finalAction := request.parameters.back?
    | throw "a method invocation requires its final complete functor descriptor"
  for descriptor in request.parameters do
    discard <| descriptorActionIdentity descriptor
  unless (← descriptorActionIdentity finalAction) == Json.mkObj [("functor", toJson functorId)] do
    throw "the method invocation differs from its selected registered functor"
  return request

/-- Frame the object action at its canonical edge address, preserving its complete
nested parameter descriptor and actual receiver. -/
def ConstructionInvocation.decodeAction (address : String) (json : Json) :
    Except String ConstructionInvocation := do
  let identity ← actionIdentity address
  let request ← ConstructionInvocation.decode address json
  let #[action] := request.parameters
    | throw "a derived object action requires its one complete action descriptor"
  unless (← descriptorActionIdentity action) == identity do
    throw "the complete action descriptor differs from the registered address"
  return request

/-- Complete computational context for an independently admitted formal point. The original
data are retained, not replaced by a formal representative or checked as an admission proof. -/
structure AdmittedPoint where
  object : String
  parameters : Array Json
  domain : Json
  source : Json
  target : Json
  argument : Json

def AdmittedPoint.encode (point : AdmittedPoint) : Json :=
  Json.mkObj [("ctor", toJson "admittedPoint"), ("args", Json.arr #[
    toJson point.object, Json.arr point.parameters, point.domain, point.source,
    point.target, point.argument])]

def AdmittedPoint.decode (json : Json) : Except String AdmittedPoint := do
  unless (← json.getObjValAs? String "ctor") == "admittedPoint" do
    throw "an admitted point requires its declared envelope"
  let args ← (← json.getObjVal? "args").getArr?
  let #[object, parameters, domain, source, target, argument] := args
    | throw "an admitted point requires all six ordered fields"
  let object ← object.getStr?
  if object.isEmpty then throw "an admitted point has no published object id"
  let parameters ← parameters.getArr?
  return { object, parameters, domain, source, target, argument }

/-- Original data retained under an independently checked single-data-field constrained
structure. The formal caller checks the closed nonrecursive one-constructor, no-index
schema, its data-field type and all proof fields; no proof is a field of this record. -/
structure ConstrainedPoint where
  constructor : String
  domain : Json
  /-- Complete public descriptor of the original data-field type. -/
  source : Json
  target : Json
  argument : Json

def ConstrainedPoint.encode (point : ConstrainedPoint) : Json :=
  Json.mkObj [("ctor", toJson "constrainedPoint"), ("args", Json.arr #[
    toJson point.constructor, point.domain, point.source, point.target, point.argument])]

/-- Check public framing only. The kernel retains the original computational data and
their owners, while the actual formal proof remains in the checked semantic term. -/
def ConstrainedPoint.decode (json : Json) : Except String ConstrainedPoint := do
  unless (← json.getObjValAs? String "ctor") == "constrainedPoint" do
    throw "a constrained point requires the constrainedPoint envelope"
  let #[constructor, domain, source, target, argument] ← (← json.getObjVal? "args").getArr?
    | throw "a constrained point requires all five ordered fields"
  let constructor ← constructor.getStr?
  if constructor.isEmpty then throw "a constrained point has no actual constructor name"
  return { constructor, domain, source, target, argument }

/-- A released arrow applied to an already selected generalized point. All descriptors come
from the formal request; none is inferred from the reply or from a backend class. -/
structure PointInvocation where
  operation : String
  parameters : Array Json
  arrow : Json
  domain : Json
  source : Json
  target : Json
  argument : Json

/-- The ordinary port operation remains the released operation id. `apply` is a request
encoding, not a new mathematical operation or an implementation-selected endpoint. -/
def PointInvocation.encode (request : PointInvocation) : Json :=
  Json.mkObj [("ctor", toJson "apply"), ("args", Json.arr #[
    toJson request.operation, Json.arr request.parameters, request.arrow,
    request.domain, request.source, request.target, request.argument])]

/-- Parse framing only. The kernel separately fixes and checks the released signature and
selected descriptors before dispatch. Parsing never establishes a mathematical law. -/
def PointInvocation.decode (json : Json) : Except String PointInvocation := do
  unless (← json.getObjValAs? String "ctor") == "apply" do
    throw "a point invocation requires the apply envelope"
  let args ← (← json.getObjVal? "args").getArr?
  let #[operation, parameters, arrow, domain, source, target, argument] := args
    | throw "a point invocation requires all seven ordered fields"
  let operation ← operation.getStr?
  if operation.isEmpty then throw "a point invocation has no released operation id"
  let parameters ← parameters.getArr?
  return { operation, parameters, arrow, domain, source, target, argument }

/-- Frame the morphism action of one registered functor using the existing `apply`,
`map` and `typedMap` records. Preserve the complete invocation, including both actual
image endpoints and the original generalized argument. The caller separately checks
the formal signature, selected images and live owners; this parser supplies no laws. -/
def PointInvocation.decodeFunctorMap (functorId : String) (json : Json) :
    Except String PointInvocation := do
  if functorId.isEmpty then throw "a functor map invocation has no registered id"
  let request ← PointInvocation.decode json
  unless request.operation == functorId ++ "#map" do
    throw "the functor map invocation differs from the dispatched operation"
  unless (← request.arrow.getObjValAs? String "ctor") == "map" do
    throw "a functor map invocation requires its selected map action"
  let #[action, arrow] ← (← request.arrow.getObjVal? "args").getArr?
    | throw "a functor map action requires its selected functor and complete source arrow"
  unless (← action.getObjValAs? String "ctor") == functorId do
    throw "the functor map action differs from the dispatched functor"
  let parameters ← (← action.getObjVal? "args").getArr?
  unless parameters == request.parameters do
    throw "the functor map action changed its ordered invocation parameters"
  discard <| TypedMap.decode arrow
  return request

/-- Frame the morphism action of a non-FunctorEntry edge. The two action
occurrences are exact data, including every ordered nested parameter packet. -/
def PointInvocation.decodeActionMap (address : String) (json : Json) :
    Except String PointInvocation := do
  let identity ← actionIdentity address
  let request ← PointInvocation.decode json
  unless request.operation == address ++ "#map" do
    throw "the derived map invocation differs from the dispatched operation"
  unless (← request.arrow.getObjValAs? String "ctor") == "map" do
    throw "a derived map invocation requires its selected map action"
  let #[action, arrow] ← (← request.arrow.getObjVal? "args").getArr?
    | throw "a derived map action requires its complete action and source arrow"
  unless request.parameters == #[action] do
    throw "the derived map action changed its complete invocation descriptor"
  unless (← descriptorActionIdentity action) == identity do
    throw "the complete action descriptor differs from the registered address"
  discard <| TypedMap.decode arrow
  return request

/-- Apply a registered presentation comparison in its independently selected direction.
The enclosing port request's operation id names the comparison; this packet retains
its full parameters, actual ordered endpoints and original point data. -/
structure PresentationInvocation where
  parameters : Array Json
  inverse : Bool
  source : Json
  target : Json
  argument : Json

def PresentationInvocation.encode (request : PresentationInvocation) : Json :=
  Json.mkObj [("ctor", toJson "presentationApply"), ("args", Json.arr #[
    Json.arr request.parameters, toJson request.inverse, request.source,
    request.target, request.argument])]

/-- Parse the existing comparison-application framing only. The caller separately
checks the enclosing operation, selected parameters and fixed endpoint types. -/
def PresentationInvocation.decode (json : Json) : Except String PresentationInvocation := do
  unless (← json.getObjValAs? String "ctor") == "presentationApply" do
    throw "a comparison invocation requires the presentationApply envelope"
  let args ← (← json.getObjVal? "args").getArr?
  let #[parameters, inverse, source, target, argument] := args
    | throw "a comparison invocation requires all five ordered fields"
  let parameters ← parameters.getArr?
  let inverse ← inverse.getBool?
  return { parameters, inverse, source, target, argument }

/-- Computational data associated with the request's independently fixed result. An opaque
token is meaningful only to the existing connection that returned it. Its owner and session
are retained by the kernel, never chosen by this token or serialized as semantic authority. -/
inductive ComputationalValue where
  | inline (data : Json)
  | opaque (token : String)

def ComputationalValue.encode : ComputationalValue → Json
  | .inline data => Json.mkObj [("ctor", toJson "valueData"), ("args", Json.arr #[data])]
  | .opaque token => Json.mkObj [("ctor", toJson "opaqueData"),
      ("args", Json.arr #[toJson token])]

/-- Check the computational envelope, without decoding its data into a law-bearing Lean
value. Required inline components are checked against the published result contract by the
consumer. An opaque value is subsequently consumed through that same declared interface. -/
def ComputationalValue.decode (json : Json) : Except String ComputationalValue := do
  let tag ← json.getObjValAs? String "ctor"
  let args ← (← json.getObjVal? "args").getArr?
  let #[data] := args | throw "a computational value requires exactly one data field"
  match tag with
  | "valueData" => return .inline data
  | "opaqueData" =>
      let token ← data.getStr?
      if token.isEmpty then throw "an opaque computational value has no token"
      return .opaque token
  | _ => throw "the reply has no declared computational value envelope"

/-- Require exactly the fields of a computational control record. No ignored field
may smuggle a backend selection, owner, result type or mathematical assertion. -/
def checkServiceFields (names : Array String) (json : Json) : Except String Unit := do
  let fields ← json.getObj?
  unless fields.toList.length == names.size &&
      fields.toList.all (fun field => names.contains field.1) do
    throw "a computation control record has unexpected or missing fields"

/-- Reference one actual node result in the surrounding deferred computation only. -/
def resultRef (index : Nat) : Json :=
  Json.mkObj [("ctor", toJson "resultRef"), ("args", Json.arr #[toJson index])]

/-- Ordinary JSON is `none`; a malformed reserved reference is an error, not data. -/
def resultRefIndex? (json : Json) : Except String (Option Nat) := do
  if (json.getObjValAs? String "ctor").toOption != some "resultRef" then return none
  checkServiceFields #["ctor", "args"] json
  let #[index] ← (← json.getObjVal? "args").getArr?
    | throw "a result reference requires exactly one node index"
  return some (← index.getNat?)

/-- Check reference scope throughout a request/result template. This function does
not substitute JSON for typed results or decide any operation's result interface. -/
partial def validateResultRefs (bound : Nat) (json : Json) : Except String Unit := do
  if (json.getObjValAs? String "ctor").toOption == some "deferredData" then
    throw "a deferred computation is a service reply, not a template data constructor"
  if let some index ← resultRefIndex? json then
    unless index < bound do throw "a result reference is self, forward or outside its program"
    return
  match json with
  | .arr values => for value in values do validateResultRefs bound value
  | .obj fields => for (_, value) in fields.toList do validateResultRefs bound value
  | _ => pure ()

/-- One call through an existing published computational interface. The kernel
selects implementations and derives the result interface from the formal declaration. -/
structure DeferredCall where
  operation : String
  input : String
  arguments : Json

def DeferredCall.encode (call : DeferredCall) : Json :=
  Json.mkObj [("op", toJson call.operation), ("input", toJson call.input),
    ("args", call.arguments)]

def DeferredCall.decode (json : Json) : Except String DeferredCall := do
  checkServiceFields #["op", "input", "args"] json
  let operation ← json.getObjValAs? String "op"
  let input ← json.getObjValAs? String "input"
  if operation.isEmpty || input.isEmpty then
    throw "a deferred call requires its published operation and input addresses"
  return { operation, input, arguments := ← json.getObjVal? "args" }

/-- An ordered computational dependency graph. The final template remains data for
the original independently fixed result contract; it supplies no equality or proof. -/
structure DeferredData where
  calls : Array DeferredCall
  result : Json

def DeferredData.encode (program : DeferredData) : Json :=
  Json.mkObj [("ctor", toJson "deferredData"), ("args", Json.arr #[
    Json.arr (program.calls.map DeferredCall.encode), program.result])]

/-- Check control framing and backward-only references. Exact declaration, role,
parameter, endpoint and owner checks are performed after resolving actual node Wires. -/
def DeferredData.decode (json : Json) : Except String DeferredData := do
  checkServiceFields #["ctor", "args"] json
  unless (← json.getObjValAs? String "ctor") == "deferredData" do
    throw "a deferred computation requires the deferredData envelope"
  let #[calls, result] ← (← json.getObjVal? "args").getArr?
    | throw "a deferred computation requires its ordered calls and final result template"
  let calls ← (← calls.getArr?).mapM DeferredCall.decode
  for (call, index) in calls.zipIdx do
    validateResultRefs index call.arguments
  validateResultRefs calls.size result
  return { calls, result }

/-- Why a backend call failed. -/
inductive PortError
  /-- The backend is not installed or cannot start. -/
  | unavailable (backend reason : String)
  /-- The established connection ended before completing the requested exchange. -/
  | disconnected (message : String)
  /-- The program broke the protocol. -/
  | protocol (message : String)
  /-- The backend reported an error for a request. -/
  | backend (kind message : String)
  /-- The selected backend has no computation for the dispatched public operation. -/
  | unsupported (operation : String)
  deriving Repr, Inhabited

/-- The stratum of a port failure. A backend that cannot start or that reports an error is
unavailable. An answer outside the protocol is malformed. -/
def PortError.stratum : PortError → Stratum
  | .unavailable .. | .disconnected .. | .backend .. => .unavailable
  | .protocol _ => .malformed
  | .unsupported _ => .noImplementation

def PortError.render : PortError → String
  | .unavailable b r => s!"{b} is unavailable: {r}"
  | .disconnected message => s!"backend connection lost: {message}"
  | .protocol m => s!"protocol error: {m}"
  | .backend k m => s!"backend error ({k}): {m}"
  | .unsupported operation => s!"the backend has no implementation of {operation}"

/-- What a program announces. Nothing here is consulted. -/
structure Ready where
  backend : String
  backendVersion : String
  capabilities : Array String

abbrev Stdio : IO.Process.StdioConfig := { stdin := .piped, stdout := .piped, stderr := .inherit }

/-- A connection to a started program. -/
structure Conn where
  child : IO.Process.Child Stdio
  ready : Ready
  nextId : IO.Ref Nat

def writeFrame (h : IO.FS.Handle) (j : Json) : IO Unit := do
  let bytes := j.compress.toUTF8
  h.putStr s!"{bytes.size}\n"
  h.write bytes
  h.flush

partial def readExact (h : IO.FS.Handle) (n : Nat) (acc : ByteArray) :
    IO (Option ByteArray) := do
  if acc.size ≥ n then return some acc
  let chunk ← h.read (USize.ofNat (n - acc.size))
  if chunk.size == 0 then return none
  readExact h n (acc ++ chunk)

def readFrame (h : IO.FS.Handle) : IO (Except PortError Json) := do
  try
    let line ← h.getLine
    if line.isEmpty then return .error (.disconnected "EOF before a reply frame")
    unless line.endsWith "\n" do
      return .error (.disconnected "EOF inside the reply frame length")
    let header := line.dropEnd 1 |>.toString
    unless !header.isEmpty && header.toList.all Char.isDigit do
      return .error (.protocol s!"bad frame length {repr line}")
    let some n := header.toNat?
      | return .error (.protocol s!"bad frame length {repr line}")
    let some bytes ← readExact h n .empty
      | return .error (.disconnected s!"EOF mid-frame (wanted {n} bytes)")
    let some payload := String.fromUTF8? bytes | return .error (.protocol "frame is not UTF-8")
    return (Json.parse payload).mapError fun e => .protocol s!"bad JSON frame: {e}"
  catch e => return .error (.disconnected s!"cannot read from the program: {e}")

def field (j : Json) (k : String) : Except PortError Json :=
  (j.getObjVal? k).mapError fun _ => .protocol s!"field '{k}' missing in {j.compress}"

def str (j : Json) (k : String) : Except PortError String := do
  (← field j k).getStr?.mapError fun _ => .protocol s!"field '{k}' is not a string"

def readyOf (j : Json) : Except PortError Ready := do
  unless (← str j "op") == "ready" do throw (.protocol s!"expected a ready frame: {j.compress}")
  let caps ← (← field j "capabilities").getArr?.mapError fun _ =>
    .protocol "capabilities is not an array"
  return { backend := ← str j "backend", backendVersion := ← str j "backend_version"
           capabilities := ← caps.mapM fun c => c.getStr?.mapError fun _ =>
             .protocol "a capability is not a string" }

/-- Kill a program and reap it. Nothing it does on the way out is waited on or believed. -/
def abort (child : IO.Process.Child Stdio) : IO Unit := do
  try child.kill catch _ => pure ()
  try discard child.wait catch _ => pure ()

/-- Close the program's input (its shutdown signal) and reap it. -/
def stop (c : Conn) : IO Unit := do
  let (_stdin, child) ← c.child.takeStdin
  try discard child.wait catch _ => pure ()

/-- The name of this package, whose `python/` holds the port's reference implementation. -/
def contractPackage : String := "cas_leaf_contracts"

/-- Resolve the actual Lake package directory, including a configured packages directory,
path dependencies and subdirectories. An explicit public-contract checkout can be supplied
for an externally overridden dependency through `CAS_LEAF_CONTRACT_PATH`. -/
def packageDir (package : String) : IO System.FilePath := do
  if package == contractPackage then
    if let some path ← IO.getEnv "CAS_LEAF_CONTRACT_PATH" then
      return path
  let manifestPath : System.FilePath := "lake-manifest.json"
  if ← manifestPath.pathExists then
    let .ok manifest := Json.parse (← IO.FS.readFile manifestPath)
      | throw <| IO.userError "cannot read the Lake package manifest"
    if (manifest.getObjValAs? String "name").toOption == some package then return "."
    if let .ok entries := (manifest.getObjVal? "packages").bind (·.getArr?) then
      if let some entry := entries.find? fun entry =>
          (entry.getObjValAs? String "name").toOption == some package then
        if let .ok path := entry.getObjValAs? String "dir" then return path
        let directory : System.FilePath :=
          (manifest.getObjValAs? String "packagesDir").toOption.getD ".lake/packages"
        let path := directory / package
        return match (entry.getObjValAs? String "subDir").toOption with
          | some subdirectory => path / subdirectory
          | none => path
  let dependency : System.FilePath := ".lake" / "packages" / package
  if ← dependency.pathExists then return dependency
  throw <| IO.userError s!"Lake package {package} is absent from the current workspace"

/-- Send one request and read its answer's value: untrusted JSON, which the kernel decodes in the
operation's result form or rejects. -/
def call (c : Conn) (op : String) (args : Json) : IO (Except PortError Json) := do
  let id ← c.nextId.modifyGet fun n => (n, n + 1)
  try writeFrame c.child.stdin (Json.mkObj [("request_id", toJson id), ("op", op), ("args", args)])
  catch e => return .error (.disconnected s!"cannot send {op}: {e}")
  let reply? ← readFrame c.child.stdout
  return do
    let reply ← reply?
    unless (reply.getObjValAs? Nat "request_id").toOption == some id do
      throw (.protocol s!"the reply does not answer request {id}")
    match ← str reply "status" with
    | "ok" => field reply "value"
    | "error" => throw (.backend (← str reply "kind") (← str reply "message"))
    | "unsupported" =>
        unless (← str reply "op") == op do
          throw (.protocol "the unsupported reply names a different operation")
        throw (.unsupported op)
    | status => throw (.protocol s!"{c.ready.backend} answered {op} with status {status}")

end CasCatalogue.Backend
