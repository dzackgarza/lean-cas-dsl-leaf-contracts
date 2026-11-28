> **Planning migration — Spec Kit and itree**
>
> Select the work-unit issue with itree. Use Spec Kit to plan and execute the work.
> The issue body and comments hold the current plan, tasks, progress and evidence.
> Earlier instructions that assign this work to vault cards or a separate task list
> identify records to migrate. Match each obligation to its owning issue. Preserve
> task IDs, order, prerequisites, acceptance criteria and evidence. Verify the transfer
> on the issue before retiring the old tracker. An open obligation stays open.

# Typed computational contract

Read this repository's [constitution](.specify/memory/constitution.md) and the
[cas-dsl kernel constitution](https://github.com/dzackgarza/cas-dsl/blob/main/.specify/memory/constitution.md).
They govern every feature and implementation plan. INTENT.md is historical
source material, not a competing specification.

## Purpose

This repository publishes the language-neutral typed boundary between the
one generic Lean kernel and computational category implementations. A leaf
**is a category implementation**; a registration is one of its ports, not a
leaf. An executable may implement multiple categories. lean-categories owns
all mathematical declarations and their meanings. cas-dsl owns generic
selection, checked execution and independent acceptance. This repository
owns the concrete invocation, data, failure and lifetime protocol. The
published interface must suffice to implement a category without reading
kernel source or its independent acceptance corpus.

## Invariants

- Generate the category interface from actual accepted typed mathematical
  declarations. Do not define mathematical objects, types, operation meanings,
  domain rules or structural routes in this repository or an SDK.
- Establish and freeze the public contract with a real first category
  implementation before dependent versions rely on it. Develop the common
  kernel and category implementations concurrently. The checked Lean runtime
  works independently of surface elaboration.
- Use statically typed implementation code: Lean and Rust under the current
  plan. The protocol itself is language-neutral. Existing Python bindings
  and providers are not a required host language. Do not duplicate the
  contract or invent a private protocol for an engine.
- Each request identifies the exact selected operation/input form, actual
  dependent arguments and realization. Preserve selected maps, parameters,
  handles, ownership and failures. Admission of wire data is not a proof
  of mathematical correctness. A leaf does not define the correctness of
  its outputs.
- A registration realizes a declared operation on its admitted domain.
  No missing result or unspecified default stands in for the required
  value. Authorized formal discharge is separate from computation.
- Resolve interface deficiencies at the actual owner without weakening
  the mathematics. A leaf cannot privately change the contract to fit an
  engine. Independent authorship concerns definitions and acceptance, not
  credential or contributor isolation.
- The contract's tests use its actual codecs, framed connections and
  processes. They establish protocol behavior, not the correctness of
  computed mathematical answers. Reuse standard collections and established
  algorithms; keep useful raw logs out of Git and feedback focused.

Use the [shared research container](https://github.com/dzackgarza/ai-review-ci/blob/main/SAGE-CONTAINER.md#use-the-image),
compatible published dependencies, the active Spec Kit work order and
[CONTRIBUTING.md](CONTRIBUTING.md). Follow the actual categorical and contract
dependencies, not a kernel-first waterfall. Publish a tested compatible
contract revision; consumers pin it. No new orchestration or approval
machinery is required.
