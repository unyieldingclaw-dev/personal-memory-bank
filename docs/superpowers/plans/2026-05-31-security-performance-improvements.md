# Security & Performance Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add structured security findings (Rule ID + Evidence + Confidence), a trust classification standard, security regression fixtures, and a performance budget standard to PMB.

**Architecture:** Four new/updated artifacts: (1) `standards/SECURITY-RULES.md` rule registry + updated output format in both security command/agent; (2) `standards/TRUST-CLASSIFICATION.md` reference doc; (3) `fixtures/security/` with 9 known-bad code samples + `mb doctor` structural check; (4) `standards/PERFORMANCE-BUDGET.md` + `mb doctor` standards-count check. All three new standards distributed via `mb init`/`mb upgrade` through `templates/standards/`.

**Tech Stack:** PowerShell (mb.ps1), Bash (mb.sh), Markdown

---

## File Map

| File | Operation |
|------|-----------|
| `standards/SECURITY-RULES.md` | Create |
| `standards/TRUST-CLASSIFICATION.md` | Create |
| `standards/PERFORMANCE-BUDGET.md` | Create |
| `.claude/commands/security-review.md` | Update output format |
| `.claude/agents/security-reviewer.md` | Update output format + trust prompt addition |
| `standards/AGENTIC-SAFETY.md` | Add one-line pointer |
| `standards/SECURITY-GUARDRAILS.md` | Add one-line pointer |
| `CLAUDE.md` | Add one-line pointer in Token Budget section |
| `fixtures/security/` (10 files) | Create |
| `scripts/mb.ps1` | Add doctor checks 13 + 14 before Startup Context section (line ~885) |
| `scripts/mb.sh` | Add doctor checks 13 + 14 before Startup Context section (line ~692) |
| `scripts/mb.ps1` | Add 3 entries to `$advisoryCreate` (line ~1244) |
| `scripts/mb.sh` | Add 3 entries to `ADVISORY_CREATE` (line ~1064) |
| `templates/standards/SECURITY-RULES.md` | Create |
| `templates/standards/TRUST-CLASSIFICATION.md` | Create |
| `templates/standards/PERFORMANCE-BUDGET.md` | Create |
| `.claude/commands/health-check.md` | Add security fixture test step |
| `docs/COMMANDS-REFERENCE.md` | Add checks 13 + 14 to doctor table; update count 12→14 |
| `VERSION` | Bump to 1.0.4 |
| `CHANGELOG.md` | Add v1.0.4 entry |
| `docs/superpowers/specs/2026-05-31-security-performance-improvements-design.md` | Create |

---

## Task 1: Create Rule Registry

**Files:**
- Create: `standards/SECURITY-RULES.md`

- [ ] **Step 1: Create the file**

```markdown
---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - security/rules
  - security/registry
last-reviewed: 2026-05-31
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Security Rules Registry

Rule IDs used by `/security-review` and the security-reviewer agent.
Reference this file when interpreting findings or extending coverage.

| ID | Severity | Pattern | Description |
|----|----------|---------|-------------|
| SEC-001 | CRITICAL | Hardcoded secrets | API keys, passwords, tokens, or credentials in source code |
| SEC-002 | CRITICAL | Command injection | Unsanitized user input passed to shell commands |
| SEC-003 | CRITICAL | SQL injection | User input concatenated directly into SQL strings |
| SEC-004 | HIGH | Unvalidated external input | Data from HTTP requests, files, or env vars used without validation |
| SEC-005 | HIGH | Missing auth checks | Endpoints or operations lacking required authentication |
| SEC-006 | HIGH | Insecure deserialization | pickle.loads(), yaml.load() without Loader=, eval() on untrusted data |
| SEC-007 | MEDIUM | XSS | Unescaped user input rendered into HTML output |
| SEC-008 | MEDIUM | Exposed error details | Stack traces, internal paths, or system info returned to users |
| SEC-009 | MEDIUM | Unsafe dynamic execution | eval(), exec(), or os.system() with any variable input |

## Adding Project-Specific Rules

Projects may extend this registry by appending rules starting at SEC-101.
Do not modify SEC-001 through SEC-099 — those are PMB-managed.

Example:

| SEC-101 | HIGH | Internal API direct call | Never call internal-api.example.com directly from client code |
```

- [ ] **Step 2: Commit**

```bash
git add standards/SECURITY-RULES.md
git commit -m "feat: add SECURITY-RULES.md rule registry (SEC-001–009)"
```

---

## Task 2: Update Security Review Command

