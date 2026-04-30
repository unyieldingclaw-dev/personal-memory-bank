# Enterprise Logging Standard

Structured, queryable, production-grade logging for AI-assisted development.

## Overview

Logging is critical for troubleshooting, compliance, and monitoring. Poor logging practices create:
- Unqueryable string concatenation logs
- PII exposure in production logs
- Health check noise drowning out real issues
- Missing correlation across distributed services

This standard ensures AI generates production-ready, structured logs with proper sanitization and traceability.

## Core Principles

### 1. Structured Over Unstructured

**Always use structured logging with key-value pairs.**

```python
# ✅ GOOD - Structured, queryable in Splunk/ELK
logger.info("analysis_completed", rmi_id="RMI-61522", conflicts=3, duration_ms=245)

# ❌ BAD - Unstructured string, can't query by rmi_id
logger.info(f"Analysis completed for RMI-61522 with 3 conflicts in 245ms")
```

**Why**: Structured logs are machine-readable, enabling:
- Fast queries: `rmi_id="RMI-61522"` finds all related logs
- Aggregations: Average `duration_ms` across all analyses
- Alerting: Trigger when `conflicts > 5`

### 2. Environment-Aware Formatting

**Production uses JSON, development uses human-readable format.**

```python
# Production (LOG_FORMAT=json)
{"timestamp":"2026-04-10T18:30:45Z","level":"INFO","event":"analysis_completed","rmi_id":"RMI-61522","conflicts":3}

# Development (LOG_FORMAT=dev)
2026-04-10 18:30:45 [INFO] analysis_completed rmi_id=RMI-61522 conflicts=3
```

**Why**: 
- JSON logs integrate with log aggregators (Splunk, ELK, Datadog)
- Human-readable logs speed up local debugging
- Automatic switching based on environment prevents mistakes

### 3. Correlation IDs

**Every request gets a unique correlation ID to trace across services.**

```python
# WHY: Traces a single user request through multiple services
logger.info("request_started", correlation_id="req-abc123", endpoint="/api/analyze")
# ... calls external service ...
logger.info("external_call", correlation_id="req-abc123", service="conflict-detector")
# ... processing ...
logger.info("request_completed", correlation_id="req-abc123", status=200)
```

**Query**: `correlation_id="req-abc123"` shows the entire request flow.

### 4. PII Sanitization

**Automatically redact sensitive data in logs.**

```python
# WHY: Compliance (GDPR, CCPA) and security
logger.info("user_registered", 
    email="***@***.com",           # Auto-redacted
    phone="***-***-1234",           # Auto-redacted
    user_id="usr-12345"             # Safe to log
)
```

**Auto-redacted patterns**:
- Email addresses → `***@***.com`
- Phone numbers → `***-***-1234`
- SSN → `***-**-****`
- Credit cards → `****-****-****-1234`

### 5. Noise Reduction

**Filter out health check spam and other noise.**

```python
# WHY: Health checks create thousands of logs per day, drowning out real issues
# These endpoints are NOT logged by default:
# - /health
# - /ready
# - /healthz
# - /ping

# Configure via: LOG_SKIP_PATHS=/health,/ready,/metrics
```

## Log Levels

Use appropriate levels for proper filtering and alerting.

| Level | When to Use | Example |
|-------|-------------|---------|
| **DEBUG** | Detailed diagnostic info for troubleshooting | `logger.debug("cache_lookup", key="user:123", hit=True)` |
| **INFO** | Normal operations, business events | `logger.info("order_placed", order_id="ORD-456", total=99.99)` |
| **WARNING** | Recoverable issues, degraded performance | `logger.warning("api_slow", endpoint="/search", duration_ms=3000)` |
| **ERROR** | Errors that need attention but don't crash | `logger.error("payment_failed", order_id="ORD-789", reason="card_declined")` |
| **CRITICAL** | System failures requiring immediate action | `logger.critical("database_down", host="db.prod.local")` |

