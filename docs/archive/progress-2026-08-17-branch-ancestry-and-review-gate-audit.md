# Archived Progress — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit (2026-08-17)

Archived 2026-08-21 from `memory-bank/progress.md` to keep that file under its 400-line CI cap
(`.github/workflows/pmb-health.yml:23`). This was the oldest section still carried in full.

Status of the threads recorded here, as of archiving:

- **Branch-ancestry / PR #8:** resolved. PR #8 merged as `b0490ef` on 2026-08-19; the rebase plan
  described below was superseded — see `activeContext.md` `[NS-26]` (port, do not merge) and
  `[NS-3]`. The branch-deletion claim in the follow-up was itself wrong; see `[NS-4]`.
- **Handoff/compaction gap:** still open as `[NS-22]`, escalated 2026-08-19.
- **Standards-freshness gap:** still open as `[NS-23]`.
- **Review-gate hardening audit:** the `/change-review` Job 7 fallback divergence called out below
  is **still open — never fixed**, consistent with the body's own "not yet done" (`[NS-17]`'s Job 7
  item was the ACR exit-code path, a different fix). The `/code-review` domain-checklist question
  remains deferred.
- **`mb.sh`/`mb.ps1` version-check gap:** still open as `[NS-14]`; the three-version finding below
  is restated in that entry.

Condensed summary and pointers live in `memory-bank/progress.md` under the same date heading.

---

## 2026-08-17 (continued) — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit

- 🔴 **`feature/review-gate-layered-enforcement` cannot be cleanly rebased onto `main`** — attempted, hit
  immediate modify/delete conflicts on `_review-gate-lib.sh`/`.ps1` on the very first replayed commit.
  Root cause, confirmed via `git cat-file -e main:scripts/_review-gate-lib.sh` (fails — file does not
  exist on `main` at all) and `git merge-base --is-ancestor 39a8647 main` ("NOT an ancestor"): `main` is
  missing entire prerequisite review-gate infrastructure going back to commit `39a8647`
  (2026-07-16-ish), not just `docs/branch-protection-rollout`'s later commits. Rebase aborted cleanly
  (`git rebase --abort`, verified clean + `HEAD` unchanged). Root cause: PR #8
  (`docs/branch-protection-rollout` → `main`) has sat open, `MERGEABLE`/`CLEAN`, all 9 checks green,
  since 2026-07-09 — over a month unmerged — while local work kept stacking on top (69 commits ahead of
  `origin/docs/branch-protection-rollout` alone, confirmed via `git rev-list --left-right --count`).
  Decision: merge PR #8 first (after refreshing its now-stale CI run), so `main` catches up and the
  feature branch becomes a normal rebase — not yet executed as of this entry.
- 🔴 **`[NS-22]` — handoff/compaction protocol gap.** Two stale `handoff.md` files found: repo root
  (2026-08-03/04 session, confirmed untracked via `git ls-files --error-unmatch handoff.md` → error) and
  `.claude/worktrees/mystifying-hertz-c54477/handoff.md` (2026-07-27, mtime-confirmed). Neither was
  deleted per `CLAUDE.md:124`'s instruction ("merge its info into Memory Bank, delete `handoff.md`") —
  nothing enforces that step. Triggered by the user asking whether a handoff was written before today's
  compaction; the honest answer required manually diffing file mtimes against today's date, since no
  hook surfaces handoff freshness. This session's own compaction was not actually harmed — the
  `PreCompact` gate's alternate path (`progress.md` dated today) was already satisfied via this file's
  own same-day entry — but the near-miss and the two-path ambiguity (handoff.md vs. progress.md-dated
  gate, no way to tell from outside which fired) are real. Not designed yet.
