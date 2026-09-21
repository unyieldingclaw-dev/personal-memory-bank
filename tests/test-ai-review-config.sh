#!/usr/bin/env bash
# tests/test-ai-review-config.sh — ai-review.config.json's excludes must actually apply, not merely parse
#
# WHY THIS SUITE EXISTS: ai-review.config.json narrows ACR's (ai-review-agent's) default blanket
# `**/*.md` exclude for its `security`/`adversarial` LLM agents down to specific paths, so those
# agents finally review this repo's own governance files instead of blanket-skipping every .md file
# (see [NS-48] in memory-bank/activeContext.md). The shape of the bug this guards against is not
# "the JSON is malformed" — it is "the exclude list looks right and is wrong", which static review
# missed TWICE in one day (2026-09-19): first `memory-bank/**`/`docs/**` were dropped entirely, then
# `memory-bank/**`'s own `templates/`/`examples/**` mirrors were missing. Both times, ad-hoc manual
# testing (construct a synthetic diff, run ai-review-agent, read the JSON by eye) is what caught it —
# there was no committed, re-runnable check. This suite is that check.
#
# WHY ASSERT ON policy.agentsSkipped/filteredFiles, NEVER ON FINDING CONTENT: ACR's LLM findings are
# not deterministic. Confirmed directly during the review that produced this suite: the IDENTICAL
# diff against ai-review.config.json itself produced `totalFindings: 0` in 3 of 4 runs and a
# corroborated `high`-severity finding in the 4th. An assertion on finding content would be exactly
# the "check that cannot fail" / "check that fails for the wrong reason" defect
# standards/CODE-REVIEW.md's Evidence Integrity section names. policy.agentsSkipped and
# filteredFiles are computed by a synchronous pre-filter BEFORE any agent (LLM or otherwise) runs.
#
# POLICY KEY PRESENCE: the `policy` key is present in ACR's JSON ONLY when at least one changed file
# was actually excluded — for an EXCLUDED file this holds regardless of --timeout/completion status
# (verified directly: present at --timeout 3000 with the agents never even invoked). For a file that
# is NOT excluded, `policy` is simply ABSENT from the JSON, whether the agent then times out or
# completes normally. skip_verdict() below treats a missing `policy` as "not skipped" (its
# `data.get("policy") or {}` default), which is the CORRECT verdict for an admitted file independent
# of whatever happens to the LLM call afterward.
#
# This is a SEPARATE fact from Ollama reachability: `policy`/`filteredFiles` are a synchronous
# PRE-filter, but ai-review-agent's own runner pings Ollama and ABORTS WITH ZERO STDOUT BEFORE that
# pre-filter ever runs (`runner.ts`'s `ping()` precedes `evaluatePolicy`) — so an unreachable Ollama
# means the pre-filter itself never runs, and neither fact above ever applies. A separate, REQUIRED
# (not optional) Ollama-reachability preflight exists below (search "THIS CHECK IS REQUIRED")
# specifically for that case. This paragraph previously stated a wrong "no preflight needed" claim,
# twice, near this exact spot (caught by two separate opposition review passes, 2026-09-19) before
# converging on this single statement — if you are editing either this paragraph or the preflight,
# keep them consistent rather than restating each other's rationale.
#
# WHY --dir INSTEAD OF cd: ai-review-agent's `loadConfig()` resolves the project directory from
# `--dir` (falling back to cwd), so `--dir "$REPO_ROOT"` loads the REAL, currently-committed
# ai-review.config.json regardless of this script's own working directory — confirmed directly
# against the installed package's CLI (`--dir <path>  Directory to diff against HEAD (default: cwd)`,
# and cli/index.ts's `projectPath = resolve(options.dir ?? process.cwd())`).
#
# WHY --diff PATCHES BUILT WITH `git diff --no-index -- /dev/null <path>` AND NO REPO AT ALL: ACR's
# --diff mode parses the patch file directly for both path and content; it does not need the target
# path to exist on disk, and does not need a git repository at all. Confirmed directly: a patch for
# `memory-bank/progress.md` built in a throwaway directory with no `git init` anywhere near it was
# accepted identically to a patch built from a real tracked file. This means each check below can
# exercise a path that does not yet exist in this repo (a future `examples/another-app/memory-bank/`)
# exactly as easily as one that does.
#
# WHY DISCOVER MIRROR DIRECTORIES WITH find RATHER THAN HARD-CODE A PATH LIST: a hard-coded list is
# exactly the failure mode this suite exists to catch — round 2's bug WAS a hard-coded list missing
# an entry. `find . -type d \( -name memory-bank -o -name docs -o -name standards \)` walks the real
# tree and asserts every directory it finds is covered, so a future `examples/another-app/memory-bank`
# is picked up automatically the moment it is added, with no test-file edit required. This is also
# why the suite does NOT assert that docs/standards have an examples/** mirror the way memory-bank
# does: no such directory exists today (verified below), so requiring one would be asserting against
# a hypothetical, which the historical bug this suite guards against was NOT — it was a real,
# existing, unmirrored directory.
#
# WHY THE MUTATION TEST, per standards/CODE-REVIEW.md's Evidence Integrity rule ("a check that cannot
# fail does not count as a check"): every assertion above proves the CURRENT config is correct. None
# of them proves the exclude entries are load-bearing rather than redundant with something else (a
# broader pattern earlier in the array, a default the tool already supplies). The mutation test
# below strips the two entries this repo's own history shows were once missing, from a config copied
# into an isolated sandbox (never the real ai-review.config.json), and asserts the previously-excluded
# path is NOW reviewed — proving removal changes behavior, not just that presence doesn't break
# anything.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== ai-review.config.json tests ==="

