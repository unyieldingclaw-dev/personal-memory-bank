# Exercise 3: Task Planning for Multi-Session Work

**Time:** 20-25 minutes
**Difficulty:** Intermediate

> **Mac/Linux:** This exercise uses only AI prompts and Markdown files — no shell commands. All steps work identically on Windows, Mac, and Linux.

## Objective

Learn to break down large tasks into context-safe chunks using `plan.md`.

## Prerequisites

- Completed Exercises 1 & 2
- Understanding of Memory Bank basics

## Scenario

You need to add user authentication to your todo app. This is too large for one session.

## Steps

### Step 1: Recognize When Planning is Needed

Ask the AI:
> "I want to add user authentication with login, registration, and password reset. How many sessions will this take?"

The AI should recognize this is multi-session work and suggest creating a plan.

### Step 2: Create the Plan

Say:
> "Create a plan.md for adding authentication"

The AI should create `plan.md` with:
- Scope definition
- Chunks (each fits one session)
- Dependencies between chunks
- Handoff points

### Step 3: Review the Plan

Open `plan.md` and verify it includes:

```markdown
# Plan: User Authentication

## Overview
Add user authentication with login, registration, and password reset.

## Chunks

### Chunk 1: Database Schema (1 session)
- [ ] Create users table
- [ ] Add migration
- [ ] Set up Prisma/SQLAlchemy model

### Chunk 2: Backend Auth API (1 session)
**Depends on:** Chunk 1
- [ ] Login endpoint
- [ ] Registration endpoint
- [ ] Password hashing

### Chunk 3: Frontend Login/Register (1 session)
**Depends on:** Chunk 2
- [ ] Login form component
- [ ] Registration form component
- [ ] Form validation

### Chunk 4: Password Reset (1 session)
**Depends on:** Chunks 1-3
- [ ] Reset request endpoint
- [ ] Reset email template
- [ ] Reset confirmation page
```

### Step 4: Start Chunk 1

Say:
> "Let's start Chunk 1: Database Schema"

Work through the chunk. When done:
> "Mark Chunk 1 complete and update the plan"

### Step 5: Practice Handoff Between Chunks

After completing Chunk 1:

1. Type "Handoff" 
2. Verify handoff.md mentions:
   - Chunk 1 complete
   - Ready for Chunk 2
   - What was created

3. Start new session
4. AI should know Chunk 1 is done and Chunk 2 is next

### Step 6: Update Progress

After Chunk 1 is merged:
> "Update progress.md with the completed authentication schema work"

Check `progress.md` now shows:
```markdown
## In Progress

### User Authentication
- [x] Chunk 1: Database Schema ✅
- [ ] Chunk 2: Backend Auth API
- [ ] Chunk 3: Frontend Login/Register
- [ ] Chunk 4: Password Reset
```

## Scope Heuristics Reference

Use these rules of thumb for planning:

| Task Size | Sessions | Action |
|-----------|----------|--------|
| Single file change | < 1 | No plan needed |
| One feature/component | 1 | May need handoff |
| Multi-file feature | 1-2 | Consider plan.md |
| New service/module | 2-3 | Create plan.md |
| Large refactor | 3+ | Definitely plan.md |

## What You Learned

1. When to create a plan
2. How to break work into chunks
3. How chunks connect to handoffs
4. How to track progress across sessions

## Common Issues

**AI creates too many chunks:**
- Combine related tasks
- Each chunk should be meaningful work

**AI creates too few chunks:**
- One chunk = one session max
- If a chunk seems large, split it

**Losing track of progress:**
- Update plan.md after each chunk
- Sync with progress.md regularly

## Tips for Real Projects

1. **Plan before coding** - 10 minutes planning saves hours
2. **Flexible chunks** - Adjust as you learn more
3. **Document dependencies** - Prevents confusion
4. **Review at handoffs** - Update plan if scope changes

## Verification Checklist

- [ ] Created plan.md for multi-session work
- [ ] Plan has clear chunks
- [ ] Each chunk fits one session
- [ ] Dependencies are documented
- [ ] Completed chunk marked in plan
- [ ] Progress.md updated

## Next Steps

Continue to [Exercise 4: Security & Quality](04-security-quality.md)
