# Archived: `progress.md` 2026-09-21 → 2026-09-25 — three sections relocated 2026-10-05

**Relocated from `memory-bank/progress.md` on 2026-10-05, verbatim.** The three sections below the
first `---` were extracted mechanically (`sed -n '47,109p'` of the pre-move file) and compared
byte-for-byte with the source before it was cut. Nothing was summarised or reflowed.

**Why:** PR #51's owed memory-bank delta (`[NS-64]`, `[NS-65]`, two addenda, a dated entry) and the
PR #53 follow-ups had to fit under the aggregate startup-context ratchet, which stood at zero
margin against `origin/main` after #53 merged. `progress.md` was also at 491 of its 500-line cap.
**Delta, not a level: 4,673 bytes and 63 lines moved out**, measured on the extracted range before
the move. All three narratives concluded before it: the 09-21 audit is done, the 09-22 plan reviews
finished (execution is `[NS-59]`), and PR #46 merged.

**The 2026-09-11 entry was deliberately NOT moved.** `activeContext.md` names it the source record
of the whole-repo review's open findings, so its work is not complete, and the Eviction Criteria
permit moving only completed entries.

**Citation survival was grep-verified before the move.** `[NS-13]` and `[NS-55]` cite
`progress.md` 2026-09-21, and `[NS-59]` cites 2026-09-22. Each original heading stays listed in
`progress.md`'s stub, so those references still resolve.

---

## 2026-09-24 → 25 — PR #46 merged; local `main` reconciled; two more merge-gate escapes

- **PR #46 merged as `739f0eb`.** Local `main` held `7b70f01`, an unpushed commit duplicating #46 at
  older versions: kept on `archive/orphaned-7b70f01`, then `git branch -f main origin/main` (ref
  only, not `reset --hard`). Seven stale working-tree duplicates deleted, each byte-identical there.
- **`[NS-63]`:** a peer in an adopter repo reported two classifier escapes, reproduced at hook level
  and folded into the merge-gate backlog item. The handoff misstated both: `.py` does have a
  basename helper (the wrapper skip never calls it), and a quoted `-R` is not new — unquoted already
  escapes. Checked against the classifier before writing.
- **Release-policy field incident (peer-reported, not reproduced):** an adopter's `mb upgrade`
  pulled a mid-PR PMB tree, receiving scripts whose comments claimed fixes not wired there — the
  dirty-tree hazard the release contract names, not `[NS-19]`'s template drift. The only version
  tags, local and remote, are `v1.0.1` and `v1.0.4`; none cut under the decided policy.

## 2026-09-22 — Pre-Approval Protocol plan: six review rounds, and my "Approve" was wrong twice

- **The spec and plan are final** (`[NS-59]`). A fresh reviewer found that the round-3-approved plan
  would turn CI red: `tests/test-mirror-parity.sh:354-421` pins the live Stop wiring to the
  template's. It found 15 more:
  - stage before `/code-review`, because `git diff HEAD` omits untracked files;
  - UTF-8 stdin in both twins;
  - fail-open trial logging;
  - a loop-guard test gap;
  - a HEAD snapshot too weak to see a staged edit.

  The plan was revised for those findings and specifies tests intended to fail when each fix is
  removed. The implementation and its tests have not run yet.
- **The parity fix flip-flopped.** I recommended A (an exemption), then F (a feature flag), then A
  again. An independent review showed F would reverse approved decisions, and that `mb upgrade`
  never deletes scripts, so a failed trial would leave dead code in every adopter. The user
  chose A+: the exemption plus a CI hard-fail expiry.
- **Found, not fixed:** `templates/.claude/settings.json` installs the modal Stop popup that both
  `HOOKS-GUIDE.md` copies call excluded. `71d5899` removed it deliberately, and `f976530` put it
  back silently. This is an open user decision.
- **Traps (auto-memory):**
  - `MB_HOME` makes a scratch clone's `mb.sh` install the real repo's templates; a test fired
    real popups.
  - Two scratch harnesses produced invalid runs. Assert every edit and every copy, and never
    trust a green that has no `Results` line.

## 2026-09-21 — Next-Steps audit; NPM_TOKEN resolved; false "unmerged" claims found

Set out to verify all 50 active `[NS-N]` entries against live state, not their own text (8 batches +
a 9th fixing a self-caught gap). **Blind spot, found by a 2nd opposition round: grepping for
"unmerged"-style phrasing missed 2 entries stale in different words** — `[NS-8]` (`mb.sh` no longer
hardcodes; deleted) and `[NS-29]` (both agents have had `model:` since 2026-08-26; corrected to keep
only the real `effort:` gap). `[NS-11]` resolved — ACR's OIDC migration removed `NPM_TOKEN`
(ACR `cd57cf5`, `CHANGELOG.md` v1.12.1). `[NS-41]`/`[NS-45]`/`[NS-43]`(b) falsely claimed "unmerged"
work already live on `main`, found by
grep, deleted/trimmed. Other corrections: `[NS-4]` branches both live, pure cleanup; `[NS-42]` write
rate dropped ~92%, gap still open; `[NS-25]` reproduced live twice, raised; `[NS-17]` NOT actually
resolved; `[NS-16]` dropped sub-item restored.

**`[NS-13]` corrected twice.** Deleted on a shallow check, restored by 3 domain reviewers as
"unmerged work" via `git merge-base --is-ancestor` — opposition proved that test false-negatives in
this shallow, squash-merged repo. Content-diffed instead: **zero** novel files (vs. `[NS-3]`'s 7,
`[NS-18]`'s 6), 26,347 deletions *behind* main. Real state: hook never implemented anywhere, only
artifact an uncommitted plan edit. Root cause: `code-review.md` missing `--no-fetch` (`[NS-55]`, 3rd
hit) — fixed, but the first attempt missed its `templates/claude-commands/` mirror; `tests/test-mirror-parity.sh`
caught the drift before merge (would've shipped red CI, self-reverting via `mb upgrade`). Both copies
now identical. `[NS-33]`'s stash cite hardened too — a prior `stash@{0}` cite is already a different
stash today; now keyed off message. **Cross-session:** `mb upgrade` force-overwrite confirmed for the
ACR peer, deferred; "Token waste audit" peer answered, their hardcoded-caps finding logged `[NS-57]`.
