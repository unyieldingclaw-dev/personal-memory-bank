# Review-Gate Hook Tag-Push Exemption

**Date:** 2026-08-03
**Status:** Implemented (Option 1 + 4, as recommended below).

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

## Recommendation (implemented)

**Option 1, implemented via real git ref resolution (not name matching), plus option 4.**
Option 3 was reconsidered during implementation and confirmed unworkable for the exact reported
case: the tag doesn't exist yet when the hook fires, so there's nothing to check ancestry
against. Option 2 was already ruled out by precedent.

**One refinement found during implementation, not anticipated in the original triage:** ref
resolution via `git show-ref` alone is insufficient for the reported scenario, because
`git tag v1.8.0 origin/main && git push origin v1.8.0` fires the `PreToolUse` hook *before*
either half of the compound command has run — the tag genuinely doesn't exist locally yet.
The implementation additionally recognizes a tag as exempt when the *same compound command*
creates it via its own `git tag <name> ...` half (regardless of whether that name already
existed), since tag creation is safe for the identical reason a tag push is: it only labels an
existing commit, never introduces new code, regardless of whether the label already existed.
This is what actually closes the reported bug, not `show-ref` resolution alone.

## Scope (as implemented)

`scripts/review-reminders.sh` (`tag_only_push()`, python3), `scripts/review-reminders.ps1`
(`Test-TagOnlyPush`/`Test-ExistingTag`, native PowerShell — no new dependency), their
`templates/scripts/` mirrors, `tests/test-review-reminders.sh` (18 new tests: bug-report
scenario, existing-tag push, `--tags`, and negative controls for branch pushes, bare/remote-only
pushes, tag/branch name collisions, mixed multi-ref pushes, the raw-stdin-fallback safety gate,
and a compound commit+tag-push where only the push half is exempted), `docs/HOOKS-GUIDE.md` +
template mirror. `review-reminders-post.sh`/`.ps1` needed no changes, confirming the original
scope estimate: an exempted push never has `.pending-push-presha` written by the `PreToolUse`
hook, so the `PostToolUse` companion's existing "reissue only if that file exists" check already
no-ops correctly.

**A PowerShell-specific bug found and fixed during implementation, unrelated to the design
itself:** `Test-TagOnlyPush` initially threw `InvalidOperation: [System.Char] does not contain a
method named 'StartsWith'` on any single-token push-args case (e.g. `git push --tags`).
Root cause: PowerShell unwraps a 1-element array to its bare scalar element at TWO separate
points — first, `$array[N..N]` (a range resolving to exactly one index) returns the element
itself, not a 1-element array; second, and independently, capturing a scriptblock's `return`ed
1-element array via plain assignment (`$x = & $scriptblock ...`) unwraps it *again* at the call
site, even after the first point was fixed inside the scriptblock. Both had to be wrapped in
`@(...)` independently — fixing only one reintroduced the bug for exactly the 1-token case.
Reproduced and fixed via isolated debugging before it reached the real hook flow.

Task Contract used per this repo's own protocol (7 files, security-sensitive domain).

## MEDIUM-HIGH bypass found by a SECOND opposition-review pass, also fixed before push

After the colon-refspec fix below was applied, a second, independent opposition-review pass
(deliberately requested to hunt for a DIFFERENT bug, not just re-confirm the first fix) found
that `created_tag_names`/`is_existing_tag` were trusted purely on the tag NAME resolving
safely, with **zero check on what commit the tag actually pointed at**. `git tag foo
<any-unreviewed-local-commit> && git push origin foo` was exempted regardless of whether that
commit had ever gone through review. Confirmed empirically (both via raw git and via the real
hook scripts) that this doesn't overwrite any branch — a tag push alone never moves a branch
ref — but it DOES unconditionally upload the tagged commit's objects to the remote's object
store with zero review. This is a real, distinct bypass of this review gate's core purpose
(preventing unreviewed content from reaching the remote), just not the branch-overwrite flavor
the first pass found — and it means the original "a tag pointer doesn't change any branch's
content, so a tag push cannot introduce unreviewed code into origin" framing above was
narrower than what was actually true: accurate for branch integrity, misleading for content
publication.