**Files:**
- Modify: `.claude/commands/security-review.md`

- [ ] **Step 1: Read the current file**

Read `.claude/commands/security-review.md` to confirm current content before editing.

- [ ] **Step 2: Replace the output format section**

The current file ends with:

```
For each finding report:
- Severity: [CRITICAL] / [HIGH] / [MEDIUM] / [LOW]
- File path and line number
- What the issue is
- Recommended fix (specific, not generic)

If no issues found: "No security issues found in current diff."
```

Replace with:

```
Rules are defined in `standards/SECURITY-RULES.md`.

For each finding, use this format:

**[SEVERITY]** Rule: SEC-00X
Evidence: `<exact code snippet triggering the issue>`
Confidence: High | Medium | Low
File: `path/to/file.ext:line`
Issue: <what the problem is>
Fix: <specific recommended fix, not generic>

If no issues found: "No security issues found in current diff."
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/security-review.md
git commit -m "feat: structured findings format in security-review command"
```

---

## Task 3: Update Security Reviewer Agent

**Files:**
- Modify: `.claude/agents/security-reviewer.md`

- [ ] **Step 1: Read the current file**

Read `.claude/agents/security-reviewer.md` to confirm current content.

- [ ] **Step 2: Replace the "Return a structured list" section**

The current file ends with:

```
Return a structured list:
**[SEVERITY]** Description — `file:line`

Severity levels: CRITICAL · HIGH · MEDIUM · LOW

Only report real findings. If you find nothing, say "No security issues found."
```

Replace with:

```
Rules are defined in `standards/SECURITY-RULES.md`.

Return findings using this format:

**[SEVERITY]** Rule: SEC-00X
Evidence: `<exact code snippet triggering the issue>`
Confidence: High | Medium | Low
File: `path/to/file.ext:line`
Issue: <what the problem is>
Fix: <specific recommended fix, not generic>

When reporting prompt-injection or rules-file-integrity findings, note the trust level of
the content source (TRUSTED / SEMI_TRUSTED / UNTRUSTED) as defined in
`standards/TRUST-CLASSIFICATION.md`. Trust level is informational — it does not change
severity automatically.

Severity levels: CRITICAL · HIGH · MEDIUM · LOW

Only report real findings. If you find nothing, say "No security issues found."
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/security-reviewer.md
git commit -m "feat: structured findings + trust level note in security-reviewer agent"
```

---

## Task 4: Create Trust Classification Standard + Wire Pointers

**Files:**
- Create: `standards/TRUST-CLASSIFICATION.md`
- Modify: `standards/AGENTIC-SAFETY.md`
- Modify: `standards/SECURITY-GUARDRAILS.md`

- [ ] **Step 1: Create TRUST-CLASSIFICATION.md**

```markdown
---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - security/trust
  - security/classification
last-reviewed: 2026-05-31
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Trust Classification

Defines trust levels for content sources in agentic workflows.
Referenced by the security-reviewer agent and `AGENTIC-SAFETY.md`.

No runtime enforcement. Trust level is informational context for security findings.

## Trust Levels

| Level | Definition |
|-------|-----------|
| TRUSTED | Content the operator explicitly controls and reviewed |
| SEMI_TRUSTED | Content in the repository but potentially modified by contributors |
| UNTRUSTED | External content not reviewed by the operator |

## Source Classification

| Source | Trust Level | Rationale |
|--------|-------------|-----------|
| Standards files (`standards/`) | TRUSTED | Operator-controlled, version-controlled |
| Commands (`.claude/commands/`) | TRUSTED | Operator-controlled, version-controlled |
| Agents (`.claude/agents/`) | TRUSTED | Operator-controlled, version-controlled |
| CLAUDE.md | TRUSTED | Operator-controlled, version-controlled |
| Memory bank files | SEMI_TRUSTED | Operator-controlled but partially AI-generated |
| Project source code | SEMI_TRUSTED | In-repo but may include external contributions |
| Config files | SEMI_TRUSTED | In-repo, usually operator-controlled |
| PR descriptions | UNTRUSTED | User-supplied, not reviewed before processing |
| Issue comments | UNTRUSTED | User-supplied, not reviewed before processing |
| User prompts (runtime) | UNTRUSTED | Direct user input during session |
| Fetched web content | UNTRUSTED | External, not operator-controlled |
| MCP tool results | UNTRUSTED | External service responses |

## Application in Security Findings

Include trust level when reporting prompt-injection or rules-file-integrity findings:

```
[HIGH] Rule: SEC-003
Evidence: `query = "SELECT * FROM users WHERE id = " + user_id`
Confidence: High
File: api.py:42
Issue: SQL injection via UNTRUSTED user input concatenated into query string
Fix: Use parameterized queries: cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

