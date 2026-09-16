#!/usr/bin/env bash
# Translate PMB's existing compaction policy into Codex's hook response contract.
# The policy stays in pre-compact-check.sh; this file is only a platform adapter.
set -u

mode="${1:-}"
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" 2>/dev/null || exit 0

case "$mode" in
    pre)
        [ -f "$repo_root/scripts/pre-compact-check.sh" ] || exit 0
        bash "$repo_root/scripts/pre-compact-check.sh" >/dev/null 2>&1
        gate_code=$?
        if [ "$gate_code" -eq 2 ]; then
            printf '%s\n' '{"continue":false,"stopReason":"PMB memory-bank state is not ready for compaction.","systemMessage":"Update memory-bank/activeContext.md and memory-bank/progress.md, or create a current handoff.md, then retry compaction. Run scripts/pre-compact-check.sh for detailed reasons."}'
        fi
        # A policy block is carried by valid JSON. Missing prerequisites and unexpected checker
        # failures stay fail-open, matching the existing checker contract.
        exit 0
        ;;
    recover)
        printf '%s\n' "After compaction, re-read all five memory-bank files before continuing and treat them as authoritative. Then read handoff.md if present as an ephemeral supplement, reconcile it with activeContext.md's Next Steps, surface any conflict, delete it only after merging its state, and resume from verified git/worktree/test state. Do not rely on the compaction summary alone."
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
