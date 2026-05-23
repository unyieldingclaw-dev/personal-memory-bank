# Governance Integrity Design

**Problem:** Adopted projects have phantom governance. `mb init` copies `.claude/settings.json` — which references hook scripts — but never copies the hook scripts themselves. The hooks appear active but silently no-op. `mb doctor` has no check for this condition.

**Solution:** Two coordinated fixes.
1. Make `templates/scripts/` the canonical home for hook scripts; `mb init` copies them from there.
2. Extend `mb doctor` Check #4 to verify each referenced hook script actually exists on disk.
3. Add a CI step that validates `templates/.claude/settings.json` references only scripts that exist in `templates/scripts/`.

---

## Section 1: File Structure

### Current state

```
scripts/
  mb.sh                   # runtime tooling
  mb.ps1                  # runtime tooling
  init-memory-bank.sh     # legacy wrapper
  init-memory-bank.ps1    # legacy wrapper
  dangerous-commands.sh   # hook script ← should be in templates/
  dangerous-commands.ps1  # hook script ← should be in templates/
  check-contract.sh       # hook script ← should be in templates/
  check-contract.ps1      # hook script ← should be in templates/
  update-reviewed.sh      # hook script ← should be in templates/
  update-reviewed.ps1     # hook script ← should be in templates/

templates/
  .claude/settings.json   # references scripts/dangerous-commands.sh etc.
  CLAUDE.md
  memory-bank/
  claude-commands/
  # NO scripts/ directory
```

### Target state

```
scripts/
  mb.sh                   # runtime tooling only
  mb.ps1                  # runtime tooling only
  init-memory-bank.sh     # legacy wrapper
  init-memory-bank.ps1    # legacy wrapper

templates/
  scripts/                # ← NEW: canonical adoptable hook scripts
    dangerous-commands.sh
    dangerous-commands.ps1
    check-contract.sh
    check-contract.ps1
    update-reviewed.sh
    update-reviewed.ps1
  .claude/settings.json   # unchanged (already references scripts/X correctly)
  CLAUDE.md
  memory-bank/
  claude-commands/
```

**Key constraint:** `templates/.claude/settings.json` references hooks as `scripts/dangerous-commands.sh` etc. — relative to the adopted project root, not to the mb repo. This path is already correct: after `mb init`, an adopted project has `scripts/` at its root. No path changes to `settings.json` are needed.

**The 6 hook scripts (explicit allowlist):**
- `dangerous-commands.sh` / `dangerous-commands.ps1`
- `check-contract.sh` / `check-contract.ps1`
- `update-reviewed.sh` / `update-reviewed.ps1`

### Why `templates/scripts/` is canonical

`templates/` is the production adoptable surface — the thing this repo distributes. Scripts that adopt projects depend on belong there, not in runtime-internal `scripts/`. This eliminates a synchronization class entirely: `templates/scripts/` is the source of truth for what hook scripts look like; `scripts/` retains no copy.

---

## Section 2: Component Behavior

### 2a. `mb init` — explicit allowlist copy

`invoke_init()` in `mb.sh` (and equivalent in `mb.ps1`) adds a new block after the `.claude/settings.json` copy:

```bash
# Hook scripts (explicit allowlist — prevents accidental export of future internal files)
for script in dangerous-commands.sh dangerous-commands.ps1 \
              check-contract.sh check-contract.ps1 \
              update-reviewed.sh update-reviewed.ps1; do
    copy_if_new "$TEMPLATES_DIR/scripts/$script" "$TARGET/scripts/$script" "scripts/$script"
done
```

Why explicit over glob: `templates/scripts/*` would silently export any future file added to that directory. An allowlist makes the export surface intentional and auditable.

### 2b. `mb doctor` Check #4 — hook script existence

The current Check #4 verifies `.claude/settings.json` exists and has a `PostToolUse` hook. Extend it to also verify each referenced hook script exists.

**Parser behavior:** Extract hook script paths from `"command":` lines in `.claude/settings.json`. Match the pattern `scripts/<basename>.<ext>` on `"command":` lines only. Do not match arbitrary strings containing `scripts/` — this keeps signal quality high if the file gains other references.

**Platform handling — logical hook targets:** For each unique basename found (e.g., `dangerous-commands`), warn if *neither* `scripts/<basename>.sh` nor `scripts/<basename>.ps1` exists. Warn only once per basename. This is platform-neutral: a Linux-only project that has only `.sh` files passes; a Windows-only project with only `.ps1` files also passes.

**Output format:**
```
[OK]   Hook scripts present (dangerous-commands, check-contract, update-reviewed)
[WARN] Hook script missing: dangerous-commands — run 'mb init' to install
```

**Severity:** `[WARN]` (yellow). Never `[ERROR]`. Always exits 0. Matches existing doctor philosophy.

**Scope:** Check only scripts referenced in `.claude/settings.json`. Do not enumerate templates or make assumptions about what scripts should exist. The settings file is the authoritative list.

