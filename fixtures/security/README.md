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
