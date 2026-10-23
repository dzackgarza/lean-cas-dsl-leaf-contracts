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

## The wire encoding of inputs and answers

The kernel's codec (`CasCatalogue.Codec`) fixes one structural encoding, derived from each form's
inductive type; a leaf reads and writes exactly this, and nothing else:

* an input object is a named object of the catalogue at its parameters,
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
  (`Mˣ ↪ M`) or its `constants` `R → R[[t]]`, is
  `{"ctor":"objectField","args":[<object id>,<field>,[<explicit parameters>]]}`; its endpoints are
  the ones the field's declaration gives at those parameters;
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
  category (`"input": "cat.sets"`) and sent as Mathlib's standard constructor of its shape with
  its explicit arguments, `{"ctor": "pair", "args": [X, Y]}` or
  `{"ctor": "cospan", "args": [f, g]}`, objects and arrows in their own encodings.
  A retained parallel-arrow diagram is `{"ctor":"parallelPair","args":[f,g]}`.
  Its cone or cocone has one defining arrow, so the reply is respectively
  `{"ctor":"cone","args":[<apex>,<inclusion>]}` or
  `{"ctor":"cocone","args":[<apex>,<projection>]}`. The two arrows in the request
  are retained exactly, including a registered trivial or zero arrow where the
  mathematical declaration specifies one; a shape label does not replace an arrow.

A registered functor's object action receives
`{"ctor": <functor id>, "args": [<ordered explicit declaration arguments>],
"receiver": <source object data>}`. The registered declaration determines the argument
types, source and target, including dependent parameters. The kernel checks those types and
endpoints; a backend cannot choose the functor or its parameters. The result is decoded in
the declared target form.

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

A registered subobject lift's public `MonoLiftComputation` has four callable fields:
`obj`, `hom`, `forward`, and `backward`. Their concrete port addresses are
`<lift id>#obj`, `<lift id>#hom`, `<lift id>#forward`, and `<lift id>#backward`, each
registered on `<lift id>#input`. These addresses expose only the published fields of
`LiftEntry.computation`; they create no mathematical operations or laws. A request is
`{"ctor":"liftInput","args":[<exact lift id>,<selected inner action descriptor>,
<complete source Arrow>,<current complete base subobject>,[<earlier actual outputs>]]}`.
The field order is fixed. `obj` sees an empty output prefix; `hom`, `forward`, and
`backward` see respectively one, two, and three actual preceding outputs. The full
selected action parameters, original Arrow endpoints and map, actual base apex and
inclusion, and session ownership survive every request. No reply chooses the lift.

The object reply is ordinary object data. Each map reply is
`{"ctor":"typedMap","args":[<actual domain data>,<actual codomain data>,<callable data>]}`.
For object output `O`, source Arrow `X → Y`, and base subobject `K → U(X)`, the map
endpoints are `O → X`, `U(O) → K`, and `K → U(O)`, in that order. `U(O)` uses the
complete selected inner action descriptor applied to the actual object output. Callable
data may be opaque on infinite carriers; it is not enumerated or converted to a Lean
morphism. Finite graphs use their actual domain and codomain descriptors. Missing fields
or incompatible declared endpoints are malformed. Well-framed mathematically wrong
objects or maps remain wrong data, to be tested by the independent permanent assertions;
no inverse, monicity, factorization or universal-property proof is requested from a leaf.

The kernel encodes a completed prescribed lift for subsequent computations as
`{"ctor":"liftedSubobject","args":[<original complete base subobject reply>,
<complete original source Arrow>,[<prescribed lift ids in route order>],
[<completed steps in route order>]]}`. Each step is
`{"ctor":"liftStep","args":[<exact lift id>,<selected inner action descriptor>,
<complete source Arrow for this step>,<actual base subobject for this step>,
[<object output>,<typed inclusion output>,<typed forward output>,<typed backward output>]]}`.
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
<exact source descriptor>,<exact target descriptor>,<input point data>]}`. The reply is an
`element` envelope at the exact target. The kernel checks its public framing against the
independently selected target and retains its actual computational data for subsequent
operations. This structural check does not establish the mathematical correctness of the
returned value; independent acceptance compares the observed computation with its meaning.

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
is authoritative for which concrete registration addresses exist.

An independently admitted point retains its original computational data as
`{"ctor":"admittedPoint","args":[<published object id>,[<full ordered parameters>],
<original generalized domain>,<original target object>,<selected admitted target>,
<actual original point data>]}`. The kernel fixes the category and the actual public
admission declaration, checks the original and admitted formal endpoints, and keeps the
formal admission evidence on the interpretation side. The wrapper supplies no proof.
Computations consume the original point data under the selected target's interface;
they do not substitute the canonical admitted formal value or certify backend membership.
Opaque data keep their original owning connection through the wrapper.

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
the descriptor or the returned data.

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

A category-wide registration uses its registered category id as `input` and accepts the same
complete public representation of values in that exact category. For a limit this is its
diagram; for a method, functor or other applicable operation it is its complete actual input
value. Structural transport is fixed before dispatch. Exact-form and category-wide
registrations have equal standing: overlapping applicable registrations are ambiguous, with
no implicit specialization order.

An answer is a value of the operation's declared result form in this encoding. The answer of a
limit is its cone, `{"ctor": "cone", "args": [<apex>, <leg>, ...]}`, and of a colimit its cocone,
`{"ctor": "cocone", "args": [<apex>, <leg>, ...]}`: the apex a value of a registered form of the
category (a named object at its parameters), each leg a morphism. The kernel decodes every answer
against its declared computational data form, retaining every required field and exact map
endpoint, or rejects it as malformed. It does not build a formal cone from the returned data:
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

/-- Why a backend call failed. -/
inductive PortError
  /-- The backend is not installed or cannot start. -/
  | unavailable (backend reason : String)
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
  | .unavailable .. | .backend .. => .unavailable
  | .protocol _ => .malformed
  | .unsupported _ => .noImplementation

def PortError.render : PortError → String
  | .unavailable b r => s!"{b} is unavailable: {r}"
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
    let header := line.dropEnd 1 |>.toString
    unless line.endsWith "\n" && !header.isEmpty && header.toList.all Char.isDigit do
      return .error (.protocol s!"bad frame length {repr line}")
    let some n := header.toNat?
      | return .error (.protocol s!"bad frame length {repr line}")
    let some bytes ← readExact h n .empty
      | return .error (.protocol s!"EOF mid-frame (wanted {n} bytes)")
    let some payload := String.fromUTF8? bytes | return .error (.protocol "frame is not UTF-8")
    return (Json.parse payload).mapError fun e => .protocol s!"bad JSON frame: {e}"
  catch e => return .error (.protocol s!"cannot read from the program: {e}")

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
  catch e => return .error (.protocol s!"cannot send {op}: {e}")
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