Fixed via `is_ancestor_of_main()` (`.sh`) / `Test-AncestorOfMain` (`.ps1`): the tagged commit
must already be an ancestor of `origin/main` — i.e. already reviewed and published through the
ordinary commit+push gate — before the exemption is granted, for both the same-command
tag-creation case (now tracking `git tag <name> <ref>`'s target ref, not just the name) and the
already-existing-tag case (peeling the tag to its target commit via `git rev-parse
...^{commit}`). This still correctly exempts the original reported scenario — tagging
`origin/main` itself is trivially its own ancestor — and doesn't reopen the "tag doesn't exist
yet when this hook fires" problem, since the check resolves the ref BEING tagged, not the tag
object itself. Fails closed if `origin/main` doesn't resolve at all, rather than falling back
to `HEAD` — a fallback would weaken the exact property being enforced, since `HEAD` may itself
be unreviewed local content.

An operational incident occurred during this second review pass, unrelated to the code itself:
the opposition subagent's sandbox setup had a `cd` silently fail inside a chained command
that had actually already been denied by this very hook, causing a LATER command in a
separate tool call to execute against the real project worktree instead of the intended
scratch sandbox — resulting in an actual (harmless, since it pointed at an already-public
commit) tag push to the live GitHub remote. The subagent correctly refused to bypass the
review gate to clean it up itself (`git push origin --delete <tag>` was denied, as designed)
and flagged it for manual cleanup instead, which the user then did directly.

6 new regression tests lock in the ancestor-check fix (an unreviewed local commit tagged and
pushed in one command; a pre-existing tag pointing at unreviewed content; and sanity checks
for both `.sh` and `.ps1` that a tag pointing at genuinely reviewed content is still exempt).

## CRITICAL bypass found by opposition review, fixed before push

Before this feature was ever pushed, an opposition-review pass on the first implementation
found a real, empirically-reproducible bypass: `src = positional[1].split(':', 1)[0]` validated
only the SOURCE side of a `src:dst` refspec. For `git push <remote> <src>:<dst>`, git updates
the REMOTE ref named `dst` with whatever `src` resolves to locally — the ref that actually
changes on `origin` is `dst`, not `src`. Since the check only looked at `src`, any existing tag
name satisfied it regardless of which side of the colon it appeared on: `git push origin
<any-existing-tag>:main` was wrongly exempted, checking out as safe because the tag name was
real, while the actual effect was overwriting `main` with unreviewed (or force-pushed,
history-rewriting) content, no marker required, no deny at all. This required no adversarial
crafting — it works with any tag a repository already has, which is nearly all of them.
Reproduced end-to-end (bare remote + clone, unreviewed local commit, tag it, push
`<tag>:main`, confirm the unreviewed content lands on `origin/main`) against both `.sh` and
`.ps1`, including `--force` variants and arbitrary destination branches.

Correctly resolving `dst` would require querying the REMOTE's own ref-name disambiguation
(an unqualified `dst` can resolve differently depending on what already exists there) from
inside a synchronous `PreToolUse` hook, with no network round-trip available. Rather than
approximate that with a local heuristic still fundamentally guessing at remote state, the fix
is simpler and safer: **any refspec containing a colon is never exempt**, regardless of what
the source side resolves to — the same "unrecognized shape costs an unnecessary re-review,
never grants an unearned exemption" rule the rest of this design already follows. 5 new
regression tests lock this in (the exact `<tag>:main` PoC, a force-push variant, and a sanity
check that the plain no-colon form of the same tag is still correctly exempted, so the fix
didn't over-correct).

## Source

Finding reported verbatim by the `ai-code-review-agent` session after hitting this live while
pushing tag `v1.8.0` post-merge of that repo's PR #15. Triaged and the ref-resolution caveat
added by the `personal-memory-bank` session on 2026-08-03, in the middle of an unrelated
in-flight fix (commit `f255c1d`, the review-gate additive-OR tokenizer fix) — deferred to this
branch rather than folded in, to keep that fix's diff scoped.
