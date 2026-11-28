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

## Build the interface a leaf author uses

- Generate the actual category-version interfaces from accepted typed
  mathematical declarations, with the complete inputs, results and registration
  addresses needed to bind their native engine calls.
- Supply reusable language bindings for the real engines being integrated.
  A binding decodes arguments, resolves live handles, dispatches registered
  handlers, encodes complete results, and manages invocation and release.
  Reuse the existing Python binding for Sage; provide other bindings where
  actual integrations need them. Keep the normative contract typed and the
  implementation languages of leaves independent.
- A leaf author should supply the existing CAS routines and only the
  necessary conversions. Improve shared codecs, invocation and handle support
  whenever ordinary engine calls require redundant glue.
- Carry the exact selected operation/input form, arguments and realization;
  preserve the actual maps, parameters, handles and outcomes. The Lean kernel
  supplies mathematical selection and composition.
- Establish and freeze the contract with actual first-category execution,
  including continued use of results. Exercise real codecs and connections
  in the contract tests, and leave mathematical acceptance to the independent
  kernel consumer.

Use the [shared research container](https://github.com/dzackgarza/ai-review-ci/blob/main/SAGE-CONTAINER.md#use-the-image),
compatible published dependencies, the active Spec Kit work order and
[CONTRIBUTING.md](CONTRIBUTING.md). Follow the actual categorical and contract
dependencies, not a kernel-first waterfall. Publish a tested compatible
contract revision; consumers pin it. No new orchestration or approval
machinery is required.