Runtime enforcement belongs in the hook/CI layer. This standard is advisory.

## Relationship to Other Standards

- `AGENTIC-SAFETY.md` — indirect prompt injection defense during live tasks
- `SECURITY-GUARDRAILS.md` — BLOCK/CONFIRM/WARN tiers for dangerous operations
- `RULES-FILE-INTEGRITY.md` — injection via rules files specifically
```

- [ ] **Step 2: Add pointer to AGENTIC-SAFETY.md**

Read `standards/AGENTIC-SAFETY.md`. Append the following line to the "Relationship to Other Standards" section (which currently ends with `- This standard — external content during live agentic tasks`):

```
- `TRUST-CLASSIFICATION.md` — formal trust level definitions for content sources
```

- [ ] **Step 3: Add pointer to SECURITY-GUARDRAILS.md**

Read `standards/SECURITY-GUARDRAILS.md`. Find the section header for the BLOCK tier rules or the introductory table. Add this line to whatever "Related Standards" or "See Also" section exists at the top or bottom. If no such section exists, append to the end of the file:

```
## Related Standards

- `TRUST-CLASSIFICATION.md` — trust levels for content sources (TRUSTED / SEMI_TRUSTED / UNTRUSTED)
- `SECURITY-RULES.md` — rule registry for `/security-review` findings (SEC-001–009)
```

- [ ] **Step 4: Commit**

```bash
git add standards/TRUST-CLASSIFICATION.md standards/AGENTIC-SAFETY.md standards/SECURITY-GUARDRAILS.md
git commit -m "feat: add TRUST-CLASSIFICATION.md + wire pointers in AGENTIC-SAFETY and SECURITY-GUARDRAILS"
```

---

## Task 5: Create Security Regression Fixtures

**Files:**
- Create: `fixtures/security/SEC-001-hardcoded-secret/bad.py`
- Create: `fixtures/security/SEC-002-command-injection/bad.py`
- Create: `fixtures/security/SEC-003-sql-injection/bad.py`
- Create: `fixtures/security/SEC-004-unvalidated-input/bad.py`
- Create: `fixtures/security/SEC-005-missing-auth/bad.py`
- Create: `fixtures/security/SEC-006-insecure-deserialization/bad.py`
- Create: `fixtures/security/SEC-007-xss/bad.html`
- Create: `fixtures/security/SEC-008-exposed-errors/bad.py`
- Create: `fixtures/security/SEC-009-unsafe-eval/bad.py`
- Create: `fixtures/security/README.md`

- [ ] **Step 1: Create SEC-001 fixture**

`fixtures/security/SEC-001-hardcoded-secret/bad.py`:
```python
# Bad: hardcoded credentials in source code (SEC-001)
API_KEY = "sk-proj-abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
DATABASE_PASSWORD = "super_secret_password_123"
GITHUB_TOKEN = "ghp_abc123def456ghi789jkl012mno345pqr678"

def get_data():
    headers = {"Authorization": f"Bearer {API_KEY}"}
    # fetch data with hardcoded key
```

- [ ] **Step 2: Create SEC-002 fixture**

`fixtures/security/SEC-002-command-injection/bad.py`:
```python
import subprocess

# Bad: user input passed directly to shell (SEC-002)
def run_command(user_input):
    result = subprocess.run(user_input, shell=True, capture_output=True)
    return result.stdout

def ping_host(hostname):
    output = subprocess.check_output("ping -c 1 " + hostname, shell=True)
    return output
```

- [ ] **Step 3: Create SEC-003 fixture**

`fixtures/security/SEC-003-sql-injection/bad.py`:
```python
import sqlite3

# Bad: user input concatenated into SQL string (SEC-003)
def get_user(user_id):
    conn = sqlite3.connect("app.db")
    cursor = conn.cursor()
    query = "SELECT * FROM users WHERE id = " + user_id
    cursor.execute(query)
    return cursor.fetchone()

def search_users(name):
    conn = sqlite3.connect("app.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE name = '" + name + "'")
    return cursor.fetchall()
```

- [ ] **Step 4: Create SEC-004 fixture**

`fixtures/security/SEC-004-unvalidated-input/bad.py`:
```python
import os
from flask import request, send_file

# Bad: user-controlled path with no validation (SEC-004)
def read_file():
    filename = request.args.get("file")
    path = os.path.join("/var/app/data", filename)
    with open(path) as f:
        return f.read()

