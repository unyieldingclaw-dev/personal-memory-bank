# Archived: `progress.md` 2026-09-12 through 2026-09-14 — three sections, moved verbatim 2026-09-18

**Relocated from `memory-bank/progress.md` on 2026-09-18**, unchanged. **Verbatim, not summarised** —
the same precedent as every relocation above it in `progress.md`.

**Why:** logging today's PR #28/#29 merge and the `[NS-54]` cross-session flag broke the aggregate
startup-context ratchet (`CLAUDE.md` + all `memory-bank/*.md`) against `origin/main`'s baseline — a
required, admin-enforced `File Size` CI check that may shrink, never grow. **Delta, not a level:
3,892 bytes moved out of `progress.md`** (this file's own verbatim body). No before/after total is stated here on purpose — see
`docs/archive/progress-2026-08-19-to-21-escalation-and-bundle-1.md` for why a level would be false
the moment anything else in that file changed. These were the oldest full-detail sections not yet
relocated (the 2026-08-12 and earlier material below them in `progress.md` was already condensed to
archive-pointers on 2026-08-23/29).

**Citation survival was grep-verified before the move**: `grep -n "2026-09-1[234]" memory-bank/activeContext.md`
found two references — `[NS-37]` and `[NS-51]`, both reading "Full record: `progress.md` ... 2026-09-13→14"
— updated in the same commit to point at this file instead of the live `progress.md` sections they
named.

---

## 2026-09-14 — baseline-health's CI-only failure was a shallow nested-clone ref assumption

`tests/test-baseline-health.sh` passed locally but its two `--no-fetch` ratchet assertions failed in
`MB Command Tests`. Reproducing Actions' actual topology (shallow checkout, `origin/main` fetched,
detached HEAD, no local branch) produced 42 pass / 2 fail: `new_sandbox` cloned the checkout and
assumed that carried `origin/main`. It does not -- clone sources do not advertise remote-tracking
refs, so the nested sandbox could not perform the comparison once `--no-fetch` suppressed recovery.
The first correction used a direct local refspec transfer and passed a detached but non-shallow
reproduction. It still failed in CI: from a shallow source Git copied the object, rejected the ref
update, and returned success, leaving the same advisory skip hidden behind a green setup command.

**Fixed in the harness only:** `new_sandbox` fetches the source checkout's already-fetched main
object via the local repository path, then creates and verifies `refs/remotes/origin/main` as a
separate step. This performs no network access and leaves `scripts/baseline-health.sh`'s fetch
interceptor unchanged. The identical shallow, detached topology is green at 44 pass / 0 fail after
the change.

## 2026-09-13 — check 15's real cause found and fixed: `$env:USERPROFILE`, not the bracket glob

The 2026-09-12 entry below attributed check 15's CI failure to the bracketed-`MB_HOME` divergence
(`[NS-51]`). That attribution was wrong, not merely incomplete: reproduced in Docker
(`mcr.microsoft.com/powershell:latest`, matching `ubuntu-latest`'s no-`cygpath` code branch of
`tests/test-mb-doctor.sh` -- a Windows-side repro attempt takes the OTHER branch and passes clean,
which is why this took a second look). The real error, `Cannot bind argument to parameter 'Path'
because it is null`, comes from `scripts/mb.ps1:112` and `:1233` -- both used
`Join-Path $env:USERPROFILE ...`, a Windows-only env var that is null on Linux/macOS pwsh. (`:113`,
`:117`, `:147` merely consume the already-computed path; they are not independent bug sites, despite
what this entry said on first write.) Non-terminating error, so `doctor` still completed and looked
healthy afterward -- but the forbidden string still appeared and failed the assertion.

**Fixed**: both sites now use `$HOME`, matching `scripts/mb.sh`'s existing identical pattern
(`$HOME/.mb`, `$HOME/.claude/CLAUDE.md`). Verified via a 4-domain code-review (Security/Correctness/
Testing/Maintainability+Architecture-Drift): Architecture Drift caught that this entry's first draft
wrongly claimed `mb.ps1` needed a `templates/` TEMPLATE_OWNED mirror -- neither `mb.sh` nor `mb.ps1`
appears in either script's own TEMPLATE_OWNED array, and the CLI ships via `git clone`, not
`mb upgrade`; no mirror exists or is needed. Testing found the existing check 15 coverage of this
class was real but accidental (a generic string match, true only because CI happens to run
`ubuntu-latest`) and that `tests/test-mb-version-notifier.sh` never exercised the actual `$HOME`
fallback branch (both its pwsh invocations always override `MB_VERSION_CACHE_DIR`). Added a dedicated,
Linux/macOS-gated test there, mutation-proven red-on-revert/green-on-fix in the same Docker image.

## 2026-09-12 — PR #25 stays red after the grep-portability fix; a second, pre-existing failure

`tests/test-mb-doctor.sh:1079`, check 15's `Resolve-Path`-throws assertion, fails on Linux `pwsh` in
CI (run `34683137897`) alongside the grep-mutation failure fixed on `fix/baseline-health-ci-portability`
-- independent of it, not introduced by either branch. Manifestation of the bracketed-`MB_HOME`
divergence `CHANGELOG.md:58` already tracks as narrowed, not closed, and `[NS-51]` points at the audit
spec for. **Corrected 2026-09-13: this attribution was wrong — see the entry above.**