# WHY THIS RUNS BEFORE ANY TOOL CHECK — Architecture Drift domain review 2026-09-19: every assertion
# below this point was gated behind ai-review-agent/Ollama, so in CI (ubuntu-latest, confirmed absent
# both there via .github/workflows/pmb-health.yml) this suite asserted NOTHING, including the two
# checks below that need neither tool. Hoisted so at least this much runs everywhere.
CONFIG="$REPO_ROOT/ai-review.config.json"
assert_file_exists "$CONFIG" "ai-review.config.json exists at repo root"

# ── graceful skip: the REST of this suite's subject is an optional, BYO local-LLM tool ──────────
# WHY exit $? (not a bare exit 0) on skip, found by Correctness AND Maintainability domain review
# 2026-09-19 (Blocking/High, independently in both): a skip means "nothing further to check", not
# "discard what already failed". print_summary (tests/helpers/assert.sh) returns 1 when $FAIL>0 — a
# bare `exit 0` after it discarded that return value, so a real failure in the file-exists or
# STRUCTURE checks ABOVE this gate (both of which run before any tool check, see the comment above
# CONFIG=... below) would still report suite exit 0. Reproduced directly: a deliberately-broken
# ai-review.config.json plus ai-review-agent absent from PATH printed "FAIL: ... / Results: 1
# passed, 1 failed" and still exited 0. tests/run.sh's run_suite() only reads the child's exit code,
# never its stdout, so this bug would have silently swallowed exactly the regression class ([NS-48])
# this suite exists to catch, specifically in CI — the one environment that lacks both tools. `exit
# $?` preserves the original graceful-skip behavior (0 when nothing has failed yet) while letting a
# genuine pre-skip failure propagate.
# WHY skip at all (not a hard failure) when the tool is absent: matches
# .claude/commands/change-review.md Step 2's exit-0-on-tool-absence convention ("ACR not found in
# PATH. Skipping local LLM swarm. Continuing with PMB-native review."). The PARTIAL, in-suite skip
# style used elsewhere in tests/ for an optional tool (e.g. tests/test-mirror-parity.sh /
# tests/test-review-reminders.sh gating individual python3-dependent blocks while the rest of the
# suite still runs) is NOT what this file does below this point — every remaining assertion needs
# both tools, so there is nothing left to run without them, and this is (as of 2026-09-19) the only
# suite in tests/ that exits early rather than skipping selected blocks. CI's ubuntu-latest runner
# has neither ai-review-agent nor Ollama installed, so in CI this file always takes one of the
# branches below and nothing past it ever executes there — this suite's real protection (beyond the
# two structural checks above) exists only on a developer machine with both tools installed.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found. Skipping the rest of this suite (needed to parse ai-review.config.json/ACR's JSON output)."
  print_summary; exit $?
