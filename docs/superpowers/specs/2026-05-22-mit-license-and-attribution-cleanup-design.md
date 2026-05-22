# MIT License & Attribution Cleanup — Design

**Date:** 2026-05-22
**Status:** Approved

## Context

All personal projects under `C:\Users\Mizzo\Claude\` need to carry an MIT License attributed to Eric Nolan. Previously:

- `Personal-Memory-Bank` had a LICENSE file but the copyright holder was wrong (`T-Mobile Release Engineering/AERO Team`).
- `Google-Organizer`, `Nolan-Budget`, and `rfx-cook-tracker` had no LICENSE file at all.
- `Personal-Memory-Bank` contained ~40 additional T-Mobile references scattered across standards, templates, and historical design/plan docs.
- `Memory-Bank` is the enterprise source repo — T-Mobile references there are expected and were **not** touched.

The intended outcome is that every personal project carries `Copyright (c) 2026 Eric Nolan` and no personal project file contains a T-Mobile attribution.

## Scope

| Project | Action |
|---------|--------|
| Personal-Memory-Bank | Replace all T-Mobile refs with `Eric Nolan`; fix LICENSE |
| Google-Organizer | Add new MIT LICENSE |
| Nolan-Budget | Add new MIT LICENSE |
| rfx-cook-tracker | Add new MIT LICENSE |
| Memory-Bank | **Skip — enterprise repo, T-Mobile refs expected** |

## MIT License Template

All LICENSE files use this exact text (copyright holder = `Eric Nolan`, year = `2026`):

```
MIT License

Copyright (c) 2026 Eric Nolan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Phase 1 — Personal-Memory-Bank: T-Mobile Scrub

**Approach:** Two-pass PowerShell replacement across all non-binary, non-`.git` files.

**Pass 1 — team strings (must run first to avoid partial replacements):**
- `T-Mobile Release Engineering/AERO Team` → `Eric Nolan`
- `T-Mobile Release Engineering / AERO` → `Eric Nolan`

**Pass 2 — remaining standalone mentions:**
- `T-Mobile` → `Eric Nolan`

**Known affected files:**
- `LICENSE` (root)
- `.claude/worktrees/keen-bohr-fa0bc9/LICENSE`
- `.claude/worktrees/sweet-williamson-66f079/LICENSE`
- `CHANGELOG.md`
- `memory-bank/progress.md`
- `docs/superpowers/specs/2026-04-29-personal-fork-design.md`
- `docs/superpowers/specs/2026-05-01-personal-standard-modernization-design.md`
- `docs/superpowers/plans/2026-04-29-personal-fork.md`
- `docs/superpowers/plans/2026-04-21-v1.4-audit-and-update.md`

**Owner lines** (`**Owner**: T-Mobile Release Engineering/AERO Team`) become `**Owner**: Eric Nolan` via Pass 1.

## Phase 2 — Add LICENSE to Three Projects

Create `LICENSE` at the root of each:
- `C:\Users\Mizzo\Claude\Google-Organizer\LICENSE`
- `C:\Users\Mizzo\Claude\Nolan-Budget\LICENSE`
- `C:\Users\Mizzo\Claude\rfx-cook-tracker\LICENSE`

All use the template above.

## Phase 3 — Commits

One commit per project, all on the existing default branch (no new branches needed):

| Project | Commit message |
|---------|----------------|
| Personal-Memory-Bank | `chore: replace T-Mobile attribution with Eric Nolan` |
| Google-Organizer | `chore: add MIT license` |
| Nolan-Budget | `chore: add MIT license` |
| rfx-cook-tracker | `chore: add MIT license` |

## Verification

1. `grep -r "T-Mobile" C:\Users\Mizzo\Claude\Personal-Memory-Bank --exclude-dir=.git` → zero results
2. `cat C:\Users\Mizzo\Claude\Personal-Memory-Bank\LICENSE` → line 3 reads `Copyright (c) 2026 Eric Nolan`
3. Confirm LICENSE exists at root of Google-Organizer, Nolan-Budget, rfx-cook-tracker
4. Spot-check one standards file (`standards/ACCESSIBILITY.md`) — Owner line reads `**Owner**: Eric Nolan`
