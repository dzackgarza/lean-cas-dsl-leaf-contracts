# Contributing to the leaf contract

The [constitution](.specify/memory/constitution.md) governs. The public typed
contract is established and frozen with the first actual category leaf; new
implementation code is statically typed, and no provider language is required. Each policy below has a stable
identifier, a class of contribution, a defective contribution and its replacement. A new lesson
gets the next free identifier in its category. Identifiers are never reused.

## Protocol (PRO)

**PRO001 — One protocol, no legacy form (RC8).** Defective: a document keeps a "legacy recipe
framing" or a raw receiver form beside the current form, or a decoder accepts a v1 `ready`
frame. Replacement: the current form only; the old form, its decoder and its examples are
deleted in the same change.

**PRO002 — Unknown fields are malformed (RC8).** Defective: a parser ignores an extra field such
as `priority` or `timeout`, or gives a missing array the default `[]`. Replacement: the parser
rejects the frame or manifest as malformed and names the field.

**PRO003 — Negotiation is not a feature (RC4, RC13).** Defective: a change claims that suspension
works because the `ready` frame lists `suspend-resume/2`. Replacement: a contract test drives a
real suspension and resume between a leaf process and the protocol peer.

**PRO004 — Reserved constructors belong to the kernel (RC4).** Defective: a leaf reply contains
`{"ctor":"noImplementation",...}` and the SDK sends it. Replacement: the SDK rejects the reply
before it is written; only the kernel writes that constructor, in a resume slot.

## Catalogue (CAT)

**CAT001 — Generated files are generated (RC3, RC10).** Defective: a hand edit of
`api/declared-ports.json`, or a prose table that restates catalogue rows. Replacement: a change
to the exporter, a regeneration with `just export-api`, and a link to the generated row.

**CAT002 — No route rule in the contract (RC5, RC6).** Defective: a document says that an
inherited operation uses the nearest binding, or the shortest route. Replacement: selection is
the kernel's (C6 agreement or a declared preferred route); the document links that rule.

**CAT003 — No computation in validation (RC4).** Defective: an admission rule for a literal
requires the contract or the kernel to compute a greatest common divisor. Replacement:
admission checks layout, scope and owner; a computed condition is a published operation that a
leaf computes.

## Tests (TST)

**TST001 — Real processes, real frames (RC13).** Defective: a test calls a handler function
directly, or replaces the framed connection with an in-memory stub. Replacement: the test starts
the leaf process and the protocol peer and exchanges length-framed JSON over their pipes.

**TST002 — Measure actual work (RC17, RC18).** Defective: logging and timing
records become prerequisites to mathematical or contract delivery. Replacement:
keep useful raw logs outside Git and compact evidence-backed measurements of
actual costs.

## Documents (DOC)

**DOC001 — State the present rule (RC1).** Defective: a document explains how an earlier form
came to be replaced. Replacement: the document states the present rule; git history keeps the
earlier form.