**Default**: `INFO` in production, `DEBUG` in development.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Minimum level to log: DEBUG, INFO, WARNING, ERROR, CRITICAL |
| `LOG_FORMAT` | `json` | Output format: `json` (production) or `dev` (local) |
| `LOG_SKIP_PATHS` | `/health,/ready` | Comma-separated paths to skip logging |
| `LOG_CORRELATION_HEADER` | `X-Correlation-ID` | HTTP header name for correlation ID |

## Structured Logging Patterns

### Business Events

```python
# Order processing
logger.info("order_created", 
    order_id="ORD-123",
    customer_id="CUST-456",
    total=149.99,
    items=3
)

# User actions
logger.info("user_login",
    user_id="usr-789",
    method="oauth",
    provider="google"
)
```

### Performance Tracking

```python
# WHY: Track slow operations for optimization
start = time.time()
result = expensive_operation()
duration_ms = (time.time() - start) * 1000

logger.info("operation_completed",
    operation="data_analysis",
    duration_ms=duration_ms,
    records_processed=1500
)
```

### Error Context

```python
# WHY: Include enough context to debug without reproducing
try:
    process_payment(order_id, amount)
except PaymentError as e:
    logger.error("payment_processing_failed",
        order_id=order_id,
        amount=amount,
        error_type=type(e).__name__,
        error_message=str(e),
        gateway="stripe"
    )
    raise
```

### External API Calls

```python
# WHY: Track integration health and latency
logger.info("external_api_call",
    service="stripe",
    endpoint="/v1/charges",
    method="POST",
    duration_ms=234,
    status_code=200
)
```

## Anti-Patterns

### ❌ String Concatenation

```python
# BAD - Can't query by user_id or status
logger.info(f"User {user_id} status changed to {status}")

# GOOD - Queryable fields
logger.info("user_status_changed", user_id=user_id, status=status)
```

### ❌ Logging Secrets

```python
# BAD - Exposes API key
logger.info("api_call", api_key=api_key, endpoint="/data")

# GOOD - Log safe identifiers only
logger.info("api_call", api_key_id="key-abc123", endpoint="/data")
```

### ❌ Exception Swallowing

```python
# BAD - Silent failure
try:
    risky_operation()
except Exception:
    pass

# GOOD - Log and re-raise or handle
try:
    risky_operation()
except Exception as e:
    logger.error("operation_failed", 
        operation="risky_operation",
        error=str(e),
        exc_info=True  # Include stack trace
    )
    raise
```

### ❌ Over-Logging

```python
# BAD - Logs every iteration (10,000 log lines)
for item in items:
    logger.debug("processing_item", item_id=item.id)

# GOOD - Log summary
logger.info("batch_processing_started", total_items=len(items))
# ... process ...
logger.info("batch_processing_completed", 
    total_items=len(items),
    successful=success_count,
    failed=fail_count,
    duration_ms=duration
)
```

## Implementation

### Python (structlog)

**Why structlog**: Industry-standard, supports JSON output, automatic PII sanitization.

```python
import structlog

# Configure once at app startup
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer() if LOG_FORMAT == "json" 
            else structlog.dev.ConsoleRenderer()
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

# Use in code
logger = structlog.get_logger(__name__)
logger.info("event_name", key1="value1", key2="value2")
```

### TypeScript (pino)

**Why pino**: Fastest JSON logger, low overhead, production-ready.

```typescript
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  transport: process.env.LOG_FORMAT === 'dev' ? {
    target: 'pino-pretty',
    options: { colorize: true }
  } : undefined
});

logger.info({ orderId: 'ORD-123', total: 99.99 }, 'order_created');
```

## Testing Logs

### Verify Log Output

```python
import logging
from io import StringIO

def test_user_login_logs():
    # Capture logs
    log_stream = StringIO()
    handler = logging.StreamHandler(log_stream)
    logger.addHandler(handler)
    
    # Trigger action
    login_user("usr-123")
    
    # Verify structured log
    log_output = log_stream.getvalue()
    assert "user_login" in log_output
    assert "usr-123" in log_output
```