- 🔴 **`[NS-23]` — standards-freshness gap.** No mechanism checks `standards/*.md` content against the
  external authorities it cites. Checked directly: only `PERFORMANCE-BUDGET.md`, `SECURITY-RULES.md`,
  `TRUST-CLASSIFICATION.md` carry `review-cycle`/`staleness-threshold` frontmatter (all `last-reviewed:
  2026-05-31`, ~2.5 months stale against their own 90-day cycle but not yet past the 180-day
  staleness-threshold). `ACCESSIBILITY.md` (asserts WCAG 2.1 AA), `SECURITY-GUARDRAILS.md`,
  `CODE-QUALITY.md` have no frontmatter at all — no tracked review cadence whatsoever. Even where the
  frontmatter exists, `grep`-confirmed no `mb doctor`/CI check references WCAG or OWASP version numbers
  — the mechanism only prompts a manual timer-based re-read, it does not verify against the standard's
  actual current published version. Not designed yet.
- 🔴 **`[NS-21]` update — review-gate command hardening audit.** Dispatched a focused, read-only audit of
  `/code-review`, `/security-review`, `/change-review` (user-requested, prompted by re-observing the
  `/code-review` Skill-tool shadowing bug live a third time during this session). Findings:
  - `/security-review` — solid, no issues.
  - `/code-review` — the 5 required domains (`standards/CODE-REVIEW.md:6-11`) are named but only
    Architecture Drift has a concrete definition; Security/Correctness/Maintainability/Testing subagents
    get the diff plus generic Severity/Blocking/Basis field defs and nothing else, so their findings rest
    on unconstrained model judgment with zero shared criteria against `/security-review`'s explicit
    9-pattern list. Marker-write hash logic and Opposition rigor are both solid.
  - `/change-review` — Job 7's inline security fallback (used whenever ACR is unavailable or its exit
    code is non-zero) has genuinely diverged from `/security-review`'s pattern list in **both**
    directions: it drops the XSS check (`security-review.md:24`) and the unsafe eval/exec check
    (`security-review.md:26`) entirely, while adding path traversal/template injection/dependency-audit
    items `/security-review` doesn't have. Confirmed via direct line comparison, not speculative — this
    means `/change-review` can silently produce weaker security coverage than running `/security-review`
    directly, especially on UI-touching diffs. Job 4 "Runtime Semantics" also folds 5 distinct concerns
    (env-defaults, async correctness, startup/shutdown ordering, rollback safety, race conditions) into
    one lens with no dedicated pass each, unlike the narrower Job 8 Accessibility which got its own job.
    Minor schema drift: `change-review.md` still carries both `Basis` and `Confidence` fields though
    `standards/CODE-REVIEW.md:87` says `Confidence` was removed.
  - Recommended first fix (not yet done): add the missing XSS and eval/exec patterns to Job 7's fallback
    list in `change-review.md`. The `/code-review` domain-checklist-sharing question is a bigger design
    call, deferred.
- 🔴 **`[NS-14]` update — mb.sh/mb.ps1 setup/upgrade scripts verified.** `tests/test-mb-init.sh` (19/19)
  and `tests/test-mb-upgrade.sh` (26/26) both green fresh, including the regression class that bit this
  project three times before (files silently missing from `TEMPLATE_OWNED`). Cross-checked the
  `TEMPLATE_OWNED` array against every file actually in `templates/` — full parity. One piece of debris
  found, not fixed (low priority): `templates/hooks/pre-push` is orphaned, unreferenced anywhere. Confirmed
  no global (`$HOME/.claude/`) install/upgrade path exists — every `TEMPLATE_OWNED` destination is
  project-relative; the only `$HOME/.claude/` touch is a read-only `mb doctor` comparison. Practical
  consequence: nothing in `mb.sh`/`mb.ps1` could push project-level fixes out to the user-level shadowing
  twins found in `[NS-21]` — that's a manual operation today.
  - Checked the version-check code directly per the user's "upgrade should look at local and the repo to
    verify we have the latest" concern: three distinct version values exist (target's `.pmb-version`, the
    local PMB source clone's `VERSION`, GitHub `main`'s true latest) and nothing compares all three —
    `mb doctor` only checks target-vs-local-clone (WARN-only), a separate notifier only checks
    local-clone-vs-GitHub. **Nothing compares target-vs-GitHub directly**, so a stale local PMB clone makes
    `mb doctor` report "up to date" even when genuinely behind upstream. Sharpens `[NS-14]`'s existing
    finding (nothing *triggers* a check) with a second gap: a triggered check can still give a false "OK"
    if its own reference point is stale. Not designed yet.

