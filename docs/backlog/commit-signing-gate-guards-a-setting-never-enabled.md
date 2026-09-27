---
status: open
created: 2026-09-25
last-reviewed: 2026-09-25
staleness-threshold: 90d
related_plan: null
---

# Commit-signing gate guards a setting never enabled here

**The CONFIRM-tier gate against skipping commit signing has nothing to protect in this repo,
because signing has never been turned on.** Found 2026-09-25 when `a171ae5` came out unsigned
(`git log -1 --format=%G? a171ae5` → `N`). Nothing was bypassed; there was no signing to bypass.

## What was measured (2026-09-25, git 2.55.0.windows.3, one machine)

- **No signing configuration at any level.** `git config --show-origin --get-all commit.gpgsign`,
  `--get gpg.format` and `--get user.signingkey` each exit 1 with no output.
- **No SSH key material.** `ls ~/.ssh/` → `No such file or directory`.
- **GitHub does not require signatures.** `gh api repos/{owner}/{repo}/branches/main/protection/required_signatures --jq .enabled`
  → `false`.
- **What reaches `main` is already signed, by GitHub.** `git log -1 --format='%h committer=%cn sig=%G?' 739f0eb`
  → `committer=GitHub sig=E`. `E` means this machine cannot check the signature (it lacks
  GitHub's key), not that the signature is bad. Branch commits are squashed away on merge.

## Why it matters

- **The gate has nothing to protect here.** PR #21 (`030662c`) made `--no-gpg-sign` and a falsey
  `commit.gpgsign` CONFIRM-tier (`standards/SECURITY-GUARDRAILS.md`, "Skip commit signing" row;
  matchers in `scripts/dangerous-commands.{sh,ps1}`). Those patterns only matter when signing is
  on. With it off they guard nothing, and nothing in the repo says so. This is the shape
  `standards/CODE-REVIEW.md` "A check that cannot fail does not count as a check" describes.
- **`[NS-35]` decision (4), "Land commit-signing first — DONE, `030662c`", means this gate landed,
  not that signing was switched on.** Read in isolation it suggests signing is active here; it is not.
- **The gate still has value for adopters who do sign**, so it should not simply be removed.
- **Not established:** whether any adopter repo has signing enabled. Not checked.

## Why enabling signing here buys little

- It does not change what lands on `main`: squash merges are GitHub-signed either way.
- It does not distinguish human from agent commits: an agent in this session commits under the
  user's identity, so it would sign with the same key. The review gate and the rule that only the
  user merges are what separate the two.
- It risks stalling every agent commit: GPG on Windows can raise a pinentry prompt an agent
  cannot answer. SSH signing avoids that only with a passphrase-less key or a loaded
  `ssh-agent`, and a passphrase-less key weakens what the signature attests.

## Options — a user decision, not made here

1. **Enforce signing deliberately.** Turn on `required_signatures` for `main` (and decide whether
   adopters should), then configure SSH signing (`gpg.format ssh`, `user.signingkey`,
   `commit.gpgsign true`, and `gpg.ssh.allowedSignersFile` — without it `%G?` cannot report `G`)
   with the key held by `ssh-agent`, and confirm an agent-run commit completes without a prompt
   before relying on it. Changing git config or branch protection is
   the user's to do; this item does not authorize it.
2. **Leave signing off and make the docs true.** Reword the "Skip commit signing" row in
   `standards/SECURITY-GUARDRAILS.md` and its `templates/` twin to say the gate protects repos that
   sign, and is inactive where `commit.gpgsign` is unset. Optionally have `mb doctor` report
   "commit signing: not configured" as INFO, so the state is visible rather than inferred.

## Done when

- One option is chosen and recorded, and
- under option 1, `git log -1 --format=%G?` on a fresh agent-made commit returns `G`; under
  option 2, the guardrail row (both copies) states that the gate is inactive without signing.