### Test PII Sanitization

```python
def test_email_redaction():
    logger.info("user_registered", email="test@example.com")
    # Verify output contains ***@***.com, not test@example.com
```

## Monitoring & Alerting

### Key Queries (Splunk/ELK)

```spl
# Find all errors for a specific RMI
level=ERROR rmi_id="RMI-61522"

# Track slow operations
event="operation_completed" duration_ms>5000

# Monitor payment failures
event="payment_failed" | stats count by reason

# Trace request flow
correlation_id="req-abc123" | sort timestamp
```

### Alert Examples

```yaml
# Alert on high error rate
alert: error_rate_high
query: level=ERROR
threshold: count > 100 in 5 minutes

# Alert on slow API
alert: api_slow
query: event="external_api_call" duration_ms>3000
threshold: count > 10 in 1 minute
```

## Migration Guide

### From Unstructured to Structured

```python
# Before
logger.info(f"Processing RMI {rmi_id} with {conflict_count} conflicts")

# After
logger.info("rmi_processing", rmi_id=rmi_id, conflicts=conflict_count)
```

### Adding Correlation IDs

```python
# 1. Generate at request entry
correlation_id = request.headers.get('X-Correlation-ID') or generate_uuid()

# 2. Bind to logger context
logger = logger.bind(correlation_id=correlation_id)

# 3. All subsequent logs include it automatically
logger.info("processing_started")  # Includes correlation_id
```

### Enabling PII Sanitization

```python
# Add processor to structlog config
from structlog_pii import PIISanitizer

structlog.configure(
    processors=[
        PIISanitizer(),  # Auto-redacts email, phone, SSN
        # ... other processors
    ]
)
```

## Compliance

### GDPR/CCPA Requirements

- ✅ PII automatically redacted in logs
- ✅ Logs retained for 90 days (configurable)
- ✅ User IDs (not names/emails) used for tracking
- ✅ Right to deletion: Logs purged with user data

### SOC2 Requirements

- ✅ All access logged with user_id and timestamp
- ✅ Failed authentication attempts logged
- ✅ Data modifications logged with before/after
- ✅ Logs immutable (append-only)

## Language Extensions

For language-specific implementations:
- [Python Logging](extensions/logging-python.md) - structlog setup, FastAPI integration
- TypeScript logging extension is planned — see `memory-bank/progress.md`
- Go and Java logging extensions are planned — see `memory-bank/progress.md`

## Quick Reference

```python
# Standard patterns
logger.info("event_name", key1="value1", key2="value2")
logger.error("error_name", error=str(e), exc_info=True)
logger.warning("warning_name", threshold=100, actual=150)

# With correlation ID
logger = logger.bind(correlation_id=correlation_id)

# Performance tracking — structlog has no .timing() context manager; use time.time()
start = time.time()
expensive_operation()
logger.info("operation_completed", duration_ms=(time.time() - start) * 1000)

# Conditional debug — structlog defers level filtering to the stdlib handler;
# just call logger.debug() and let the handler filter it
logger.debug("detailed_info", data=value)
```

## Support

- **Documentation**: See `docs/LOGGING-GUIDE.md` for quick start
- **Examples**: See `standards/extensions/logging-python.md` for complete runnable examples
- **Issues**: Report via GitLab issues
- **Questions**: Teams — [RE - SkyNet Support - AI Discussion](https://teams.microsoft.com/l/channel/19%3A7130c6f6eb354efda1d4b3fa89546215%40thread.tacv2/RE%20-%20SkyNet%20Support%20-%20AI%20Discussion?groupId=4f72c46d-e46e-43b9-a3d6-1de811294cf8&tenantId=be0f980b-dd99-4b19-bd7b-bc71a09b026c)

---

**Version**: 1.0.0  
**Last Updated**: April 10, 2026  
**Owner**: T-Mobile Release Engineering/AERO Team
