#!/usr/bin/env sh
# scripts/check-review-gate-lib-presence.sh — hardcoded (not settings.json-derived) existence
# check: if review-reminders.sh/.ps1/-post.sh/-post.ps1 exist in <dir>, the matching
# _review-gate-lib.sh/.ps1 must exist too.
#
# WHY hardcoded, not folded into the existing dynamic settings.json-parsing check: a
# dot-sourced lib is never referenced in settings.json's command strings -- it's only
# reachable one hop away, via the hook files' own `. "$(dirname "$0")/_review-gate-lib.sh"`
# line. The dynamic check (mb doctor's "Hook scripts present", CI's template-integrity job)
# structurally cannot see a file it never parses out of settings.json. This exact class of
# gap already bit review-reminders*.sh/.ps1 themselves once (missing from mb init's copy loop
# and TEMPLATE_OWNED until 2026-07-29) -- a lib file with weaker detection coverage than the
# files that already slipped through once is a real risk, not theoretical.
#
# WHY one shared script instead of separate copies in mb.sh's doctor and the CI workflow:
# duplicating this check's logic between two call sites is exactly the class of drift this
# whole refactor exists to eliminate -- applied here to the detection mechanism itself, not
# just the hooks it protects.
#
# Usage: check-review-gate-lib-presence.sh <dir>
# Exit 0: no problem found. Exit 1: a required lib file is missing; prints one ERROR line
# per gap to stdout.
dir="${1:?usage: check-review-gate-lib-presence.sh <dir>}"
fail=0

if { [ -f "$dir/review-reminders.sh" ] || [ -f "$dir/review-reminders-post.sh" ]; } && [ ! -f "$dir/_review-gate-lib.sh" ]; then
    echo "ERROR: $dir/_review-gate-lib.sh missing but $dir/review-reminders.sh/-post.sh present -- the review-gate hook will fail open (gate silently disabled)"
    fail=1
fi
if { [ -f "$dir/review-reminders.ps1" ] || [ -f "$dir/review-reminders-post.ps1" ]; } && [ ! -f "$dir/_review-gate-lib.ps1" ]; then
    echo "ERROR: $dir/_review-gate-lib.ps1 missing but $dir/review-reminders.ps1/-post.ps1 present -- the review-gate hook will fail open (gate silently disabled)"
    fail=1
fi

exit $fail
