# Exercise 2: Handoff Practice

**Time:** 15-20 minutes
**Difficulty:** Beginner

## Objective

Practice the handoff workflow to ensure seamless session transitions.

## Prerequisites

- Completed Exercise 1 (Basic Setup)
- Test project with Memory Bank configured

## Steps

### Step 1: Start a Work Session

1. Open your test project in Cursor
2. Start a new AI conversation
3. Ask the AI to do some work:

```
Create a basic todo item component in React. Include:
- Checkbox for completion
- Text display
- Delete button
```

Wait for the AI to create the component.

### Step 2: Simulate Context Filling Up

In a real scenario, you'd work until context reaches ~80%. For practice, we'll trigger a handoff manually.

Say to the AI:
> "Handoff"

### Step 3: Verify Handoff File

The AI should:
1. Stop working
2. Create `handoff.md` in project root
3. Respond: "Handoff ready at `handoff.md`. Start a new conversation."

Check the handoff file:
```powershell
Get-Content handoff.md
```

**Mac/Linux:**
```bash
cat handoff.md
```

**Expected contents:**
- Summary of what was done (created todo component)
- Files modified (the component file)
- Current state
- What to do next

### Step 4: Start New Conversation

1. **Start a completely new AI conversation** (not just a new message)
2. The AI should automatically read `handoff.md`
3. Ask: "What were we working on?"

**Expected:** AI should know about the todo component and be ready to continue.

### Step 5: Continue Work

Ask the AI:
> "Continue from where we left off. What's next?"

The AI should:
- Reference the previous work
- Suggest next steps
- Be ready to implement

### Step 6: Complete and Clean Up

After confirming the handoff worked:

1. Ask AI: "Merge the handoff into Memory Bank and delete handoff.md"

The AI should:
- Update `activeContext.md` with current focus
- Update `progress.md` if anything was completed
- Delete `handoff.md`

### Step 7: Verify Clean Up

```powershell
# handoff.md should be gone
Test-Path handoff.md  # Should return False

# Check activeContext.md was updated
Get-Content memory-bank\activeContext.md
```

**Mac/Linux:**
```bash
[ -f handoff.md ] && echo "True" || echo "False"

cat memory-bank/activeContext.md
```

## What You Learned

1. How to trigger a handoff
2. What information goes in `handoff.md`
3. How a new session picks up context
4. How to merge handoff back into Memory Bank

## Common Issues

**AI doesn't create handoff.md:**
- Make sure you said exactly "Handoff"
- Check the rule file is loaded

**New session doesn't know context:**
- Verify `handoff.md` exists
- Explicitly say "Read handoff.md"

**Handoff file is incomplete:**
- AI may have been interrupted
- Trigger handoff again

## Real-World Tips

1. **Don't wait until 80%** - Handoff at natural stopping points
2. **Verify before closing** - Check handoff.md has what you need
3. **Merge promptly** - Don't leave handoff.md lying around
4. **Commit regularly** - Commit Memory Bank changes after merging

## Verification Checklist

- [ ] Triggered handoff successfully
- [ ] handoff.md created with session summary
- [ ] New session read the handoff
- [ ] Work continued seamlessly
- [ ] Handoff merged into Memory Bank
- [ ] handoff.md deleted

## Next Steps

Continue to [Exercise 3: Task Planning](03-task-planning.md)
