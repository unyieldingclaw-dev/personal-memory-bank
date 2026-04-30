# [Language] Extension for Code Quality Standard

> **Instructions**: Copy this template to create a new language extension.
> Replace `[Language]` with your language name (e.g., "Go", "Rust", "Java").
> Fill in each section with language-specific guidance.

## Formatting

### Tools
- **Formatter**: [tool name and link]
- **Linter**: [tool name and link]

### Configuration

```
[Include config file example]
```

### Rules
- [Key formatting rules for this language]
- [Line length, indentation, etc.]

## Type Safety

### Tools
- **Type Checker**: [tool name if applicable]

### Configuration

```
[Include config file example]
```

### Rules

| Rule | Example |
|------|---------|
| [Type annotation requirement] | `[code example]` |
| [Null handling approach] | `[code example]` |

```[language]
// ✅ GOOD - Example of proper typing
[code example]

// ❌ BAD - Example of poor typing
[code example]
```

## Testing

### Framework
- **Test Runner**: [framework name and link]
- **Coverage**: [coverage tool]

### Configuration

```
[Include config file example]
```

### Rules

| Rule | Implementation |
|------|----------------|
| Test file naming | `[pattern]` |
| Test function naming | `[pattern]` |
| Minimum coverage | [percentage] |

```[language]
// ✅ GOOD - Test example
[code example]
```

## [Language-Specific Patterns]

> Add sections for patterns unique to this language.
> Examples: async patterns, memory management, concurrency, etc.

### Rules

| Rule | Rationale |
|------|-----------|
| [Pattern rule] | [Why it matters] |

```[language]
// ✅ GOOD - Example
[code example]
```

## Error Handling

### Rules

| Rule | Implementation |
|------|----------------|
| [Error handling approach] | [How to implement] |

```[language]
// ✅ GOOD - Error handling example
[code example]

// ❌ BAD - Poor error handling
[code example]
```

## Anti-Patterns

### Avoid These

| Anti-Pattern | Better Approach |
|--------------|-----------------|
| [Bad practice] | [Good alternative] |
| [Bad practice] | [Good alternative] |

```[language]
// ❌ BAD
[code example]

// ✅ GOOD
[code example]
```

## Dependencies

### Rules

| Rule | Rationale |
|------|-----------|
| [Dependency management rule] | [Why] |

```
[Package file example]
```

## IDE Integration

### Cursor

Add to `.cursor/rules/[language].mdc`:

```yaml
---
globs: ["**/*.[extension]"]
---

# [Language] Code Quality

## Formatting
- [Key formatting rules]
- Run: `[command]`

## Type Safety
- [Key type safety rules]
- Run: `[command]`

## Testing
- [Testing requirements]
- Run: `[command]`
```

### Pre-commit

```yaml
# .pre-commit-config.yaml
repos:
  - repo: [repo url]
    rev: [version]
    hooks:
      - id: [hook id]
```

## Common AI Mistakes in [Language]

| Mistake | Prevention |
|---------|------------|
| [Common AI mistake] | [How to prevent] |
| [Common AI mistake] | [How to prevent] |