def download():
    user_file = request.form.get("filename")
    return send_file(user_file)
```

- [ ] **Step 5: Create SEC-005 fixture**

`fixtures/security/SEC-005-missing-auth/bad.py`:
```python
from flask import Flask, jsonify
import database

app = Flask(__name__)

# Bad: admin endpoint with no authentication check (SEC-005)
@app.route("/admin/users")
def list_all_users():
    users = database.get_all_users()
    return jsonify(users)

@app.route("/admin/delete/<user_id>", methods=["DELETE"])
def delete_user(user_id):
    database.delete_user(user_id)
    return jsonify({"deleted": user_id})
```

- [ ] **Step 6: Create SEC-006 fixture**

`fixtures/security/SEC-006-insecure-deserialization/bad.py`:
```python
import pickle
import yaml

# Bad: deserializing untrusted data (SEC-006)
def load_user_session(cookie_data):
    return pickle.loads(cookie_data)

def load_config(config_string):
    # Missing Loader= argument
    return yaml.load(config_string)

def restore_object(serialized):
    return pickle.loads(serialized)
```

- [ ] **Step 7: Create SEC-007 fixture**

`fixtures/security/SEC-007-xss/bad.html`:
```html
<!DOCTYPE html>
<html>
<body>
  <!-- Bad: user input injected into HTML without escaping (SEC-007) -->
  <script>
    var username = "<?= $_GET['name'] ?>";
    document.write("Hello, " + username);
  </script>

  <div id="content"></div>
  <script>
    // Bad: hash fragment written directly to DOM
    document.getElementById("content").innerHTML = location.hash.substring(1);
  </script>

  <!-- Bad: search term reflected without encoding -->
  <p>Results for: <?= $_GET['q'] ?></p>
</body>
</html>
```

- [ ] **Step 8: Create SEC-008 fixture**

`fixtures/security/SEC-008-exposed-errors/bad.py`:
```python
import traceback
from flask import Flask, jsonify

app = Flask(__name__)

# Bad: full stack trace and internal path returned to user (SEC-008)
@app.route("/process")
def process():
    try:
        result = do_something()
        return jsonify(result)
    except Exception as e:
        return jsonify({
            "error": str(e),
            "traceback": traceback.format_exc(),
            "file": __file__,
            "python_path": __import__("sys").path
        }), 500
```

- [ ] **Step 9: Create SEC-009 fixture**

`fixtures/security/SEC-009-unsafe-eval/bad.py`:
```python
# Bad: eval/exec with user-controlled input (SEC-009)
def calculate(expression):
    result = eval(expression)
    return result

def run_script(code):
    exec(code)

def dynamic_call(func_name, args):
    import os
    os.system(func_name + " " + args)
```

- [ ] **Step 10: Create README**

`fixtures/security/README.md`:
```markdown
# Security Regression Fixtures

Known-bad code samples used to verify `/security-review` catches each rule.
One subdirectory per rule ID from `standards/SECURITY-RULES.md`.

## Structure

| Directory | Rule | Pattern |
|-----------|------|---------|
| `SEC-001-hardcoded-secret/bad.py` | SEC-001 | Hardcoded secrets |
| `SEC-002-command-injection/bad.py` | SEC-002 | Command injection |
| `SEC-003-sql-injection/bad.py` | SEC-003 | SQL injection |
| `SEC-004-unvalidated-input/bad.py` | SEC-004 | Unvalidated external input |
| `SEC-005-missing-auth/bad.py` | SEC-005 | Missing auth checks |
| `SEC-006-insecure-deserialization/bad.py` | SEC-006 | Insecure deserialization |
| `SEC-007-xss/bad.html` | SEC-007 | XSS |
| `SEC-008-exposed-errors/bad.py` | SEC-008 | Exposed error details |
| `SEC-009-unsafe-eval/bad.py` | SEC-009 | Unsafe dynamic execution |

## Running Fixture Tests

Via `mb health-check` (PMB repo only):

```bash
mb health-check
```

The health-check command includes a security fixture step that runs `/security-review`
against this directory and reports which rule IDs were caught vs missed.

## mb doctor Check 13

`mb doctor` Check 13 verifies this directory and all 9 subdirectories exist.
It does NOT invoke the LLM — structural presence only. Fast.
```

- [ ] **Step 11: Commit**

```bash
git add fixtures/
git commit -m "feat: add security regression fixtures (SEC-001–009)"
```

---

## Task 6: Create Performance Budget Standard + Wire Pointer

**Files:**
- Create: `standards/PERFORMANCE-BUDGET.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Create PERFORMANCE-BUDGET.md**

