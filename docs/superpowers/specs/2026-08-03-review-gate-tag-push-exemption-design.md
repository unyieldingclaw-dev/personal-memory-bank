# Review-Gate Hook Tag-Push Exemption

**Date:** 2026-08-03
**Status:** Proposed — not started. Deferred to its own branch/session (`claude/tag-push-gate-fix`,
worktree `.claude/worktrees/tag-push-gate-fix`), tracked so it isn't lost between sessions.

## Problem

Reported by the `ai-code-review-agent` (ACR) session, discovered live while cutting an actual
release (`git tag v1.8.0 origin/main && git push origin v1.8.0`) in that repo, which has PMB's
review-gate hooks installed via `mb init`/`mb upgrade`.

`review-reminders.sh`/`.ps1` (`PreToolUse`) denied the compound command outright — nothing in
it executed, not even the harmless `git tag` half — because `needs_push` detection (both the
quote-stripped substring floor and the `classify_targets()`/`Get-CommandTargets` tokenizer added
this session) only checks whether the git subcommand is `push`. Neither layer looks at what ref
is actually being pushed. A tag push and a branch push are indistinguishable to the hook.

This is a mismatch, not just friction: the hook's actual check for a `push` is a diff-hash
between `origin/main` and `HEAD` — a meaningful proxy for "has this code been reviewed" for a
**branch** push. A tag push carries no diff at all; it labels a commit that (in the release
case) was already merged and already gated through its own PR's `/change-review` pass at merge
time. Satisfying the gate for the tag push meant recomputing a `.change-review-ok` marker from
whatever feature branch happened to be locally checked out — content with no relationship to
the tag or the release event. It worked, but by coincidence, not by any check that's actually
about the tag.

Verified independently against this session's current code (post the additive-OR tokenizer fix
in commit `f255c1d`): `classify_targets()`/`Get-CommandTargets` extract the subcommand token
(`push`) via `next_subcommand()`/`Get-NextSubcommand`, but never inspect the tokens *after* the
subcommand (the remote and refspec arguments) — so this gap is orthogonal to and unaffected by
that fix. It has been present since `needs_push` detection was first written (this session,
commit `e2fb87f` and earlier), on both bash and PowerShell.

### Impact on agent sessions

- **Compound commands silently no-op.** An agent chaining a tag creation with its push (a
  natural, idiomatic release script) gets zero execution and a generic deny, with no signal that
  the `git tag` half was fine on its own — the agent has to already know to split multi-step git
  commands whenever a push is anywhere in the chain.
- **The "review" satisfied is meaningless for a tag push.** A fresh `.change-review-ok` marker
  before a release tag push reads as "the release was reviewed." It isn't — it's "some diff on
  whatever branch is currently checked out was reviewed," which may be entirely unrelated to the
  tag.
- **Extra tool-call overhead** for a routine, low-risk operation (pushing a tag to an
  already-green, already-merged, already-CI-passed commit).

## Options considered

1. **Exempt tag pushes from the gate.** A pushed ref that resolves to `refs/tags/*` doesn't
   introduce new code — whatever commit it points to either came through a branch push (already
   gated) or was created directly (a different, tag-specific check would be more honest, see
   option 3). Lowest implementation cost.

   **Caveat found during triage, not in the original report:** this cannot be a naming
   heuristic. `git push origin v1.8.0` is syntactically identical whether `v1.8.0` resolves
   locally to a tag or a branch — git itself disambiguates by asking the local ref store, not by
   the string looking tag-shaped. Any implementation must actually resolve the ref (e.g.
   `git show-ref --tags -- <name>` / `git rev-parse --symbolic-full-name <name>`, mirroring how
   `resolve_cd_root()` already asks git for ground truth rather than parsing text) before
   exempting — never infer "is a tag" from the ref string alone. Security-wise this is
   comfortably safe: exempting a *real* tag push cannot smuggle unreviewed code into `origin`,
   since a tag by itself changes no branch content.

2. **Parse the git subcommand more precisely so `git tag` isn't caught in the same deny as a
   chained `git push`.** Rejected — the file's existing design rationale (see the "WHY match raw
   stdin instead of extracting the command field" comment already in `review-reminders.sh`)
   already tried and abandoned finer-grained command-field extraction once, because it reopens a
   JSON-escaping bypass class. Also moot on its own: the hook denies per Bash-tool-call, not
   per-git-invocation, so even perfect subcommand parsing can't let `git tag` execute while
   blocking only the chained `git push` within the same tool call — the gate is inherently
   all-or-nothing per call.

3. **Make the check release-aware:** for a detected tag push, verify the tag's target commit is
   already an ancestor of `origin/main` (i.e., already merged, already gated at merge time)
   instead of demanding an unrelated fresh `/change-review` marker. More correct in principle,
   but can't handle the exact case in the report: in `git tag v1.8.0 origin/main && git push
   origin v1.8.0`, the tag doesn't exist yet when the hook fires (before either half of the
   compound has run), so there's nothing to check ancestry against until after the `git tag` half
   executes — which the current single-shot, pre-execution gate can't straddle.

4. **Pure-docs fix, no logic change:** document the current behavior and the 3-step workaround
   (isolate `git tag`, recompute `.change-review-ok`, then push) so future sessions don't have to
   rediscover it by trial and error. Lowest risk, doesn't fix the conceptual mismatch.

## Recommendation (not decided — for the session that picks this up)

**Option 1, implemented via real git ref resolution (not name matching), plus option 4
unconditionally.** Option 3 is more principled but doesn't actually cover the reported scenario;
option 2 is already ruled out by precedent. Whichever direction is chosen, add the 3-step
workaround to `docs/HOOKS-GUIDE.md` regardless, since it costs nothing and helps immediately.

## Scope if implemented (estimate, not final)

Same file set this session's tag-push-adjacent fixes have touched before: `scripts/review-reminders.sh`,
`scripts/review-reminders.ps1` (only the `PreToolUse` hook needs the ref check — the `PostToolUse`
companion only fires after a push already happened, so exempting there just changes which marker
it reconciles, if any), their `templates/scripts/` mirrors, `tests/test-review-reminders.sh`,
`docs/HOOKS-GUIDE.md` + template mirror. Likely warrants a Task Contract under this repo's own
protocol (4+ files).

## Source

Finding reported verbatim by the `ai-code-review-agent` session after hitting this live while
pushing tag `v1.8.0` post-merge of that repo's PR #15. Triaged and the ref-resolution caveat
added by the `personal-memory-bank` session on 2026-08-03, in the middle of an unrelated
in-flight fix (commit `f255c1d`, the review-gate additive-OR tokenizer fix) — deferred to this
branch rather than folded in, to keep that fix's diff scoped.
