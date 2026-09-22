---
status: open
created: 2026-09-22
last-reviewed: 2026-09-22
staleness-threshold: 90d
related_plan: null
---

# Sanitize file names printed by the pre-commit refusal

`.githooks/pre-commit` lists staged names with `git diff --cached --name-only -z`, which (deliberately) turns off git's C-quoting so non-ASCII names are matched correctly. The same raw names are printed in the refusal message, so a staged `memory-bank/` file whose name contains terminal escape sequences (ESC/OSC bytes are legal in Linux and macOS file names) is echoed unescaped and could hide or spoof the ERROR text in a terminal or CI log. The refusal itself always happens (`mb_refuse` exits 1), so this is display integrity, not a bypass. Raised by the 2026-09-21 `/code-review` security domain (Medium, INFERRED: not reproducible on the Windows review host, which remaps non-UTF-8 bytes in file names). Fix: keep matching on the raw list, and print a sanitized copy, e.g. `LC_ALL=C tr -d '\000-\010\013-\037\177'`; add a Linux-only test with an ESC in a staged name.
