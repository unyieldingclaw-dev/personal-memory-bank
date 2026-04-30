# Logging Quick Start Guide

Get production-ready structured logging running in 5 minutes.

## TL;DR

```python
# Install
pip install structlog

# Use
import structlog
logger = structlog.get_logger(__name__)
logger.info("event_name", key1="value1", key2="value2")
```

That's it. You now have structured, queryable logs.

## Why Structured Logging?

**Problem**: Traditional logs are unqueryable strings:
```python
logger.info(f"User {user_id} placed order {order_id} for ${total}")
```

Can't search for "all orders over $100" or "all actions by user-123".

**Solution**: Structured key-value logging:
```python
logger.info("order_placed", user_id="usr-123", order_id="ORD-456", total=149.99)
```

Now you can query: `event="order_placed" total>100` or `user_id="usr-123"`.

## Setup (Python)

### 1. Install

```bash
pip install structlog
```

### 2. Configure (once at app startup)

```python
import structlog
import logging

# Configure structlog
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()  # JSON for production
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

# Set log level
logging.basicConfig(
    format="%(message)s",
    level=logging.INFO,
)
```

### 3. Use Everywhere

```python
import structlog

logger = structlog.get_logger(__name__)

# Business events
logger.info("user_registered", user_id="usr-123", method="oauth")

# Errors
try:
    process_payment(order_id)
except PaymentError as e:
    logger.error("payment_failed", order_id=order_id, error=str(e), exc_info=True)
    raise

# Performance
start = time.time()
result = expensive_operation()
logger.info("operation_completed", duration_ms=(time.time() - start) * 1000)
```

## Common Patterns

### Business Events

```python
# User actions
logger.info("user_login", user_id="usr-789", method="password")
logger.info("user_logout", user_id="usr-789", session_duration_sec=3600)

# Transactions
logger.info("order_created", order_id="ORD-123", total=99.99, items=3)
logger.info("payment_processed", order_id="ORD-123", gateway="stripe", amount=99.99)

# Data operations
logger.info("record_created", table="users", record_id="usr-456")
logger.info("record_updated", table="orders", record_id="ORD-789", fields_changed=2)
```

### Error Logging

```python
try:
    result = risky_operation(param1, param2)
except ValueError as e:
    logger.error("validation_failed",
        operation="risky_operation",
        param1=param1,
        param2=param2,
        error=str(e),
        exc_info=True  # Include stack trace
    )
    raise
except Exception as e:
    logger.critical("unexpected_error",
        operation="risky_operation",
        error_type=type(e).__name__,
        error=str(e),
        exc_info=True
    )
    raise
```

### Performance Tracking

```python
import time

def track_performance(operation_name):
    start = time.time()
    try:
        yield
    finally:
        duration_ms = (time.time() - start) * 1000
        logger.info("operation_completed",
            operation=operation_name,
            duration_ms=duration_ms
        )

# Use it
with track_performance("data_analysis"):
    analyze_data(dataset)
```

### External API Calls

```python
import requests

response = requests.post(
    "https://api.stripe.com/v1/charges",
    data={"amount": 1000, "currency": "usd"}
)

logger.info("external_api_call",
    service="stripe",
    endpoint="/v1/charges",
    method="POST",
    status_code=response.status_code,
    duration_ms=response.elapsed.total_seconds() * 1000
)
```

## Environment Configuration

### Development (Human-Readable)

```bash
# .env.development
LOG_LEVEL=DEBUG
LOG_FORMAT=dev
```

Output:
```
2026-04-10 18:30:45 [INFO] order_created order_id=ORD-123 total=99.99
```

### Production (JSON)

```bash
# .env.production
LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_SKIP_PATHS=/health,/ready,/metrics
```

Output:
```json
{"timestamp":"2026-04-10T18:30:45Z","level":"INFO","event":"order_created","order_id":"ORD-123","total":99.99}
```

## Correlation IDs

Track requests across services:

