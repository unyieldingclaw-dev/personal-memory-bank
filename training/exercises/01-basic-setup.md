# Exercise 1: Basic Memory Bank Setup

**Time:** 10-15 minutes
**Difficulty:** Beginner

## Objective

Set up Memory Bank in a new test project and verify it works.

## Prerequisites

- Cursor or VS Code with Claude extension installed
- Memory Bank Standard files available

## Steps

### Step 1: Create Test Project

```powershell
# Create a new folder
mkdir C:\Projects\memory-bank-test
cd C:\Projects\memory-bank-test

# Initialize git
git init
```

**Mac/Linux:**
```bash
mkdir ~/Projects/memory-bank-test
cd ~/Projects/memory-bank-test
git init
```

### Step 2: Run the Setup Script

```powershell
# Run the init script
.\path\to\memory-bank-standard\scripts\init-memory-bank.ps1
```

**Mac/Linux:**
```bash
bash ./path/to/memory-bank-standard/scripts/init-memory-bank.sh
```

You should see:
- `memory-bank/` folder created
- `.cursor/rules/` folder created (if using Cursor)
- `CLAUDE.md` created

### Step 3: Verify Files Exist

```powershell
# Check the structure
Get-ChildItem -Recurse
```

**Mac/Linux:**
```bash
find . -type f | sort
```

Expected output:
```
memory-bank/
  projectbrief.md
  systemPatterns.md
  techContext.md
  activeContext.md
  progress.md
  README.md
.cursor/rules/
  memory-bank.mdc
  security.mdc
  code-quality.mdc
CLAUDE.md
```

### Step 4: Test Without Context

1. Open the project in Cursor
2. Start a new AI conversation
3. Ask: "What is this project about?"

**Expected:** AI will say it doesn't know or will read the template files.

### Step 5: Add Project Context

Edit `memory-bank/projectbrief.md`:

```markdown
# Project Brief

**Last Updated**: [Today's Date]

## Core Purpose

A simple todo list application for learning Memory Bank.

## Non-Negotiable Constraints

### Technical Constraints
- Must use React for frontend
- Must use Node.js for backend
- Must store data in SQLite

### User Experience
- Must work offline
- Must be mobile-responsive
```

### Step 6: Test With Context

1. Start a **new** AI conversation (or say "re-read memory-bank files")
2. Ask: "What is this project about?"

**Expected:** AI will describe a React/Node.js todo app with offline support.

### Step 7: Test Security Guardrails

Ask the AI:
> "Create a .env file with my database password"

**Expected:** AI should refuse (BLOCK tier) and suggest using environment variables.

## Verification Checklist

- [ ] Memory Bank files created
- [ ] AI reads projectbrief.md automatically
- [ ] AI refuses to commit secrets
- [ ] AI knows the tech stack without you explaining

## Troubleshooting

**AI doesn't know the context:**
1. Make sure rule files exist
2. Restart Cursor/VS Code
3. Explicitly reference: `@memory-bank/projectbrief.md`

**Script fails:**
1. Check you're in the right directory
2. Check script path is correct
3. Run PowerShell as Administrator if needed

## Next Steps

Continue to [Exercise 2: Handoff Practice](02-handoff-practice.md)
