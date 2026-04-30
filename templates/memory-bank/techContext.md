# Technical Context & Stack

**Last Updated**: [Date]

## Development Environment

| Component | Value |
|-----------|-------|
| OS | [e.g., Windows 10, macOS, Linux] |
| Shell | [e.g., PowerShell, bash, zsh] |
| IDE | [e.g., Cursor, VS Code] |
| Git | [Remote URL(s)] |
| Package Manager | [e.g., npm, pnpm, pip] |

## Backend Stack

### Core Framework
- **Language**: [e.g., Python 3.11+]
- **Framework**: [e.g., FastAPI]
- **Server**: [e.g., Uvicorn]
- **Validation**: [e.g., Pydantic]

### Data Layer
- **Primary Database**: [e.g., PostgreSQL 15+]
- **Fallback Database**: [e.g., SQLite 3.x]
- **ORM**: [e.g., SQLAlchemy 2.x]
- **Migrations**: [e.g., Alembic]

### Caching & Messaging
- **Cache**: [e.g., Redis 7.x]
- **Queue**: [e.g., RabbitMQ 3.x]

### External APIs
- [API 1]: [Description, version]
- [API 2]: [Description, version]

### Dependencies

```
[Key dependencies with versions]
```

## Frontend Stack

### Framework
- **Framework**: [e.g., React 18]
- **Language**: [e.g., TypeScript 5.x]
- **Build Tool**: [e.g., Vite 5.x]
- **UI Library**: [e.g., Mantine 7.x]

### Dependencies

```json
{
  "key": "dependencies"
}
```

## Infrastructure

### Services & Ports

| Service | Port | Protocol | Status |
|---------|------|----------|--------|
| [Service 1] | [Port] | [HTTP/TCP] | [Running/Stopped] |
| [Service 2] | [Port] | [HTTP/TCP] | [Running/Stopped] |
| [Service 3] | [Port] | [HTTP/TCP] | [Running/Stopped] |

### Docker Services (if applicable)

```yaml
services:
  [service]:
    image: [image]
    ports: ["host:container"]
```

## Configuration

### Environment Variables

```bash
# Required
[VAR_NAME]=[description]

# Optional
[VAR_NAME]=[description]

# Feature Flags
[FLAG_NAME]=[true/false]
```

### Configuration Files

| File | Purpose |
|------|---------|
| [filename] | [what it configures] |
| [filename] | [what it configures] |

## Database Schema

### Key Tables
- **[table]**: [Purpose]
- **[table]**: [Purpose]
- **[table]**: [Purpose]

### Key Indexes
- [Index description]
- [Index description]

## External Service Constraints

### [Service 1]
- **Rate Limit**: [limit]
- **Auth**: [auth method]
- **Quirks**: [any special considerations]

### [Service 2]
- **Rate Limit**: [limit]
- **Auth**: [auth method]
- **Quirks**: [any special considerations]

## Performance Characteristics

### Latency Budget

| Operation | Target | Actual |
|-----------|--------|--------|
| [Operation 1] | [target] | [actual] |
| [Operation 2] | [target] | [actual] |
| [Operation 3] | [target] | [actual] |

### Optimization Strategies
- [Strategy 1]
- [Strategy 2]
- [Strategy 3]

## Development Workflow

### Starting Services

```bash
# Commands to start services
```

### Running Tests

```bash
# Commands to run tests
```

## Deployment

### Current State
- **Environment**: [local/staging/production]
- **Distribution**: [how code is deployed]

### Requirements
- [Requirement 1]
- [Requirement 2]