fi

# ---------------------------------------------------------------------------
# 1. STRUCTURE — the [NS-48] TRAP: loadConfig does a SHALLOW merge, so setting agentPolicy for one
#    agent silently drops the other's defaults. Re-specifying both is the fix; this is the
#    regression guard for someone editing one array and forgetting the other, which is exactly
#    the shape of mistake a copy-paste edit invites. Needs only python3 — hoisted above the
#    ai-review-agent/Ollama gates below for the same reason as the file-exists check above.
# ---------------------------------------------------------------------------
STRUCT=$(python3 - "$CONFIG" <<'PYEOF'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    cfg = json.load(fh)
try:
    sec = cfg["agentPolicy"]["security"]["exclude"]
    adv = cfg["agentPolicy"]["adversarial"]["exclude"]
except KeyError as e:
    print(f"MISSING_KEY:{e}")
    sys.exit(0)
print("SAME" if sec == adv else f"DIFFERENT:sec={sec} adv={adv}")
PYEOF
)
assert_equals "$STRUCT" "SAME" "security.exclude and adversarial.exclude are identical arrays"

if ! command -v ai-review-agent >/dev/null 2>&1; then
  echo "SKIP: ai-review-agent not found in PATH. Skipping the rest of this suite."
  print_summary; exit $?
fi

ACR_TIMEOUT_MS=10000

