#!/usr/bin/env bash
# tests/setup.sh — creates a minimal PMB-initialized project in a temp dir
# Usage: source tests/setup.sh; setup_test_project "$TMPDIR"; cd "$TMPDIR"

setup_test_project() {
  local dir="$1"
  mkdir -p "$dir/memory-bank"
  mkdir -p "$dir/.claude/contracts"
  mkdir -p "$dir/standards"
  mkdir -p "$dir/docs/plans"
  mkdir -p "$dir/docs/archive/plans"

  # Minimal memory-bank files
  for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
    printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# %s\nTest content.\n" \
      "$(date +%Y-%m-%d)" "$f" > "$dir/memory-bank/$f"
  done

  # CLAUDE.md
  printf "# Project\nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40\n" > "$dir/CLAUDE.md"

  # Required standards files
  for s in WORKFLOW.md CODE-QUALITY.md SECURITY-GUARDRAILS.md CODE-REVIEW.md; do
    printf "# %s\n" "$s" > "$dir/standards/$s"
  done

  # Init git repo so mb commands that check git status work
  cd "$dir" || return 1
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -q -m "init"
  cd - > /dev/null || return 1
}
