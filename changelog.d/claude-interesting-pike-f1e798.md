### Fixed

- The journal gate's block message always ends its suggested `note` commands with
  `--session <id>`, in both twins. **Why:** it added the flag only when the session id came from the
  hook payload, so inside Claude Code (id from `CLAUDE_CODE_SESSION_ID`) the command carried none,
  and pasted into the user's own terminal, which lacks that variable, it failed with "no session
  id". In a shell holding a different session's `CLAUDE_CODE_SESSION_ID` the pasted command is now
  refused instead of writing into that session. The journal stays inert until Plan C's
  `.pmb-features` flag PR. PR #57's "Block message" follow-up.