SANDBOXES=()
cleanup() { for d in "${SANDBOXES[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT

# new_sandbox — creates a mktemp -d and registers it in SANDBOXES, in the CALLER's own shell
# context (`d=$(new_sandbox)` only captures this function's stdout via command substitution; the
# SANDBOXES append happens as a separate statement at the call site, never inside a function called
# through `$(...)`). This mirrors tests/test-baseline-health.sh's own new_sandbox() and its header
# comment on exactly this pitfall: "every call site invokes this as X=$(new_sandbox), and command
# substitution runs the function in a SUBSHELL. An array append performed in here is discarded when
# that subshell exits." An earlier version of build_diff() below did the append INSIDE itself for
# exactly that reason and leaked every sandbox it created — reproduced by Correctness domain review
# 2026-09-19: 9 temp directories per run, never cleaned up, because `diff=$(build_diff ...)` at every
# call site forked a subshell that discarded the SANDBOXES+=() line before cleanup() could ever see it.
new_sandbox() {
  local d
  d=$(mktemp -d) || return 1
  printf '%s' "$d"
}

# build_diff <sandbox-dir> <relative-path> <content-line> — writes one file under the CALLER-OWNED
# sandbox directory and emits a `git diff --no-index` patch for it to stdout. Taking the sandbox as
# an argument (rather than creating and owning one internally) is what fixes the leak above: the
# caller creates it via new_sandbox, registers it in SANDBOXES itself, then passes it in here.
# 2>/dev/null on the diff itself is load-bearing, not cosmetic: git's own "LF will be replaced by
# CRLF" warning goes to stderr, and an earlier draft of this suite piped 2>&1 here, which spliced
# that warning INTO the patch file ACR then parsed as diff content — producing a real (if harmless)
# hallucinated finding about the warning text itself. Reproduced once while writing this suite.
# WHY `; return 0` at the end: `git diff --no-index` exits 1 whenever it finds a difference — the
# NORMAL case here, not an error (0 would mean "no diff", which cannot happen since we always diff
# real content against /dev/null). That 1 is captured into `out` via `out=$(...)` (not left as this
# function's own exit status) — but WITHOUT the explicit `return 0` guard, a future edit that moved
# or removed the trailing `printf` could again let that 1 propagate as THIS FUNCTION's return code,
# which every call site's `|| continue`/`|| return 1` then reads as "could not build the diff" and
# silently skips the rest of that iteration. Reproduced while writing this suite, before the guard
# existed: the entire directory-discovery loop in section 2 ran zero assertions with no error
# printed, because every single build_diff call "failed" this way and every loop iteration bailed
# out via `continue` before reaching its assert_equals.
build_diff() {
  local d="$1" relpath="$2" content="$3" out
  mkdir -p "$d/$(dirname "$relpath")"
  printf '%s\n' "$content" > "$d/$relpath"
  out=$(cd "$d" && git diff --no-index -- /dev/null "$relpath" 2>/dev/null)
  # `printf '%s\n'`, NOT `'%s'`: `out=$(...)` strips ALL of git's own trailing newlines, and section
  # 3/3.5 concatenate several build_diff calls into one patch file with `>>`. Without restoring
  # exactly one trailing newline here, two concatenated diffs glue onto a single line — reproduced
  # directly: "+content a" and the next file's "diff --git a/b.md ..." landed on the same line, which
  # a diff parser reads as one malformed hunk rather than two separate file diffs. A single-diff call
  # site (section 2's loop) is unaffected either way, since a lone trailing newline is inert there.
  printf '%s\n' "$out"
  return 0
}

# run_acr <dir> <diff-file> <out-json> — runs ai-review-agent and writes ONLY stdout (the JSON) to
# <out-json>; stderr (progress banners) is discarded. Exit code is deliberately not asserted by
# callers. CORRECTED SCOPE 2026-09-19 (opposition review): a DISPATCHED agent that times out or
# errors still emits well-formed policy/filteredFiles fields alongside its own error status
# (measured: a bad model name yields exit 2, 1339 bytes of valid JSON, agentStatus all "error") — but
# an agent that never gets dispatched because ai-review-agent's own Ollama ping() failed emits NOTHING
# (exit 4, 0 bytes stdout). "A timed-out or agent-failed run still emits well-formed fields" was true
# only for the first case; the preflight below is what keeps the second case (ping failure) from ever
# reaching this function during the suite's real assertions.
# WHY --profile security IS ENOUGH TO EXERCISE THE ADVERSARIAL AGENT TOO — Maintainability domain
# review 2026-09-19 flagged this as ambiguous (skip_verdict below checks both "security" and
# "adversarial" in agentsSkipped/filteredFiles, but only --profile security is ever passed here);
# Testing domain review the same day resolved it by reading the installed package's source directly
# (profiles.ts): the "security" PROFILE NAME expands to the agent set
# ['security','secrets','dependencies','adversarial'] — it is not the name of a single agent. So a
# single --profile security run genuinely dispatches (or policy-skips) the adversarial agent as well;
# skip_verdict checking both keys against one such run is correct, not a coverage gap.
run_acr() {
  local dir="$1" diff="$2" out="$3"
  ai-review-agent --dir "$dir" --profile security --chunk --format json \
    --timeout "$ACR_TIMEOUT_MS" --diff "$diff" >"$out" 2>/dev/null
}

# skip_verdict <json-file> <target-file...> — prints one line per target: SKIPPED if the file's
# security/adversarial coverage was excluded (whole-agent skip via policy.agentsSkipped, or a
# partial per-file strip via filteredFiles — both are "excluded" from this suite's point of view),
# REVIEWED otherwise. A malformed/unparseable JSON file prints ERROR rather than silently matching
# neither branch, so a broken ACR invocation is loud rather than reading as "reviewed".
# WHY `| tr -d '\r'`: this python3 (Windows) writes text-mode stdout as \r\n. A single-target call's
# lone output line has its \r\n fully stripped by the caller's `$(...)` command substitution (which
# strips ALL trailing newline bytes), so that case looked fine in isolation — but the admit-side
# check (section 3) requests 3 targets in one call, and `read -r line` in a loop strips only the
# final \n per line, leaving \r attached to every line except the last. That left a literal
# "REVIEWED\r" being compared against "REVIEWED", failing an assert_equals whose printed Expected/
# Actual looked byte-identical on screen — reproduced while writing this suite. Stripping \r here
# once, at the source, means no call site needs to know this python3 uses CRLF.
skip_verdict() {
  local json="$1"; shift
  python3 - "$json" "$@" <<'PYEOF' | tr -d '\r'
import json, sys
path = sys.argv[1]
targets = sys.argv[2:]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as e:
    for t in targets:
        print(f"{t}:ERROR:{e}")
    sys.exit(0)
policy = data.get("policy") or {}
skipped_agents = set(policy.get("agentsSkipped") or [])
filtered = data.get("filteredFiles") or {}
whole_skip = "security" in skipped_agents and "adversarial" in skipped_agents
for t in targets:
    per_file = any(t in (filtered.get(a) or []) for a in ("security", "adversarial"))
    print(f"{t}:{'SKIPPED' if (whole_skip or per_file) else 'REVIEWED'}")
PYEOF
}

# THIS CHECK IS REQUIRED, NOT DEFENSIVE PADDING — missing entirely in an earlier draft (found by
# opposition review 2026-09-19), then reimplemented with a hardcoded curl/URL/model check that a
# SECOND opposition pass found could disagree with ai-review-agent itself (a project ai-review.config.json
# could set its own ollamaUrl/model, invisible to a separate curl probe — silently skipping when ACR
# would have worked, or the reverse). This version asks ai-review-agent the SAME question it would ask
# for real, resolved through its own config-loading, rather than re-implementing that resolution:
# ai-review-agent's own runner pings Ollama and ABORTS WITH ZERO STDOUT before producing any JSON at
# all (not even policy/filteredFiles) when the ping fails, whether because Ollama is unreachable or
# the configured model isn't pulled — confirmed against the installed package's source (runner.ts's
# ping() precedes evaluatePolicy; ollamaProvider.ts's ping() checks the model too, not just the
# server) and reproduced empirically: an unreachable --ollama-url exits 4 with 0 bytes of stdout,
# identically at the default 180000ms timeout and this suite's own 10s — `--timeout` cannot rescue a
# ping that fails before any agent is dispatched. Before a check like this existed, "ai-review-agent
# installed but Ollama stopped or the model not pulled" (a common local dev state, not a hypothetical)
# made every downstream run_acr() call return an empty file, skip_verdict() catch the JSON-parse
# exception and print "ERROR:...", and every assertion below fail loudly instead of this suite
# skipping. The probe targets memory-bank/**, which this repo's own config already excludes — but
# CORRECTED 2026-09-19 (Correctness domain review): this does NOT make the whole call fast. Measured
# directly against this file's own real installation: the probe still took ~10s (the full
# ACR_TIMEOUT_MS) with agentStatus.secrets:"timeout", because --profile security also dispatches
# `secrets`/`dependencies` agents (confirmed against profiles.ts) that agentPolicy's exclude arrays
# do NOT govern — only `security`/`adversarial` are. So this preflight is exactly as slow as any
# other real-dispatch call in this file when Ollama IS reachable; its purpose is solely to
# distinguish "reachable" (some output, any output) from "unreachable" (zero bytes) before spending
# the rest of the suite's real assertions.
PREFLIGHT_SBX=$(new_sandbox); SANDBOXES+=("$PREFLIGHT_SBX")
preflight_diff=$(build_diff "$PREFLIGHT_SBX" "memory-bank/preflight-probe.md" "Preflight probe line.")
preflight_difffile=$(mktemp); SANDBOXES+=("$preflight_difffile")
printf '%s' "$preflight_diff" > "$preflight_difffile"
preflight_out=$(mktemp); SANDBOXES+=("$preflight_out")
run_acr "$REPO_ROOT" "$preflight_difffile" "$preflight_out"
if [ ! -s "$preflight_out" ]; then
  echo "SKIP: ai-review-agent produced no output — Ollama unreachable or its configured model not pulled. Skipping the rest of this suite."
  print_summary; exit $?
fi

# ---------------------------------------------------------------------------
# 2. EXCLUDE-SIDE — every real directory matching the misread-prone content shape must be excluded.
#    Discovered, not hard-coded (see header comment); this is what would have caught round 2's bug
#    (templates/memory-bank existed, unmirrored) automatically before it shipped.
# ---------------------------------------------------------------------------
mapfile -t DISCOVERED_DIRS < <(cd "$REPO_ROOT" && find . -type d \( -name memory-bank -o -name docs -o -name standards \) -not -path "./node_modules/*" | sort)
# Anti-vacuity — Correctness domain review 2026-09-19 (Medium): with no floor on how many directories
# the find above discovers, a broken -name/-path clause (or these directories being renamed away)
# would make the loop below execute zero times and report zero failures — the same "check that
# cannot fail" shape section 4's own anti-vacuity check (MUT_RESULT) already guards against for the
# mutation test. The expected count is NOT hardcoded here (that would reintroduce the exact
# hard-coded-list failure mode this file's own header rejects for this section) — only that it is
# nonzero.
DISCOVERED_COUNT=${#DISCOVERED_DIRS[@]}
assert_equals "$([ "$DISCOVERED_COUNT" -gt 0 ] && echo NONZERO || echo ZERO)" "NONZERO" "directory-discovery found at least one memory-bank/docs/standards directory (found $DISCOVERED_COUNT — 0 would mean this loop checked nothing)"

for dir in "${DISCOVERED_DIRS[@]}"; do
  [ -z "$dir" ] && continue
  relpath="${dir#./}/regression-test-canary.md"
  sbx=$(new_sandbox) || continue
  SANDBOXES+=("$sbx")
  diff=$(build_diff "$sbx" "$relpath" "Canary line for $relpath.")
  difffile=$(mktemp); SANDBOXES+=("$difffile")
  printf '%s' "$diff" > "$difffile"
  outjson=$(mktemp); SANDBOXES+=("$outjson")
  run_acr "$REPO_ROOT" "$difffile" "$outjson"
  verdict=$(skip_verdict "$outjson" "$relpath")
  assert_equals "${verdict#*:}" "SKIPPED" "excluded: $relpath ($verdict)"
done

# Fixed single-file case, not directory-shaped: only fixtures/security/README.md (the prose file)
# needs excluding, not the whole fixtures/security/** tree — Security domain review 2026-09-19 found
# the earlier fixtures/security/** entry over-excluded real .py/.html vulnerable-code fixtures that
# needed reviewing, not excluding.
sbx=$(new_sandbox); SANDBOXES+=("$sbx")
diff=$(build_diff "$sbx" "fixtures/security/README.md" "Canary line for fixtures/security/README.md.")
difffile=$(mktemp); SANDBOXES+=("$difffile"); printf '%s' "$diff" > "$difffile"
outjson=$(mktemp); SANDBOXES+=("$outjson")
run_acr "$REPO_ROOT" "$difffile" "$outjson"
verdict=$(skip_verdict "$outjson" "fixtures/security/README.md")
assert_equals "${verdict#*:}" "SKIPPED" "excluded: fixtures/security/README.md ($verdict)"

# Real-fixture admit-side canary — Testing domain review 2026-09-19 (Blocking/High): the check just
# above only ever exercises fixtures/security/README.md. It never proved the ORIGINAL regression this
# suite's own comment two blocks up names (an earlier, over-broad fixtures/security/** entry that
# excluded real vulnerable-code fixtures needed for review, not just the README) actually stays fixed
# — nothing here touched a real fixture path. `find fixtures/security -type f` confirms
# fixtures/security/SEC-001-hardcoded-secret/bad.py exists; asserting IT is REVIEWED (not excluded)
# is what actually closes that historical bug class, the same way section 3's ADMIT_FILES closes the
# control-plane-file regression.
sbx=$(new_sandbox); SANDBOXES+=("$sbx")
diff=$(build_diff "$sbx" "fixtures/security/SEC-001-hardcoded-secret/bad.py" "# Canary line for fixtures/security/SEC-001-hardcoded-secret/bad.py.")
difffile=$(mktemp); SANDBOXES+=("$difffile"); printf '%s' "$diff" > "$difffile"
outjson=$(mktemp); SANDBOXES+=("$outjson")
run_acr "$REPO_ROOT" "$difffile" "$outjson"
verdict=$(skip_verdict "$outjson" "fixtures/security/SEC-001-hardcoded-secret/bad.py")
assert_equals "${verdict#*:}" "REVIEWED" "admitted (not excluded): fixtures/security/SEC-001-hardcoded-secret/bad.py ($verdict)"

# ---------------------------------------------------------------------------
# 3. ADMIT-SIDE — the whole point of [NS-48]: these three files must NOT be excluded, or the fix
#    regresses to the blanket **/*.md default it replaced. Combined into one diff (one LLM-bounded
#    call instead of three) since none of these three should be excluded and a per-file skip would
#    show up in filteredFiles regardless of the others.
#
# WHY THIS LIST IS HARDCODED, unlike section 2's find-based discovery: section 2 discovers new
# LOCATIONS of a known content-shape (a directory literally named memory-bank/docs/standards) — that
# generalizes because the shape to look for is known in advance. There is no analogous shape to walk
# for "files NS-48 specifically carved an exception for": these three are deliberate, individually-
# reasoned admissions (the control-plane files ACR previously never reviewed at all, plus the config
# file itself), not instances of a pattern. A future control-plane file (e.g. a new .claude/agents/*.md)
# does NOT need adding here to stay protected — it is already admitted by default, since nothing
# excludes .claude/**; this list exists only to positively confirm these THREE specific files, the
# ones NS-48 was written to fix, don't regress back under some future overly-broad exclude pattern.
# ---------------------------------------------------------------------------
ADMIT_FILES=(
  ".claude/commands/security-review.md"
  ".claude/agents/security-reviewer.md"
  "ai-review.config.json"
)
ADMIT_D=$(new_sandbox); SANDBOXES+=("$ADMIT_D")
admit_diff=$(mktemp); SANDBOXES+=("$admit_diff")
: > "$admit_diff"
for f in "${ADMIT_FILES[@]}"; do
  build_diff "$ADMIT_D" "$f" "Canary line for $f." >> "$admit_diff"
done
admit_out=$(mktemp); SANDBOXES+=("$admit_out")
run_acr "$REPO_ROOT" "$admit_diff" "$admit_out"
admit_verdicts=$(skip_verdict "$admit_out" "${ADMIT_FILES[@]}")
while IFS= read -r line; do
  f="${line%%:*}"; v="${line#*:}"
  assert_equals "$v" "REVIEWED" "admitted (not excluded): $f ($line)"
done <<<"$admit_verdicts"

# ---------------------------------------------------------------------------
# 3.5. MIXED DIFF — closes a real coverage gap found independently by Correctness AND Testing
#    domain review 2026-09-19: every diff built above is homogeneous (either every file in it should
#    be excluded, or every file in it should be admitted). ACR only emits a whole-agent
#    policy.agentsSkipped when ALL changed files in a diff match the exclude patterns
#    (policyFilter.ts's matchesAll); when a diff mixes excluded and admitted files, the excluded ones
#    are instead stripped per-file into filteredFiles while the agent still runs on the rest. Neither
#    branch above ever exercises that filteredFiles code path — confirmed by both domain reviews via
#    live reproduction, and independently here: no assertion before this point has ever seen a
#    populated filteredFiles key in any captured JSON. A regression that broke ONLY the per-file
#    strip (leaving whole-diff skip intact) would ship undetected without this check.
# ---------------------------------------------------------------------------
MIX_D=$(new_sandbox); SANDBOXES+=("$MIX_D")
mix_diff=$(mktemp); SANDBOXES+=("$mix_diff")
{
  build_diff "$MIX_D" "memory-bank/mixed-canary.md" "Canary line for memory-bank/mixed-canary.md."
  build_diff "$MIX_D" ".claude/commands/mixed-canary.md" "Canary line for .claude/commands/mixed-canary.md."
} > "$mix_diff"
mix_out=$(mktemp); SANDBOXES+=("$mix_out")
run_acr "$REPO_ROOT" "$mix_diff" "$mix_out"
mix_verdicts=$(skip_verdict "$mix_out" "memory-bank/mixed-canary.md" ".claude/commands/mixed-canary.md")
while IFS= read -r line; do
  f="${line%%:*}"; v="${line#*:}"
  case "$f" in
    memory-bank/*) assert_equals "$v" "SKIPPED" "mixed diff: excluded file still excluded per-file ($line)" ;;
    .claude/*)     assert_equals "$v" "REVIEWED" "mixed diff: admitted file still reviewed alongside an excluded one ($line)" ;;
  esac
done <<<"$mix_verdicts"

# ---------------------------------------------------------------------------
# 4. MUTATION — proves the two entries round 2 added are load-bearing, not vacuous. Operates on a
#    COPY of the config in an isolated sandbox; the real, committed ai-review.config.json is never
#    touched. See header comment for why this is required, not optional, per this repo's own
#    Evidence Integrity rule.
# ---------------------------------------------------------------------------
MUT_D=$(new_sandbox); SANDBOXES+=("$MUT_D")
MUT_RESULT=$(python3 - "$CONFIG" "$MUT_D/ai-review.config.json" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as fh:
    cfg = json.load(fh)
STRIP = {"templates/memory-bank/**", "examples/**/memory-bank/**"}
removed = 0
for agent in cfg.get("agentPolicy", {}):
    before = cfg["agentPolicy"][agent].get("exclude", [])
    after = [p for p in before if p not in STRIP]
    removed += len(before) - len(after)
    cfg["agentPolicy"][agent]["exclude"] = after
with open(dst, "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2)
print(removed)
PYEOF
)
# Anti-vacuity: if STRIP matched nothing (e.g. the entries were renamed), the mutation is a no-op
# and the assertion below would trivially pass by testing the UNMUTATED config's own correct
# behavior — the exact "check that cannot fail" shape this whole block exists to avoid. Expected is
# 4, not 2: STRIP names 2 entries and the loop removes them from BOTH the security and adversarial
# arrays (2 entries × 2 agents).
assert_equals "$MUT_RESULT" "4" "mutation actually removed 4 entries — 2 patterns × 2 agent arrays (0 here would mean this test checked nothing)"

# WHY BOTH stripped patterns get their own diff target, not just templates/memory-bank/**: an
# earlier version of this block only tested one of the two entries STRIP names, so the assertion
# proved "templates/memory-bank/** is load-bearing" but said nothing about
# "examples/**/memory-bank/** is load-bearing" — Testing domain review 2026-09-19. Both must flip to
# REVIEWED for this to actually prove what MUT_RESULT's count-of-4 claims it set up.
mut_sbx=$(new_sandbox); SANDBOXES+=("$mut_sbx")
mut_diff=$(mktemp); SANDBOXES+=("$mut_diff")
{
  build_diff "$mut_sbx" "templates/memory-bank/regression-test-canary.md" "Canary line."
  build_diff "$mut_sbx" "examples/task-tracker-api/memory-bank/regression-test-canary.md" "Canary line."
} > "$mut_diff"
mut_out=$(mktemp); SANDBOXES+=("$mut_out")
run_acr "$MUT_D" "$mut_diff" "$mut_out"
mut_verdicts=$(skip_verdict "$mut_out" "templates/memory-bank/regression-test-canary.md" "examples/task-tracker-api/memory-bank/regression-test-canary.md")
while IFS= read -r line; do
  f="${line%%:*}"; v="${line#*:}"
  assert_equals "$v" "REVIEWED" "mutation: stripping templates/memory-bank/**+examples/**/memory-bank/** un-excludes $f ($line) — proves both entries are load-bearing"
done <<<"$mut_verdicts"

print_summary
