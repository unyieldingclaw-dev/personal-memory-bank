# PMB New-Project Launcher Design

**Date:** 2026-06-04
**Status:** Approved

## Problem

`mb init` requires the user to `cd` into the target project directory before running it. Users want to initialize PMB in a project without opening a terminal and navigating there first.

## Solution

A standalone double-clickable Windows launcher (`mb-new-project.bat`) that pops a native folder-picker dialog, then delegates to `mb init <path>`. To support this, both `mb.ps1` and `mb.sh` are extended to accept an optional path argument.

## Approach

**Option B** — standalone launcher + path arg added to `mb init`:
- The launcher stays thin (GUI pick → delegate)
- The `--path` / positional arg is genuinely useful from any terminal too
- No init logic is duplicated

## Files Changed

| File | Change |
|------|--------|
| `mb-new-project.bat` | New. Double-clickable GUI launcher |
| `scripts/mb.ps1` | `Invoke-Init`: use `$Arg` as target path if provided |
| `scripts/mb.sh` | `invoke_init`: use `$ARG` as target path if provided |
| Both scripts | Help text: updated `init` line to show `mb init [path]` |

## Usage

- **GUI:** Double-click `mb-new-project.bat` → folder picker → done
- **CLI:** `mb init "C:\path\to\project"` from any terminal
- **Unchanged:** `mb init` with no args still uses the current directory
