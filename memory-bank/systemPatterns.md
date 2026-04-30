# System Patterns - Memory Bank Standard

**Last Updated**: April 10, 2026

## Architecture Patterns

### Template Repository Pattern

**Decision**: This is a template repo, not a library or package.

**Rationale**:
- Teams copy files to their projects (no dependency management)
- Easy to customize per project
- Works offline without package registry
- No version conflicts between projects

**Implementation**:
```
memory-bank-standard/        # This repo (template)
    └── templates/           # Files to copy
        
your-project/                # Target project
    ├── memory-bank/         # Copied and filled in
    ├── .cursor/rules/       # Copied
    └── CLAUDE.md            # Copied
```

### Dual IDE Support

**Decision**: Support both Cursor and Claude Code with same Memory Bank files.

**Rationale**:
- Teams use different IDEs
- Memory Bank content is IDE-agnostic
- Only rule loading mechanism differs

**Implementation**:
- `memory-bank/*.md` - Shared between IDEs
- `.cursor/rules/*.mdc` - Cursor-specific rules
- `CLAUDE.md` - Claude Code instructions

## Five-Standard Architecture

The project delivers five enterprise AI coding standards:
1. **Memory Bank** — persistent context across AI sessions
2. **Security Guardrails** — 3-tier BLOCK/CONFIRM/WARN system
3. **Code Quality** — generic rules + language extensions
4. **Logging** — structured logging, PII sanitization, correlation IDs
5. **Workflow** — 7-phase feature development (Brainstorm→Spec→Plan→Implement→Simplify→Security→Commit)

**Rationale**:
- Separation of concerns
- Can adopt incrementally
- Easier to maintain and update
- Clear ownership per standard

## File Structure Patterns

### Memory Bank Files

**5-File Structure** (not more, not fewer):

| File | Purpose | Stability |
|------|---------|-----------|
| `projectbrief.md` | What and why | Very stable |
| `systemPatterns.md` | How (decisions) | Stable |
| `techContext.md` | With what (stack) | Moderate |
| `activeContext.md` | Right now | Volatile |
| `progress.md` | What's done | Updates often |

**Rationale**: 
- More files = harder to maintain
- Fewer files = too much in one place
- This split matches natural information categories

### Rule File Organization

**Cursor** (multiple files):
```
.cursor/rules/
├── memory-bank.mdc    # Core Memory Bank loading
├── security.mdc       # Security guardrails
├── code-quality.mdc   # Quality standards
└── [language].mdc     # Optional language rules
```

**Claude Code** (single file):
```
CLAUDE.md              # All rules in sections
```

**Rationale**:
- Cursor supports multiple rule files natively
- Claude Code uses single CLAUDE.md by convention
- Keep parallel structure where possible

## Content Patterns

### Template Placeholder Style

**Pattern**: Use `[bracketed placeholders]` for fillable content.

```markdown
## Core Purpose

[One paragraph describing what this project does and why it exists.]

## Non-Negotiable Constraints

### Business Requirements
- [Requirement 1 - e.g., "Zero false negatives in detection"]
```

**Rationale**:
- Clear what needs to be filled
- Examples show format without being project-specific
- Easy to search for unfilled placeholders

### Documentation Hierarchy

**Pattern**: Overview → Details → Reference

1. **README.md** - Quick start, what's included
2. **docs/SETUP-GUIDE.md** - Step-by-step instructions
3. **standards/*.md** - Full specifications
4. **docs/QUICK-REFERENCE.md** - Cheatsheet for daily use

### Training Structure

**Pattern**: Presentation + Progressive Exercises

1. **presentation.html** - Visual overview (30 min)
2. **01-basic-setup.md** - First success (10 min)
3. **02-handoff-practice.md** - Core workflow (15 min)
4. **03-task-planning.md** - Advanced usage (20 min)
5. **04-security-quality.md** - Full standard (15 min)

## Code Patterns

### Script Conventions

**PowerShell** (`.ps1`):
- Use `param()` block for arguments
- Use `Write-Host` with `-ForegroundColor`
- Support `-Force` for overwrite
- Exit with clear status messages

**Bash** (`.sh`):
- Use `set -e` for fail-fast
- Use color codes via variables
- Parse args with `while` loop
- Support `--force` flag

### Rule File Format

**Cursor `.mdc` files**:
```yaml
---
alwaysApply: true           # or globs: ["**/*.py"]
---

# Title

## Section
Content...
```

**CLAUDE.md**:
```markdown
# Project Instructions

## Section
Content...
```

## Never Do This

- ❌ Add project-specific examples to templates (keep generic)
- ❌ Require external services for core functionality
- ❌ Make templates that only work in one IDE
- ❌ Create deeply nested folder structures
- ❌ Add dependencies that need package managers
- ❌ Write documentation without "why" explanations
- ❌ Create training without hands-on exercises
- ❌ Skip the YAML frontmatter in Cursor rules