```markdown
---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - performance/budget
  - performance/context
last-reviewed: 2026-05-31
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Performance Budget

PMB's primary performance cost is LLM context consumption, not compute.
This document defines explicit limits to prevent gradual context bloat.

## Limits

| Dimension | Limit | Action if Exceeded |
|-----------|-------|-------------------|
| Standards files (`standards/`) | ≤ 20 | Archive or merge redundant standards |
| Memory bank entries (lines in `progress.md`) | ≤ 50 | Run `mb archive` |
| Agent delegations per command | ≤ 1 | Refactor to inline or batch |
| Default scan scope | Changed files first | Full-repo is explicit opt-in only |
| Full-repo scan | Explicit request only | Never triggered automatically |
| Fixture files per security rule | 1 | Keep fixtures minimal |

## Why These Limits

**Standards proliferation** grows context linearly. Every standard added increases tokens
loaded, retrieval work, and reasoning time on every session.

**Duplicate context** is the second risk. Multiple copies of the same content (`.claude/`,
`.cursor/`, generated artifacts) each cost tokens if loaded. Maintain a single source of
truth; generate copies, do not duplicate them independently.

**Agent chains** that call other agents recursively are the primary path to O(n²) complexity.
Keep delegation depth to 1.

## mb doctor Integration

`mb doctor` Check 14 counts `.md` files in `standards/` and warns if > 20.
Current count after v1.0.4: 14 (well within budget).

## What to Do When Limits Are Reached

- **Standards > 20:** Review for overlap. Can two standards merge? Is one superseded?
- **Memory entries > 50:** Run `mb archive` on `progress.md` to move completed items.
- **Agent chain > 1:** Inline the sub-task or make it a separate user-invoked command.
```

- [ ] **Step 2: Add pointer to CLAUDE.md Token Budget section**

Read `CLAUDE.md`. Find the Token Budget section. After the `CLAUDE_CODE_EFFORT_LEVEL` line (last bullet in the "Session commands" list), add:

```
See `standards/PERFORMANCE-BUDGET.md` for explicit limits on standards count, memory entries, and agent delegation depth.
```

- [ ] **Step 3: Commit**

```bash
git add standards/PERFORMANCE-BUDGET.md CLAUDE.md
git commit -m "feat: add PERFORMANCE-BUDGET.md + pointer in CLAUDE.md Token Budget section"
```

---

## Task 7: Add mb doctor Checks 13 and 14

**Files:**
- Modify: `scripts/mb.ps1` (insert before line ~885, after check 12 ends)
- Modify: `scripts/mb.sh` (insert before line ~692, after check 12 ends)

- [ ] **Step 1: Add checks to mb.ps1**

Read `scripts/mb.ps1`. Find the section after check 12 that begins:

```powershell
    # Startup context — observability section (not a numbered health check)
```

Insert the following block immediately before that line:

```powershell
    # 13. Security regression fixtures
    $fixturesDir = Join-Path $RepoRoot "fixtures\security"
    $expectedFixtures = @(
        "SEC-001-hardcoded-secret","SEC-002-command-injection","SEC-003-sql-injection",
        "SEC-004-unvalidated-input","SEC-005-missing-auth","SEC-006-insecure-deserialization",
        "SEC-007-xss","SEC-008-exposed-errors","SEC-009-unsafe-eval"
    )
    if (-not (Test-Path $fixturesDir)) {
        Write-Host "[WARN] fixtures/security/ not found — security regression fixtures missing" -ForegroundColor Yellow
    } else {
        $missingFixtures = $expectedFixtures | Where-Object { -not (Test-Path (Join-Path $fixturesDir $_)) }
        if ($missingFixtures.Count -gt 0) {
            Write-Host "[WARN] fixtures/security/ missing: $($missingFixtures -join ', ')" -ForegroundColor Yellow
        } else {
            Write-Host "[OK]   Security regression fixtures present (9/9)" -ForegroundColor Green
        }
    }

    # 14. Standards count (performance budget)
    $standardsDir = Join-Path $RepoRoot "standards"
    if (Test-Path $standardsDir) {
        $stdCount = (Get-ChildItem -Path $standardsDir -Filter "*.md" -File |
            Where-Object { $_.Name -notlike "_*" }).Count
        if ($stdCount -gt 20) {
            Write-Host "[WARN] $stdCount standards files — budget is <= 20 (see standards/PERFORMANCE-BUDGET.md)" -ForegroundColor Yellow
        } else {
            Write-Host "[OK]   Standards count: $stdCount (budget: <= 20)" -ForegroundColor Green
        }
    }

```

