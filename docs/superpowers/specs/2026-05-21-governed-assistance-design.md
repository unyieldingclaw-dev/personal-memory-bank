# Governed Assistance Philosophy — Design

## Context

The Personal Memory Bank repo completed Sub-project A (hook coverage expansion). The GPT governance audit identified a key gap: the repo operates well as "persistent AI memory with safety standards" but has not yet articulated the shift to "layered constrained operational governance." Three high-value surfaces are missing the governed-assistance philosophy and enforcement-layer architecture:

- `templates/CLAUDE.md` — advisory file Claude reads at session start; no governance framing
- `README.md` — public-facing doc; no governance model section
- `docs/HOOKS-GUIDE.md` — hook architecture doc; no enforcement-layer matrix

This sub-project adds the "governed assistance, not autonomous intelligence" philosophy and documents the Hook/Opponent/CI responsibility split — making explicit what was previously implicit.

## Design

### Approach: Minimal targeted insertions (3 files)

No new files. No cross-editing existing standards. Three surgical additions:

1. **`templates/CLAUDE.md`** — new `## Governed Assistance Model` section (after `## Context Compaction Recovery`, before `## Security Guardrails`)
2. **`README.md`** — new "Governance Model" `<details>` block after `## How It Works` table, before `## Advanced Features`
3. **`docs/HOOKS-GUIDE.md`** — new `## Enforcement Layer Architecture` section after the Hook Types table, before `## Default Hooks in This Standard`

### Content added to `templates/CLAUDE.md`

```markdown
## Governed Assistance Model

This system operates on **governed assistance, not autonomous intelligence.** Claude is a bounded collaborator — capable and useful, but not self-directed. That distinction matters:

**What governed assistance means in practice:**
- Claude reads context the user controls (memory bank files), not context Claude generates autonomously
- Claude proposes; the user approves. Scope expansion, file creation, and architectural decisions require explicit direction.
- When context is ambiguous, Claude asks — it does not assume, infer a mandate, or take creative initiative
- Autonomous reasoning and persistent memory are tool features; constrained operation, explicit scope, and layered enforcement are governance features that make the tool safe to depend on

**Enforcement is layered — from softest to hardest:**
- **CLAUDE.md** (this file): advisory — Claude reads this and follows it, but can drift when context-compacted or distracted
- **Hooks**: deterministic structural enforcement — fires on every tool call, cannot be talked around
- **Reviewer / Opponent**: semantic enforcement — a second agent or human reviewer checks scope and quality
- **CI**: deterministic gate — enforces patterns the hook layer can't (file size, forbidden imports, secret scanning)

When layers conflict, the more deterministic layer wins. Advisory rules shape behavior proactively; enforcement layers catch drift when advisory isn't enough.
```

### Content added to `README.md`

```markdown
<details>
<summary>Governance Model</summary>

Memory Bank is built on **governed assistance** — the idea that AI is most useful when it operates within explicit, layered constraints rather than as an autonomous agent. The system enforces this at four levels:

| Layer | Type | Responsibility |
|-------|------|----------------|
| `CLAUDE.md` | Advisory | Behavioral norms, workflow patterns, code style |
| Hooks | Deterministic structural | Per-command enforcement — blocks/confirms/warns on dangerous ops |
| Reviewer / Opponent | Semantic | Scope drift, spec compliance, code quality checks |
| CI | Deterministic gates | Codebase-wide invariants (file size, forbidden patterns, secrets) |

See [`docs/HOOKS-GUIDE.md`](docs/HOOKS-GUIDE.md) for the full enforcement layer architecture.

</details>
```

### Content added to `docs/HOOKS-GUIDE.md`

```markdown
## Enforcement Layer Architecture

Hooks are one layer in a four-layer enforcement stack. Understanding which layer owns which concern prevents duplication and drift:

| Layer | Kind | Owns | Does NOT own |
|-------|------|------|-------------|
| **CLAUDE.md** | Advisory | Behavioral norms, workflow philosophy, code style | Anything requiring guaranteed execution |
| **Hooks** | Deterministic structural | Per-tool-call pattern enforcement: dangerous commands, credential access | Semantic correctness, business logic review |
| **Reviewer / Opponent** | Semantic | Spec compliance, scope drift, code quality | Mechanical pattern matching |
| **CI** | Deterministic gate | Codebase invariants: file size, forbidden imports, secret scanning | Real-time per-command interception |

**Design rule:** Don't duplicate concerns across layers. If a check belongs in CI, adding it to hooks creates two places to update when patterns change. If a check is semantic, adding it to hooks creates false confidence (simple pattern matching misses context). Each layer does its job; the stack as a whole provides defense in depth.
```

## Files to Modify
- `templates/CLAUDE.md`
- `README.md`
- `docs/HOOKS-GUIDE.md`

## Verification
1. Read `templates/CLAUDE.md` — confirm `## Governed Assistance Model` section present
2. Read `README.md` — confirm Governance Model `<details>` block present after How It Works
3. Read `docs/HOOKS-GUIDE.md` — confirm `## Enforcement Layer Architecture` section present