### 2c. CI — template integrity step

Add a step to `.github/workflows/governance.yml` that validates every `scripts/<name>` path in `templates/.claude/settings.json` resolves to at least one file in `templates/scripts/`.

**Behavior:**
- Parse `"command":` lines in `templates/.claude/settings.json`
- Extract basenames (e.g., `dangerous-commands` from `scripts/dangerous-commands.ps1`)
- For each unique basename, check `templates/scripts/<basename>.sh` or `templates/scripts/<basename>.ps1` exists
- On failure: explicit error naming the missing file, non-zero exit

**Example failure output:**
```
ERROR: templates/.claude/settings.json references scripts/dangerous-commands but
       neither templates/scripts/dangerous-commands.sh
       nor    templates/scripts/dangerous-commands.ps1 exists.
```

This is a CI-only check. Doctor doesn't call `mb` sub-commands or shell out to external validation; doctor reads files directly.

### 2d. Documentation update

Add a comment to `templates/scripts/` (via a `README.md` in that directory) and to `scripts/` noting the boundary: `scripts/` is internal runtime tooling for the mb CLI itself; `templates/scripts/` is the production adoptable surface that `mb init` distributes to projects.

---

## Section 3: Platform Handling

### Doctor — logical hook targets

The doctor check normalizes to basenames before checking existence:

```bash
# Extract basenames from "command": lines in .claude/settings.json
# e.g., "scripts/dangerous-commands.ps1" → "dangerous-commands"
BASENAMES=$(grep '"command":' .claude/settings.json \
  | grep -oP 'scripts/\K[^.]+(?=\.(sh|ps1))' \
  | sort -u)

MISSING=()
for base in $BASENAMES; do
    if [ ! -f "scripts/${base}.sh" ] && [ ! -f "scripts/${base}.ps1" ]; then
        MISSING+=("$base")
    fi
done
```

Warn once per missing basename. No per-file output for present scripts — aggregate OK line only.

**Why not check each `.sh` and `.ps1` separately:** Producing warnings for a missing `.ps1` on a Linux-only machine is noise. The governance intent is: can this script fire? If either platform variant exists, it can.

**Verbose mode (optional, not in this iteration):** If `mb doctor --verbose` is ever added, it could print platform parity info (e.g., `[INFO] scripts/dangerous-commands: .sh present, .ps1 missing`). Not in scope now.

---

## Constraints

- **Always exit 0** — WARN tier, never blocks. Matches hook/doctor philosophy.
- **No sync script** — `templates/scripts/` is canonical; `scripts/` has no hook scripts after migration. No mirroring needed.
- **Explicit allowlist in mb init** — not a glob. Export surface is intentional.
- **Narrow parser in doctor** — only `"command":` lines, not all strings.
- **Immutable basenames** — the 6 basenames are fixed. If new hook scripts are added later, the mb.sh allowlist and this spec are updated together.
- **No breaking changes** — adopted projects that ran `mb init` before this change still work. They just won't have the hook scripts until they re-run `mb init`.

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/dangerous-commands.sh` | Move to `templates/scripts/dangerous-commands.sh` |
| `scripts/dangerous-commands.ps1` | Move to `templates/scripts/dangerous-commands.ps1` |
| `scripts/check-contract.sh` | Move to `templates/scripts/check-contract.sh` |
| `scripts/check-contract.ps1` | Move to `templates/scripts/check-contract.ps1` |
| `scripts/update-reviewed.sh` | Move to `templates/scripts/update-reviewed.sh` |
| `scripts/update-reviewed.ps1` | Move to `templates/scripts/update-reviewed.ps1` |
| `scripts/mb.sh` | Extend `invoke_init()` with hook script copy block; extend Check #4 with existence check |
| `scripts/mb.ps1` | Same as mb.sh, PowerShell equivalent |
| `.github/workflows/governance.yml` | Add template integrity validation step |
| `templates/scripts/README.md` | Document `templates/scripts/` as production adoptable surface |
| `.claude/settings.json` | Update hook commands from `scripts/X` to `templates/scripts/X` (this repo's own hooks; the move invalidates the old paths) |

**Not changed:** `templates/.claude/settings.json` — already references `scripts/<name>` paths, which are correct for adopted projects (relative to their own project root after `mb init` copies the scripts there).

---

## Success Criteria

1. `mb init` on a fresh project produces a `scripts/` directory with all 6 hook scripts
2. `mb doctor` Check #4 on a fresh project shows `[OK] Hook scripts present (...)`
3. `mb doctor` Check #4 on an old project missing hook scripts shows `[WARN] Hook script missing: X — run 'mb init'`
4. CI fails if a script is referenced in `templates/.claude/settings.json` but missing from `templates/scripts/`
5. This repo's own `mb doctor` shows `[OK]` after updating `.claude/settings.json` paths
