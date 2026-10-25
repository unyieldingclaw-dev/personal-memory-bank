#!/usr/bin/env bash
# Emit PMB recovery context after Codex compacts the session.
set -u

mode="${1:-}"
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" 2>/dev/null || exit 0

case "$mode" in
    recover)
        printf '%s\n' "After compaction, re-read all five memory-bank files before continuing and treat them as authoritative. Then read handoff.md if present as an ephemeral supplement, reconcile it with activeContext.md's Next Steps, surface any conflict, delete it only after merging its state, and resume from verified git/worktree/test state. Do not rely on the compaction summary alone."
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
