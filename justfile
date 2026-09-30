# Lean QC delegates to ~/ai-review-ci/justfiles/lean.just. The commit and push
# tiers are static scans; CI builds on Mathlib's prebuilt cache and runs the
# kernel-axiom audit.

# List available recipes.
default:
    @just --list

# Scan staged Lean source.
test-commit:
    @just -f ~/ai-review-ci/justfiles/lean.just -d . test-commit

# Static Lean scans before push.
test-push:
    @just -f ~/ai-review-ci/justfiles/lean.just -d . test-push

# Build and run the full Lean gate.
test-ci:
    @just -f ~/ai-review-ci/justfiles/lean.just -d . test-ci

# Kernel-axiom audit, consumed by lean.just's lean-axiom-audit.
[private]
_lean-axiom-audit:
    @lake build AxiomAudit
