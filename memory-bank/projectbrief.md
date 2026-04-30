# Project Brief - Memory Bank Standard

**Last Updated**: April 10, 2026

## Core Purpose

A reusable, enterprise-ready standard for AI coding assistants that provides:
- **Persistent context** across AI coding sessions (Memory Bank pattern)
- **Security guardrails** to prevent dangerous AI actions (3-tier system)
- **Code quality standards** for consistent AI-generated code
- **Logging standards** for production-grade structured logging

This is a **template repository** - teams copy these files to their own projects.

## Non-Negotiable Constraints

### Business Requirements
- Must work for both Cursor and Claude Code IDEs
- Must be easy to adopt (< 15 minutes setup)
- Must work for teams with mixed experience levels (enterprise + new AI coders)
- Must be deployable globally (user-level) or per-project

### Technical Constraints
- Templates must be IDE-agnostic where possible
- Rule files must use correct format per IDE:
  - Cursor: `.mdc` files with YAML frontmatter
  - Claude Code: `CLAUDE.md` in project root
- Scripts must work on Windows (PowerShell) and macOS/Linux (Bash)
- No external dependencies for core functionality

### Content Constraints
- Standards must be complete but scannable
- Templates must be fillable (not example-specific)
- Training must be hands-on, not lecture-based
- Documentation must answer "why" not just "how"

## Key Goals

### Phase 1: Core Standard (Complete)
- [x] Memory Bank standard with 5-file structure
- [x] Security Guardrails with 3-tier system
- [x] Code Quality standard with language extensions
- [x] Logging standard with structured logging
- [x] Templates for all file types
- [x] Setup scripts (PowerShell + Bash)
- [x] Training materials

### Phase 2: Distribution (Next)
- [ ] Push to internal GitLab repository
- [ ] Create npm/pip package for easier distribution
- [ ] Add more language extensions (Go, Java, C#)
- [ ] Create video walkthrough

### Phase 3: Tooling (Future)
- [ ] VS Code extension for Memory Bank management
- [ ] CI/CD integration for standard enforcement
- [ ] Analytics dashboard for adoption tracking

## Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Setup time | < 15 min | Time from clone to first AI conversation |
| Adoption | 80% of team | Number of projects using standard |
| Context savings | 90% less re-explanation | Survey / observation |
| Security incidents | 0 from AI actions | Incident tracking |

## Stakeholders

| Role | Who | Responsibility |
|------|-----|----------------|
| Standard Owner | Eric Nolan | Design, implementation, maintenance |
| Primary Users | Development Team | Daily use in projects |
| Reviewers | Team Leads | Validate applicability |
| Training | Eric Nolan | Onboarding new users |

## Out of Scope

This project explicitly does NOT:
- Replace project-specific documentation
- Enforce rules at CI/CD level (guidance only)
- Work with IDEs other than Cursor and Claude Code
- Provide AI model fine-tuning or customization
