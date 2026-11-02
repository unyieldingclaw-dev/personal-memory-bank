### Fixed

- **Force pushes, rm and command-running arguments in forms the BLOCK tier missed, in both
  shells.** These are ported from Side-Quest-Atlas's local fix and rewritten as POSIX ERE.
  - **What got through.** `git push origin main --force`, `git -C . push -f`,
    `git push origin +main`, `git push --mirror`, `rm -r -f x`, `rm x -rf`, `rm --rec --forc x`,
    `git -c alias.x='!cmd' x` and `awk 'BEGIN{system("cmd")}'` all ran with no verdict.
  - **Why it mattered.** The template's `Bash(git *)` allow rule, and `/code-review`'s
    `Bash(awk *)` grant, approve a command before Claude Code's auto-mode classifier sees it.
  - **The change.** Three structural rows join the literal ones, which stay. They match common
    spellings of rm with recursive and force flags, a force push, a `!` git alias, and awk
    `system()` / `getline`. `git stash push` is deliberately not matched. The matching is not
    exhaustive: a deliberately respelled command can get through.
  - **Adopter-visible:** the hook is `TEMPLATE_OWNED`, so `mb upgrade` delivers these rows to
    every project it upgrades. They are hard denies, with accepted false positives on text that
    names the flags (`git commit -m 'drop rm -r and -f'`) and on `awk ...; grep "system(" f`. On
    bash, `mb upgrade` does not refresh `standards/`, so copy `standards/SECURITY-GUARDRAILS.md` by
    hand to get the updated description.
  - **Not ported.** `find -exec` (Claude Code already gates find's actions), sed's `e` command (no
    shipped settings allow rule or command grant approves sed), and the network-fetch rows. For
    network fetching, a deny scoped to the read-only review agents is in the backlog instead.
  - **Examples, false positives and the by-design non-coverage** are in
    `standards/SECURITY-GUARDRAILS.md`, including that `rm -r` without `-f` runs unprompted in the
    Bash tool. The tested forms, blocked and not, are the fixture table in
    `tests/test-dangerous-commands.sh`; observed gaps are in
    `docs/backlog/shipped-allow-rules-skip-the-auto-mode-classifier.md`.
