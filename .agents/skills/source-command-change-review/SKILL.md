---
name: source-command-change-review
description: Review a branch, pull request, or diff with PMB's change-review procedure. On native Windows Codex, use scoped escalation to reach a normal-user ACR installation when the sandbox cannot see its npm shim.
---

# Change review in Codex

Read the tracked `.claude/commands/change-review.md` in this repository and follow its review jobs, finding schema, exit-code table, opposition step, and reporting rules. This adapter changes only ACR discovery and invocation on native Windows Codex. It does not authorize a merge, a push, or a standing sandbox exception.

## Select and bind the input

Use the source command's Step 1 to select the exact review diff. Record its source, base and head commit IDs when applicable, changed paths, byte count, and SHA-256. Materialize it in a unique temporary file outside the repository; never use ACR's default staged diff. For a local Git diff, prefer `git diff --binary --output=<absolute-temp-path> <base>...<head>` so Git writes the bytes. For an existing diff file, copy it and compare hashes. For a PR, capture `gh pr diff <number>` and record `baseRefOid` and `headRefOid` from `gh pr view` before review. Check that the file is readable by the process that will run ACR. Keep the temporary file until the review finishes, then remove it in a `finally` path.

On Windows, verify the temporary file's bytes before use: compare its SHA-256 to a second capture of the same selected diff. Do not claim this check passes merely because the file exists. The observed PowerShell 7.6.6 redirection match on one PR diff is evidence for that case, not a guarantee for every shell or diff.

## Discover ACR

Try `Get-Command ai-review-agent -ErrorAction SilentlyContinue` inside the sandbox. If found, run the source command's version preflight. If absent but a normal-user installation is expected, request a separate escalated execution of `ai-review-agent --version`. When the tool supports `sandbox_permissions: require_escalated`, use that per call; do not create a broad reusable approval prefix. Escalation may be auto-reviewed, so do not describe it as a guaranteed human prompt. Before running this mutable npm-linked executable outside the sandbox, confirm that the user has authorized that ACR invocation for the current task; if not, ask specifically. Tool escalation approval alone is not user consent. If user consent or escalation is denied, the command fails, the version is unreadable, or the parsed version is below 1.10.0, record ACR unavailable and use the PMB-native security review. Do not switch Windows to `unelevated` or assume `/sandbox-add-read-dir` works without an actual successful invocation.

The version is a capability check, not an identity pin: this machine's shim is an `npm link` into a mutable checkout. Record the resolved command path and reported version, but do not claim a reproducible ACR build from those facts. Run the version check immediately before the review.

## Run and assess ACR

For a qualifying version, request a separate escalated execution of the exact source-command invocation, using the absolute temporary diff path:

`ai-review-agent --profile security --chunk --format json --diff <absolute-temp-path>`

Do not pass `--allow-truncation`, `--write-tests`, or a broad approval prefix. Confirm the process exit code and parse the JSON. Apply Job 7's full exit-code table. In particular, exit 0 alone is never a clean-coverage claim, and exit 1 requires an actual findings object before it is treated as a review result. Check `agentStatus`, `policy.agentsSkipped`, `filteredFiles`, truncation and early-exit signals, plus the intended changed-path list. An `ok` status for every agent does not establish that every file was reviewed. Inspect intentional exclusions in `ai-review.config.json`; cover excluded or uncertain paths with PMB-native security review and say which paths ACR did not cover. If completion or coverage cannot be established, use PMB-native review as the actual security coverage and report the ACR limitation. Verify consequential ACR findings against the cited code before treating them as supported findings.

Before any opposition marker write and again before reporting, recheck the source diff and compare its SHA-256 with the reviewed temporary file. For a PR, recheck both base and head OIDs. The source command's marker hashes a local `origin/main...HEAD` diff: for a PR or supplied diff, do not write that marker unless its exact local diff bytes equal the reviewed bytes and the PR identities are still current. If identity or bytes change, do not reuse the result or write a marker; remove only a marker created by this review if a later recheck finds it stale, then restart review on the new diff. Do not overwrite a marker that predated this review or appeared while it ran; coordinate with its owner instead. Never remove a pre-existing peer marker. Report the reviewed IDs, diff hash, ACR version/path, exit code, and coverage caveats. Follow the source command's remaining jobs and marker rules where they apply to the reviewed diff.