- [ ] **Step 2: Add checks to mb.sh**

Read `scripts/mb.sh`. Find the section after check 12 that begins:

```bash
    # Startup context — observability section (not a numbered health check)
```

Insert the following block immediately before that line:

```bash
    # 13. Security regression fixtures
    FIXTURES_DIR="$REPO_ROOT/fixtures/security"
    EXPECTED_FIXTURES=(
        "SEC-001-hardcoded-secret" "SEC-002-command-injection" "SEC-003-sql-injection"
        "SEC-004-unvalidated-input" "SEC-005-missing-auth" "SEC-006-insecure-deserialization"
        "SEC-007-xss" "SEC-008-exposed-errors" "SEC-009-unsafe-eval"
    )
    if [ ! -d "$FIXTURES_DIR" ]; then
        echo -e "${YELLOW}[WARN] fixtures/security/ not found — security regression fixtures missing${NC}"
    else
        MISSING_FIXTURES=()
        for fx in "${EXPECTED_FIXTURES[@]}"; do
            [ ! -d "$FIXTURES_DIR/$fx" ] && MISSING_FIXTURES+=("$fx")
        done
        if [ ${#MISSING_FIXTURES[@]} -gt 0 ]; then
            echo -e "${YELLOW}[WARN] fixtures/security/ missing: ${MISSING_FIXTURES[*]}${NC}"
        else
            echo -e "${GREEN}[OK]   Security regression fixtures present (9/9)${NC}"
        fi
    fi

    # 14. Standards count (performance budget)
    STANDARDS_DIR="$REPO_ROOT/standards"
    if [ -d "$STANDARDS_DIR" ]; then
        STD_COUNT=$(find "$STANDARDS_DIR" -maxdepth 1 -name "*.md" ! -name "_*" -type f | wc -l | tr -d ' ')
        if [ "$STD_COUNT" -gt 20 ]; then
            echo -e "${YELLOW}[WARN] $STD_COUNT standards files — budget is <= 20 (see standards/PERFORMANCE-BUDGET.md)${NC}"
        else
            echo -e "${GREEN}[OK]   Standards count: $STD_COUNT (budget: <= 20)${NC}"
        fi
    fi

```

- [ ] **Step 3: Verify mb doctor runs without error**

```bash
pwsh scripts/mb.ps1 doctor
```

Expected: checks 13 and 14 appear as `[OK]` lines. No syntax errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1 scripts/mb.sh
git commit -m "feat: mb doctor checks 13 (fixtures) and 14 (standards count)"
```

---

## Task 8: Wire New Standards into mb upgrade

**Files:**
- Modify: `scripts/mb.ps1` (add 3 entries to `$advisoryCreate`, line ~1231)
- Modify: `scripts/mb.sh` (add 3 entries to `ADVISORY_CREATE`, line ~1052)

- [ ] **Step 1: Update mb.ps1 $advisoryCreate**

Find the `$advisoryCreate` array in `scripts/mb.ps1`. It currently ends with:

```powershell
        "standards/SUPPLY-CHAIN.md"
    )
```

Replace that closing line with:

```powershell
        "standards/SUPPLY-CHAIN.md"
        "standards/SECURITY-RULES.md"
        "standards/TRUST-CLASSIFICATION.md"
        "standards/PERFORMANCE-BUDGET.md"
    )
```

- [ ] **Step 2: Update mb.sh ADVISORY_CREATE**

Find the `ADVISORY_CREATE` array in `scripts/mb.sh`. It currently ends with:

```bash
        "standards/SUPPLY-CHAIN.md"
    )
```

Replace that closing line with:

```bash
        "standards/SUPPLY-CHAIN.md"
        "standards/SECURITY-RULES.md"
        "standards/TRUST-CLASSIFICATION.md"
        "standards/PERFORMANCE-BUDGET.md"
    )
