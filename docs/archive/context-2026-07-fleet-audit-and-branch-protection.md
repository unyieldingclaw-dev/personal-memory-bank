# Archived Context: Fleet Audit + Branch-Protection Rollout (2026-07-04 through 2026-07-13)

Archived from `memory-bank/activeContext.md` on 2026-08-14. Full narrative detail. The follow-ups this
audit produced ([NS-6], [NS-7], [NS-12], [NS-14]) are tracked in `memory-bank/activeContext.md`'s
`Next Steps` list, not here.

## Branch Protection Rollout & CI Hardening (2026-07-04 through 2026-07-08)

**Branch protection rollout complete (2026-07-08)**: applied to the 5 public PMB-based repos
(`personal-memory-bank`, `ai-code-review-agent`, `pitlogic`, `Spotify-Road-Trip`, `Pit-timer`) —
`enforce_admins: true`, `required_pull_request_reviews` (0 approvals, PR required even for the owner),
`required_status_checks.strict: true` with each repo's own real CI checks. **Workflow change**: direct
`git push origin main` now rejected on all 5 — every change must go through a branch + PR + passing
checks, including the user's own commits. Confirmed via `gh api ... branches/main/protection` GET on
all 5. Private repos (`Bowling-Tracker`, `gmail-organizer`, `tipsy-bunghole`, `side-quest-atlas`,
`Nolan-Budget`, `rfx-data-analytics`) are explicitly out of scope — GitHub Free blocks both branch
protection and rulesets entirely on private repos; user chose to skip rather than upgrade to Pro or
make them public.

Also fixed along the way: `PowerShell Lint` had been red on `main` since a prior session's merge
(`Get-TemplateDirFiles` tripped `PSUseSingularNouns`) — fixed by renaming to `Get-TemplateDirFile`
(commit `a350aa6`).

**Process gap identified and corrected**: mid-session, discovered that pushes to personal-memory-bank
had been using a self-computed `.change-review-ok` hash instead of actually running `/change-review` —
meaning ACR never ran its Job 7 security check on those pushes. `/change-review` is the correct,
designed push-gate command; going forward, always run it before push rather than hand-computing the
hash.

**CI-hardening task contract complete (2026-07-06)**: fixed the two red mains found in the
branch-protection planning pass (`Bowling-Tracker`, `gmail-organizer`), then applied a
"continue-on-error + gate" pattern across all 4 PMB-based repos so a failing early CI step can never
again mask a later real failure for weeks. Also created `AI-Code-Review-Agent/.github/workflows/ci.yml`
from scratch — that repo had no push/PR CI gate at all.

**PMB v1.2.0/v1.2.1**: doctor suite 35/35 passing, all 9 CI jobs confirmed green on PR #7 (`b1105e3`)
as of 2026-07-04; `/change-review` gained a Baseline Repo Health spot-check; fixed a
`templates/docs/` scaffolding gap.

## Review-Flow Fleet Audit (2026-07-13)

Audited all 11 repos' actual review-flow coverage (GitHub API + local `git status`, not estimates)
after being asked "do we have a proper review flow advising all projects." Findings: real enforcement
(hook wired + required CI check + current template) exists in exactly 2 of 11 —
`personal-memory-bank`, `ai-code-review-agent`. Everything else has at most a PR-required wrapper with
no content gate. Root causes, confirmed by reading `Invoke-Upgrade` in `scripts/mb.ps1`: (1)
`install.bat` pointed users at a stale onboarding script name (fixed, commit `949b052`). (2) No
fleet-wide command exists anywhere in `mb.ps1` and no manifest tracks which local repos are
PMB-managed — nothing pushes updates outward or reminds a stale repo to resync, so drift is
structural, not accidental. (3) CI-workflow generation is deliberately out of `templates/` scope, so
some repos lacking a required status check is unfixable by `mb upgrade` regardless.

Also found real **local-vs-GitHub drift** the GitHub-only audit missed: `Nolan-Budget`'s local
`.pmb-version` reads `1.2.1` (current) but was never committed/pushed — GitHub shows zero PMB
footprint for a repo that's actually the most up-to-date one locally. Most other local repos had real
uncommitted/unpushed work in progress — deliberately did not run `mb upgrade` against any of them from
this session, per the cross-repo write boundary rule.

`rfx-data-analytics` (empty repo, superseded by `pitlogic`) — deletion attempted but blocked: this
session's `gh` auth lacks the `delete_repo` OAuth scope.

**`update-reviewed` hook fixed:** `scripts/update-reviewed.ps1`/`.sh` had the same flat-vs-nested
`tool_input.file_path` bug already fixed elsewhere, just never applied here — `last-reviewed:`
auto-stamping had silently never worked, on either platform, since introduction. Fixed and
live-confirmed.
