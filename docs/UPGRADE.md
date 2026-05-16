# Upgrading an Existing Project

This guide covers updating a project that already uses Memory Bank when a new version of the standard is released.

The core rule: **your memory-bank/ files are yours — the upgrade never touches them.** Only the tooling and standards files change.

---

## When to Upgrade

Run `mb doctor` to see your current version. Compare it to the `VERSION` file in the memory-bank repo. If they differ, an upgrade is available.

You do not need to upgrade immediately. The system is designed so old projects continue working. Upgrade when you want new features (`mb audit`, `mb compact`, etc.) or when `mb doctor` reports issues.

---

## Upgrade Steps

### 1. Update the repo

```bash
cd /path/to/personal-memory-bank
git pull
```

### 2. Re-run the installer

```
install.bat          # Windows
./install.sh         # Mac/Linux
```

This updates the `mb` command globally. Your projects are not touched yet.

### 3. In your project, check what changed

```bash
mb validate          # is anything missing?
mb doctor            # any new health checks failing?
```

### 4. Selectively update project files

The upgrade does **not** auto-copy files into your project. You choose what to bring in.

**CLAUDE.md** — if the new version adds important rules, merge them manually:
```bash
diff CLAUDE.md /path/to/memory-bank/templates/CLAUDE.md
```
Copy the sections you want. Do not wholesale replace — you may have project-specific additions.

**memory-bank/ files** — these are your content, not ours. The upgrade never modifies them. The only change is the frontmatter schema (see below).

**.claude/settings.json** — if a new hook was added, copy it from `templates/.claude/settings.json`. Check the diff first.

**Cursor rules** — if `.cursor/rules/` files changed, you can re-run:
```bash
./scripts/init-memory-bank.sh --force   # Mac/Linux
.\scripts\init-memory-bank.ps1 -Force   # Windows
```
This overwrites cursor rules only. Memory-bank files and CLAUDE.md are skipped when they already exist with `-Force`.

### 5. Add frontmatter to existing memory-bank files (1.0.0+)

If your project predates v1.0.0, your memory-bank files lack frontmatter. Add it manually to the top of each file — copy the schema from `templates/memory-bank/` and fill in `last-reviewed` with today's date.

Then run `mb validate` to confirm frontmatter is recognized.

---

## What Never Changes During Upgrade

- `memory-bank/*.md` — your project content, always preserved
- `CLAUDE.md` — your project-specific AI instructions (upgrade only if you want new rules)
- `.claude/commands/*.md` — your slash commands (upgrade if you want new commands)
- Any hand-edited standards in `standards/` (if you've customized them)

---

## Rollback

If something breaks after upgrading:

1. The old `mb` binary is still in the repo's git history
2. `git checkout <old-commit> -- scripts/mb.ps1 scripts/mb.sh` restores the old scripts
3. Re-run `install.bat` or `install.sh` to re-register the old version

Your memory-bank files are never at risk — they're in your project's git history.

---

## Version History

See [CHANGELOG.md](../CHANGELOG.md) for what changed in each version.
