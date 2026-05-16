---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - architecture/decisions
  - patterns/code
  - anti-patterns
last-reviewed: YYYY-MM-DD
---

# System Patterns & Architecture Decisions

**Last Updated**: [Date]

## Architecture Patterns

### [Pattern 1 Name - e.g., "Multi-Adapter Microservices"]

**Decision**: [What you decided]

**Rationale**:
- [Why reason 1]
- [Why reason 2]
- [Why reason 3]

**Implementation**:
```
[Diagram or structure showing the pattern]
```

### [Pattern 2 Name - e.g., "Dual-Mode Database"]

**Decision**: [What you decided]

**Rationale**:
- [Why reason 1]
- [Why reason 2]

**Implementation**:
- [How it works]
- [Configuration needed]

## Code Patterns

### API Response Schemas

**Always**:
- [Rule 1 - e.g., "Use Pydantic models for request/response"]
- [Rule 2 - e.g., "Include Optional fields with clear defaults"]

**Example**:
```python
# Example code showing the pattern
```

### Error Handling

**Pattern**: [e.g., "Graceful degradation with warnings"]

**Rules**:
- [Rule 1 - e.g., "Never fail entire operation if one part fails"]
- [Rule 2 - e.g., "Return partial results with data_quality_warnings"]
- [Rule 3 - e.g., "Use aggressive timeouts (500ms)"]

### [Additional Pattern]

**Pattern**: [Description]

**Rules**:
- [Rule 1]
- [Rule 2]

## Frontend Patterns

### Component Structure

**Pattern**: [e.g., "Feature-based components with shared utilities"]

```
src/
  components/
    [Component structure]
  utils/
    [Utilities structure]
```

### State Management

**Pattern**: [e.g., "React hooks + local state (no Redux)"]

**Rules**:
- [Rule 1]
- [Rule 2]

### Theme System

**Pattern**: [e.g., "CSS classes for theme-aware styling"]

**Never**: [What to avoid - e.g., "Hardcode colors"]
**Always**: [What to do - e.g., "Use semantic classes"]

## Data Flow Patterns

### [Main Flow Name - e.g., "Request Processing Flow"]

1. [Step 1]
2. [Step 2]
3. [Step 3]
4. [Step 4]

## Testing Patterns

### Test Data

**Always use these for verification**:
- [Test case 1]
- [Test case 2]
- [Test case 3]

### Manual Testing Process

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Git & Version Control

### Commit Message Format

```
<type>: <short description>

Types: feat, fix, chore, docs, refactor, test, style
```

### Branch Strategy

- `main` - [Purpose]
- `feature/*` - [Purpose]
- [Other branches]

## Never Do This

- ❌ [Anti-pattern 1 - e.g., "Create new files without explicit need"]
- ❌ [Anti-pattern 2 - e.g., "Add obvious comments"]
- ❌ [Anti-pattern 3 - e.g., "Use inline imports"]
- ❌ [Anti-pattern 4 - e.g., "Hardcode colors in components"]
- ❌ [Anti-pattern 5 - e.g., "Skip WHY comments for non-obvious logic"]
- ❌ [Anti-pattern 6 - e.g., "Commit without testing first"]
- ❌ [Anti-pattern 7 - e.g., "Force push to main"]