```

- [ ] **Step 3: Commit**

```bash
git add scripts/mb.ps1 scripts/mb.sh
git commit -m "feat: add 3 new standards to mb upgrade ADVISORY_CREATE"
```

---

## Task 9: Create Template Copies

**Files:**
- Create: `templates/standards/SECURITY-RULES.md`
- Create: `templates/standards/TRUST-CLASSIFICATION.md`
- Create: `templates/standards/PERFORMANCE-BUDGET.md`

- [ ] **Step 1: Copy the three standards files to templates**

```bash
cp standards/SECURITY-RULES.md templates/standards/SECURITY-RULES.md
cp standards/TRUST-CLASSIFICATION.md templates/standards/TRUST-CLASSIFICATION.md
cp standards/PERFORMANCE-BUDGET.md templates/standards/PERFORMANCE-BUDGET.md
```

These are identical copies. `mb init` uses a glob loop over `templates/standards/` so no script changes are needed.

- [ ] **Step 2: Verify mb init would pick them up**

```bash
grep -n "standardsTemplate" scripts/mb.ps1 | head -5
```

Expected output contains the glob loop:
```
foreach ($f in Get-ChildItem $standardsTemplate -File)
```

This confirms all files in `templates/standards/` are automatically distributed. No further changes needed.

- [ ] **Step 3: Commit**

```bash
git add templates/standards/SECURITY-RULES.md templates/standards/TRUST-CLASSIFICATION.md templates/standards/PERFORMANCE-BUDGET.md
git commit -m "feat: add 3 new standards to templates for mb init distribution"
```

---

## Task 10: Update health-check Command

**Files:**
- Modify: `.claude/commands/health-check.md`

- [ ] **Step 1: Read the current file**

Read `.claude/commands/health-check.md` to confirm current content.

- [ ] **Step 2: Add security fixture test step**

After `## 4. Git Status` and its content, and before `## 5. Summary`, insert:

```markdown
## 5. Security Fixture Check

Run `/security-review` against the `fixtures/security/` directory. For each fixture, note whether the expected rule ID appears in the findings.

**Output header:** `### Security Fixtures`

For each subdirectory in `fixtures/security/`, report:
- `SEC-00X` — ✅ caught / ❌ missed

If `fixtures/security/` does not exist, skip this step and note it in the summary.
```

Then update the existing `## 5. Summary` to `## 6. Summary`, and update the summary step number and example:

```markdown
## 6. Summary

Print a short paragraph summarizing all five areas. Use ✅ for clean, ⚠️ for warnings, ❌ for failures. Example:

> ✅ mb doctor: all 14 checks OK. ✅ mb validate: structure valid. ⚠️ mb audit: activeContext.md is 9 days past its 7-day threshold. ✅ Working tree clean, main is up to date. ✅ Security fixtures: 9/9 rules caught.
```

- [ ] **Step 3: Update the description frontmatter**

The current description says `mb doctor (9 checks)`. Update to:

```yaml
description: Full PMB health check — mb doctor (14 checks), staleness audit, structure validation, and security fixture verification on this repo's own memory bank.
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/health-check.md
git commit -m "feat: add security fixture verification step to health-check command"
```

---

## Task 11: Update COMMANDS-REFERENCE.md

**Files:**
- Modify: `docs/COMMANDS-REFERENCE.md`

- [ ] **Step 1: Read the doctor checks table**

Read `docs/COMMANDS-REFERENCE.md` lines 131–155 to confirm the current table format.

- [ ] **Step 2: Update the doctor checks count**

Find:
```
`mb doctor` runs 12 deterministic health checks and prints a startup context observability section.
```

Replace with:
```
`mb doctor` runs 14 deterministic health checks and prints a startup context observability section.
```

- [ ] **Step 3: Add checks 13 and 14 to the table**

Find the row:
```
| — | Startup context | (observability, not a health check) ...
```

Insert before it:
```
| 13 | Security fixtures | `fixtures/security/` exists with all 9 rule subdirectories | Create fixtures manually or re-clone PMB |
| 14 | Standards count | `standards/` contains ≤ 20 `.md` files | Review standards for overlap; see `PERFORMANCE-BUDGET.md` |
```

- [ ] **Step 4: Commit**

```bash
git add docs/COMMANDS-REFERENCE.md
git commit -m "docs: add checks 13-14 to COMMANDS-REFERENCE doctor table"
```

---

## Task 12: VERSION + CHANGELOG

**Files:**
- Modify: `VERSION`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Read current files**

Read `VERSION` and the top of `CHANGELOG.md` to confirm current version and format.

- [ ] **Step 2: Bump VERSION**

Replace the content of `VERSION` with:
```
1.0.4
```

- [ ] **Step 3: Add CHANGELOG entry**

Prepend to `CHANGELOG.md` (after any existing header, before the v1.0.3 entry):

