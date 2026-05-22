# GitHub Presence Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix broken README content, surface missing CLI commands, add badges, and set the GitHub repo description and topics so the project is accurate and discoverable.

**Architecture:** Three independent changes — (1) surgical edits to README.md, (2) `gh` CLI calls to set repo metadata, (3) browser verification. All changes are in the main worktree at `C:\Users\Mizzo\Claude\Personal-Memory-Bank`.

**Tech Stack:** Markdown, GitHub CLI (`gh`), git

---

### Task 1: Fix README bugs

**Files:**
- Modify: `C:\Users\Mizzo\Claude\Personal-Memory-Bank\README.md` (lines 14, 38)

- [ ] **Step 1: Fix the clone URL placeholder**

In `README.md` line 14, replace:
```
git clone https://github.com/your-username/personal-memory-bank
```
with:
```
git clone https://github.com/UnyieldingClaw/personal-memory-bank
```

- [ ] **Step 2: Fix the Mac/Linux install script path**

In `README.md` line 38, replace:
```bash
chmod +x scripts/install.sh && ./scripts/install.sh
```
with:
```bash
chmod +x install.sh && ./install.sh
```

- [ ] **Step 3: Verify the install script exists at the correct path**

Run:
```powershell
Test-Path "C:\Users\Mizzo\Claude\Personal-Memory-Bank\install.sh"
```
Expected: `True`

- [ ] **Step 4: Commit**

```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add README.md
git commit -m "fix: correct clone URL and install script path in README"
```

---

### Task 2: Add badges to README

**Files:**
- Modify: `C:\Users\Mizzo\Claude\Personal-Memory-Bank\README.md` (after line 1)

- [ ] **Step 1: Add version and license badges after the h1**

In `README.md`, after `# Personal Memory Bank` (line 1), insert a blank line then the badges:
```markdown
# Personal Memory Bank

![Version](https://img.shields.io/badge/version-1.0.0-blue)  ![License](https://img.shields.io/badge/license-MIT-green)
```

- [ ] **Step 2: Verify badges render correctly in local markdown preview**

Open `README.md` in VS Code or any markdown previewer. Confirm both badges appear as inline images (blue "version 1.0.0" and green "MIT").

- [ ] **Step 3: Commit**

```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add README.md
git commit -m "docs: add version and license badges to README"
```

---

### Task 3: Surface missing CLI commands in Day-to-Day section

**Files:**
- Modify: `C:\Users\Mizzo\Claude\Personal-Memory-Bank\README.md` (Day-to-Day Commands section, currently ends at `mb help`)

- [ ] **Step 1: Add mb query, mb budget, mb doctor to the commands block**

Find the Day-to-Day Commands code block (currently ends with `mb help`). Replace the entire block with:
```
mb status     Check file sizes and health
mb validate   Verify required files and frontmatter are present
mb audit      See freshness — flag stale or overdue files
mb update     Get a prompt to update memory bank after a session
mb commit     Commit memory bank changes separately from feature code
mb query TAG  Find all memory tagged with TAG (e.g. mb query auth)
mb budget     Check token overhead of CLAUDE.md + memory-bank/
mb doctor     Full diagnostic (git, templates, hooks, file sizes)
mb help       Full command list
```

- [ ] **Step 2: Verify commands exist in the mb script**

Run:
```powershell
Select-String -Path "C:\Users\Mizzo\Claude\Personal-Memory-Bank\scripts\mb.ps1" -Pattern "^.*'query'|^.*'budget'|^.*'doctor'" | Select-Object -ExpandProperty Line
```
Expected: lines matching all three command handlers confirming they exist in the script.

- [ ] **Step 3: Commit**

```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add README.md
git commit -m "docs: surface mb query, budget, and doctor in day-to-day commands"
```

---

### Task 4: Set GitHub repo description

**Files:** none (GitHub metadata via `gh` CLI)

- [ ] **Step 1: Confirm gh is authenticated**

Run:
```powershell
gh auth status
```
Expected: output shows `Logged in to github.com as UnyieldingClaw`

- [ ] **Step 2: Set the repo description**

Run:
```powershell
gh repo edit UnyieldingClaw/personal-memory-bank --description "Everything your AI coding assistant needs between sessions: structured memory, CLI tooling, slash commands, hooks, and guardrails"
```
Expected: no error output

- [ ] **Step 3: Verify**

Run:
```powershell
gh repo view UnyieldingClaw/personal-memory-bank --json description -q .description
```
Expected:
```
Everything your AI coding assistant needs between sessions: structured memory, CLI tooling, slash commands, hooks, and guardrails
```

---

### Task 5: Set GitHub topics

**Files:** none (GitHub metadata via `gh` CLI)

- [ ] **Step 1: Add all 10 topics**

Run:
```powershell
gh repo edit UnyieldingClaw/personal-memory-bank --add-topic claude-code --add-topic cursor --add-topic ai-assistant --add-topic developer-tools --add-topic memory-bank --add-topic productivity --add-topic llm --add-topic context-management --add-topic automation --add-topic templates
```
Expected: no error output

- [ ] **Step 2: Verify topics were set**

Run:
```powershell
gh repo view UnyieldingClaw/personal-memory-bank --json repositoryTopics -q ".repositoryTopics[].name"
```
Expected: 10 lines listing each topic.

---

### Task 6: Browser verification

- [ ] **Step 1: Open the repo page**

Navigate to `https://github.com/UnyieldingClaw/personal-memory-bank` in a browser.

- [ ] **Step 2: Verify repo description**

Confirm the one-liner under the repo name reads:
> Everything your AI coding assistant needs between sessions: structured memory, CLI tooling, slash commands, hooks, and guardrails

- [ ] **Step 3: Verify topics**

Confirm the 10 topic chips appear below the description: `claude-code`, `cursor`, `ai-assistant`, `developer-tools`, `memory-bank`, `productivity`, `llm`, `context-management`, `automation`, `templates`

- [ ] **Step 4: Verify README badges**

Confirm the blue "version 1.0.0" and green "MIT" badges render under the heading.

- [ ] **Step 5: Verify README install commands**

Confirm the Windows clone URL shows `UnyieldingClaw/personal-memory-bank` (not `your-username`).
Confirm the Mac/Linux block shows `chmod +x install.sh && ./install.sh` (not `scripts/install.sh`).

- [ ] **Step 6: Verify Day-to-Day Commands table**

Confirm `mb query`, `mb budget`, and `mb doctor` appear in the commands block.
