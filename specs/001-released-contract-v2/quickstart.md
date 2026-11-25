# Quickstart validation: Released contract, protocol 2

Run in the research container from a checkout of this repository. No lean-cas-dsl checkout is
needed.

## Setup (explicit, outside the edit loop)

```bash
just setup        # uv sync --frozen; lake build cas-peer
```

## Tier 1

```bash
just test         # uv run --frozen pytest tests/contract
```

Expected: every test in the [plan's contract-test table](plan.md#contract-tests) passes; one new
file under `tests/logs/`; one new line per test in `tests/timing/records.jsonl`.

## User Story 1: a category implementation from this repository

```bash
lake exe cas-peer run tests/scenarios/sets-category.json -- \
  uv run --frozen python tests/leaves/sets_category.py
```

Expected: negotiation, one immediate reply, one deferred program, one suspension resumed with a
result slot and a `noImplementation` slot, one export invocation and one discard, each matched
by the scenario.

## User Story 2: a kernel check with the protocol peer

A kernel engineer registers `peer/leaves.json` with a scenario path and runs the kernel check
of the task in hand. Expected: each frame the kernel sends equals the scenario frame; the peer
exits nonzero and names the first difference otherwise.

## User Story 3: provider replacement

```bash
lake exe cas-peer manifest tests/scenarios/two-providers.json
```

Expected: both registrations are admitted by the decoder; the file has no priority field.