```markdown
## v1.0.4 — 2026-05-31

### Added
- `standards/SECURITY-RULES.md` — rule registry (SEC-001–009) for structured security findings
- `standards/TRUST-CLASSIFICATION.md` — TRUSTED/SEMI_TRUSTED/UNTRUSTED source classification reference
- `standards/PERFORMANCE-BUDGET.md` — explicit limits for standards count, memory entries, agent delegation depth
- `fixtures/security/` — 9 known-bad code samples for security regression testing (SEC-001–009)
- `mb doctor` Check 13: verifies `fixtures/security/` structure (9 subdirectories)
- `mb doctor` Check 14: counts `standards/*.md` files; warns if > 20
- `/health-check` step 5: runs `/security-review` against security fixtures, reports caught/missed per rule ID
- Structured finding format for `/security-review` command and security-reviewer agent: Rule ID, Evidence, Confidence, Fix
- Trust level note in security-reviewer agent for prompt-injection and rules-file-integrity findings
- All 3 new standards distributed via `mb init` and `mb upgrade` (ADVISORY_CREATE)
```

- [ ] **Step 4: Commit and tag**

```bash
git add VERSION CHANGELOG.md
git commit -m "chore: bump to v1.0.4"
git tag v1.0.4
```

---

## Task 13: Write Design Spec

**Files:**
- Create: `docs/superpowers/specs/2026-05-31-security-performance-improvements-design.md`

- [ ] **Step 1: Write spec from the approved design**

Create `docs/superpowers/specs/2026-05-31-security-performance-improvements-design.md` with the full design from the brainstorming session. Content:

```markdown
# Security & Performance Improvements Design

**Date:** 2026-05-31
**Status:** Implemented (v1.0.4)

## Context

External review of PMB's security and performance characteristics identified four concrete
improvements. The security reviewer is well-designed (advisory-only, read-only, bounded
authority) but lacked structured finding output and a formal trust model. Performance risk
is low today but context explosion is the future risk — a budget document prevents gradual
bloat.

## Decisions

### 1. Structured Findings Format
Add Rule ID, Evidence snippet, and Confidence level to security-review output.
A rule registry (`SECURITY-RULES.md`) makes rule IDs first-class auditable artifacts.

### 2. Trust Classification
Reference doc only — no runtime enforcement. Trust level is informational context for the
security reviewer. Runtime enforcement belongs in hook/CI layer when actual code exists to
gate. Deferred: base+extension pattern (project-specific rules) pending evidence of friction.

### 3. Security Regression Fixtures
Passive fixtures alone (option A) are not reliably used without automation.
Split approach: `mb doctor` checks structure (fast, no LLM), `mb health-check` runs the
reviewer against fixtures on demand (slow, semantic, explicit).
Fixtures are PMB dogfooding only — not distributed via `mb init`.

### 4. Performance Budget
Reference doc with explicit limits. `mb doctor` Check 14 enforces the standards-count
limit structurally (deterministic). Primary risk is context explosion, not compute.

## Architecture

Four deliverables:
1. `standards/SECURITY-RULES.md` — rule registry, ADVISORY_CREATE
2. `standards/TRUST-CLASSIFICATION.md` — trust reference, ADVISORY_CREATE
3. `standards/PERFORMANCE-BUDGET.md` — budget limits, ADVISORY_CREATE
4. `fixtures/security/` — PMB-only dogfooding infrastructure

Updated: `.claude/commands/security-review.md`, `.claude/agents/security-reviewer.md`,
`mb doctor` (checks 13+14), `mb health-check`, `mb upgrade` ADVISORY_CREATE.

## What Was Not Done

- Autonomous fixes or memory writes (increases risk, not value)
- Runtime trust enforcement (no hook/CI code to back it up)
- Base+extension pattern for project-specific rules (deferred — no friction evidence)
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-05-31-security-performance-improvements-design.md
git commit -m "docs: add design spec for security/performance improvements (v1.0.4)"
```

---

## Verification

- [ ] `pwsh scripts/mb.ps1 doctor` — checks 13 and 14 show `[OK]`
- [ ] `bash scripts/mb.sh doctor` — checks 13 and 14 show `[OK]`
- [ ] Run `/security-review` against `fixtures/security/SEC-001-hardcoded-secret/bad.py` — output uses structured format with `Rule: SEC-001`, `Evidence:`, `Confidence:`, `Fix:`
- [ ] Run `mb init` in a temp dir — `standards/SECURITY-RULES.md`, `TRUST-CLASSIFICATION.md`, `PERFORMANCE-BUDGET.md` are created
- [ ] Count `standards/*.md`: should be 14 (< 20 budget)
- [ ] `git tag` shows `v1.0.4`