```python
from uuid import uuid4

# At request entry (e.g., FastAPI middleware)
correlation_id = request.headers.get('X-Correlation-ID') or str(uuid4())
logger = logger.bind(correlation_id=correlation_id)

# All subsequent logs include correlation_id automatically
logger.info("request_started", endpoint="/api/analyze")
logger.info("database_query", table="users", query_time_ms=45)
logger.info("external_call", service="payment-gateway")
logger.info("request_completed", status=200, total_duration_ms=234)
```

Query all logs for one request: `correlation_id="req-abc123"`

## PII Sanitization

### Auto-Redaction (Recommended)

```bash
pip install structlog-pii
```

```python
from structlog_pii import PIISanitizer

structlog.configure(
    processors=[
        PIISanitizer(),  # Add this first
        # ... other processors
    ]
)

# Emails, phones, SSNs automatically redacted
logger.info("user_registered", email="john@example.com")
# Output: email="***@***.com"
```

### Manual Sanitization

```python
# Log user IDs, not emails
logger.info("user_action", user_id="usr-123")  # ✅ Safe

# Don't log PII
logger.info("user_action", email="john@example.com")  # ❌ Exposes PII
```

## FastAPI Integration

```python
from fastapi import FastAPI, Request
import structlog
from uuid import uuid4

app = FastAPI()
logger = structlog.get_logger(__name__)

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    # Generate correlation ID
    correlation_id = request.headers.get('X-Correlation-ID') or str(uuid4())
    
    # Bind to logger context
    request_logger = logger.bind(
        correlation_id=correlation_id,
        method=request.method,
        path=request.url.path
    )
    
    # Skip health checks
    if request.url.path in ["/health", "/ready"]:
        return await call_next(request)
    
    # Log request
    request_logger.info("request_started")
    
    # Process request
    start = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start) * 1000
    
    # Log response
    request_logger.info("request_completed",
        status_code=response.status_code,
        duration_ms=duration_ms
    )
    
    return response
```

## Querying Logs

### Splunk

```spl
# Find all errors for a specific user
level=ERROR user_id="usr-123"

# Track slow operations
event="operation_completed" duration_ms>5000

# Monitor payment failures
event="payment_failed" | stats count by error_type

# Trace request flow
correlation_id="req-abc123" | sort timestamp
```

### ELK (Elasticsearch)

```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "event": "order_created" }},
        { "range": { "total": { "gte": 100 }}}
      ]
    }
  }
}
```

## Common Mistakes

### ❌ String Concatenation

```python
# BAD
logger.info(f"User {user_id} logged in")

# GOOD
logger.info("user_login", user_id=user_id)
```

### ❌ Logging Secrets

```python
# BAD
logger.info("api_call", api_key=api_key)

# GOOD
logger.info("api_call", api_key_id="key-abc123")
```

### ❌ Over-Logging

```python
# BAD - 10,000 log lines
for item in items:
    logger.debug("processing_item", item_id=item.id)

# GOOD - Summary
logger.info("batch_processing", total=len(items), successful=success_count)
```

## Next Steps

- **Full Documentation**: See `standards/LOGGING.md`
- **Language-Specific**: See `standards/extensions/logging-python.md`
- **TypeScript**: See `standards/extensions/logging-typescript.md`
- **Monitoring**: Set up alerts in Splunk/ELK for error rates

## Quick Reference

```python
# Standard patterns
logger.info("event_name", key1="value1", key2="value2")
logger.error("error_name", error=str(e), exc_info=True)
logger.warning("warning_name", threshold=100, actual=150)

# With correlation ID
logger = logger.bind(correlation_id=correlation_id)

# Performance tracking
start = time.time()
result = operation()
logger.info("operation_completed", duration_ms=(time.time() - start) * 1000)
```

## Support

- **Issues**: GitLab Issues
- **Questions**: Teams — [RE - SkyNet Support - AI Discussion](https://teams.microsoft.com/l/channel/19%3A7130c6f6eb354efda1d4b3fa89546215%40thread.tacv2/RE%20-%20SkyNet%20Support%20-%20AI%20Discussion?groupId=4f72c46d-e46e-43b9-a3d6-1de811294cf8&tenantId=be0f980b-dd99-4b19-bd7b-bc71a09b026c)
- **Documentation**: `standards/LOGGING.md`
