# Agent Memory, Context, and Out-of-Band Consolidation

**Status:** Research candidate — not an adopted PMB design.

**Captured:** 2026-08-29

## Why this is being preserved

Several recent external sources describe a recurring distinction between:

- memory as files an agent can read and write during normal work;
- infrastructure for many concurrent, long-running agents;
- periodic, out-of-band consolidation of accumulated session material; and
- the practical limits of putting more and more memory into every live agent context.

These ideas may be relevant to PMB, but they should not be treated as evidence that PMB needs a new memory architecture. PMB should first stabilize its current implementation.

## Source-derived observations

### 1. Agent memory evolved from static instructions toward writable files

A presentation shown in the referenced material describes a progression:

`CLAUDE.md` → memory tool → skills → `memory/` files

The framing is that persistent memory can move from a single convention file toward structured files that agents can read and write.

**Potential PMB relevance:** PMB already uses structured files and an authority hierarchy. The interesting question is not whether PMB should add another memory mechanism, but whether its existing files provide the right boundaries and lifecycle for persistent knowledge.

### 2. Production memory introduces concurrency, attribution, and stale-scope problems

The presentation identifies three scaling problems:

- concurrent writes by many agents;
- lost attribution of who wrote memory and when; and
- stale or mixed scopes contaminating later runs.

A later diagram proposes versioning, author/session attribution, content-hash preconditions, permissions, and separate read-only/read-write scopes.

**Potential PMB relevance:** These are primarily multi-agent/shared-memory concerns. They should not automatically become PMB requirements for a single-project workflow. They are worth revisiting if PMB begins supporting multiple concurrent agents writing shared memory.

### 3. Out-of-band "dreaming" is a consolidation pattern

The presentation describes a periodic process that consumes transcripts from agent sessions, verifies/organizes/enriches memory, and writes an updated memory state for subsequent sessions. Another diagram shows an orchestrator dispatching one subagent per session transcript against a cloned input memory store, with an output memory store produced after consolidation.

**Potential PMB relevance:** This is the strongest research lead. PMB already has memory maintenance concepts such as freshness, provenance, cleanup, and context-size awareness. An out-of-band consolidation process could potentially separate *doing work* from *curating memory* rather than asking every working session to continuously reorganize its own memory.

No implementation decision is implied here.

### 4. The useful part of the "second brain" idea may simply be disciplined files and automation

A separate video argues against treating Obsidian graphs, animated knowledge maps, voice assistants, or a branded "agentic OS" as inherently valuable. Its practical recommendation is to keep useful information in ordinary files, automate deterministic work with code where possible, and use AI where reasoning is actually needed. It specifically emphasizes avoiding unnecessary token consumption for work that can be performed by ordinary automation.

**Potential PMB relevance:** This reinforces an existing PMB design preference: do not add infrastructure merely because it makes an agent system look more sophisticated. Deterministic tooling should handle deterministic work; AI should be used where judgment or synthesis is actually useful.

### 5. Terminal multiplexing is an execution concern, not automatically a memory concern

The Herdr material describes a terminal multiplexer designed for multiple AI agents, including persistent local sessions, remote/VPS operation, agent detection/tracking, and an agent-controllable CLI.

**Potential PMB relevance:** Useful as context for long-running/multi-agent execution, but not currently a reason to add a multiplexer or remote-agent layer to PMB.

### 6. Software-factory diagrams emphasize the surrounding control loop

The referenced software-factory material depicts a loop around coding agents involving orchestration, harnesses, models, sandboxes, automated testing, agentic testing, code review, human review, deployment, monitoring, and incoming work.

**Potential PMB relevance:** The useful lesson is the separation of concerns around an agent rather than the specific product stack. PMB, ACR, and the harness should remain distinct systems with explicit handoffs rather than becoming one large autonomous platform.

## Candidate PMB investigations

These are questions for later review, not requirements:

1. **Could PMB perform memory consolidation out of band?**
   - What information would be eligible?
   - What source/provenance would be retained?
   - What deterministic safeguards would constrain writes?
   - Would the benefit justify the additional orchestration and token cost?

2. **Should PMB distinguish working context from durable memory more explicitly?**
   - `activeContext` and `progress` already provide some separation.
   - Determine whether a further boundary solves an observed problem or merely creates another layer.

3. **If PMB supports multiple concurrent agents, what minimum concurrency controls are actually needed?**
   - content-hash preconditions;
   - explicit writer/session attribution;
   - version history;
   - scoped permissions.

4. **Should memory maintenance be treated as a separate lifecycle from normal task execution?**
   - Compare current `mb clean` / freshness mechanisms with an offline consolidation model.

5. **Can every proposed memory feature be justified against context cost and operational complexity?**

## Explicit non-conclusions

- PMB does **not** currently need Obsidian.
- PMB does **not** currently need RAG/vector search merely because a large knowledge base might exist someday.
- PMB does **not** currently need a voice assistant.
- PMB does **not** currently need a terminal multiplexer.
- PMB does **not** currently need autonomous "dreaming."
- Multi-agent concurrency controls should not be added until concurrent shared-memory writes are an actual PMB requirement.

## Evidence discipline

These notes preserve claims from the supplied video material and screenshots. They are research leads, not independently verified product or architectural claims. Before adopting any item, verify the original source, inspect PMB's current implementation, and establish an observed problem or measurable benefit.
