#!/bin/bash
#
# Auto-update last-reviewed frontmatter in memory-bank files after edits.
#
# Called by the PostToolUse hook after Write/Edit tool calls. Reads tool input
# JSON from stdin, checks if the edited file is inside memory-bank/, and updates
# the last-reviewed: frontmatter line with today's date. Silent on success.

set -e

# WHY: Reads from stdin because Claude Code PostToolUse hooks pass tool input as JSON.
# WHY plain `cat` (fd 0) and not `cat /dev/stdin`: when a native Windows process such as Claude
# Code launches Git Bash, fd 0 is a native pipe, and /dev/stdin -> /proc/self/fd/0 -> pipe:[0]
# cannot be reopened by path, so `cat /dev/stdin` failed (ENOENT) and the hook silently did
# nothing. Every other shell hook here already reads fd 0 directly.
INPUT=$(cat 2>/dev/null || true)
if [ -z "$INPUT" ]; then exit 0; fi

# WHY: Use python3 for JSON parsing — available on all supported platforms (Mac, Linux).
# Falls back to exit 0 if python3 is missing rather than blocking agent work.
# WHY tool_input.file_path, not file_path: the real payload nests everything under
# "tool_input" (e.g. {"tool_name":"Edit","tool_input":{"file_path":"..."}}), matching
# the same fix already applied in check-contract.ps1 (confirmed there via a live hook
# payload). This script had the same flat-read bug and, unlike
# check-contract.sh/dangerous-commands.sh, was never included in that fix -- FILE_PATH
# was always empty, so the script silently exited 0 on every call without ever
# updating last-reviewed.
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || true)

if [ -z "$FILE_PATH" ]; then exit 0; fi

# WHY: Normalize path separators before checking — may receive mixed slashes.
NORMALIZED=$(echo "$FILE_PATH" | tr '\\' '/')
if [[ "$NORMALIZED" != */memory-bank/* ]]; then exit 0; fi

# WHY use the normalized path from here on: perl -i places its temp file by splitting the path
# on '/', so a backslash-only Windows path puts the temp file in the cwd. Cygwin perl unlinks
# the original before renaming the temp over it, so when the cwd is on another drive the rename
# fails and the file is lost. One path also keeps the -f check, the grep and the edit on the same
# file. Trade-off: a POSIX filename containing a literal backslash is now skipped, not updated.
FILE_PATH="$NORMALIZED"

if [ ! -f "$FILE_PATH" ]; then exit 0; fi

# WHY: Only update if last-reviewed: already exists in frontmatter.
# Don't add frontmatter to files that don't have it — that's a human decision.
if ! grep -q 'last-reviewed:' "$FILE_PATH"; then exit 0; fi

TODAY=$(date +%Y-%m-%d)

# WHY: Use perl -i for cross-platform in-place sed (BSD sed and GNU sed have
# incompatible -i syntax; perl works identically on macOS and Linux).
perl -i -pe "s/^last-reviewed:.*\$/last-reviewed: $TODAY/" "$FILE_PATH" 2>/dev/null || true

exit 0
