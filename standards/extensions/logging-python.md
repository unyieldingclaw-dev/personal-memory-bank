# Python Logging Extension

Python-specific implementation of the Enterprise Logging Standard using structlog.

## Quick Start

```bash
pip install structlog
```

```python
import structlog

logger = structlog.get_logger(__name__)
logger.info("event_name", key1="value1", key2="value2")
```

## Configuration

### Production Setup

```python
import structlog
import logging
import sys

def configure_logging(log_level="INFO", log_format="json"):
    """
    WHY: Centralized configuration ensures consistent logging across all modules.
    Call once at application startup (main.py or __init__.py).
    """
    
    # WHY: JSON in production for log aggregators, dev format for local debugging
    if log_format == "json":
        renderer = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer(colors=True)
    
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            renderer,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    
    # WHY: Configure stdlib logging to work with structlog
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, log_level.upper()),
    )

# Call at app startup
configure_logging(
    log_level=os.getenv("LOG_LEVEL", "INFO"),
    log_format=os.getenv("LOG_FORMAT", "json")
)
```

### With PII Sanitization

```bash
pip install structlog structlog-pii
```

```python
from structlog_pii import PIISanitizer

structlog.configure(
    processors=[
        PIISanitizer(),  # WHY: Auto-redacts emails, phones, SSNs for GDPR/CCPA
        structlog.stdlib.filter_by_level,
        # ... other processors
    ]
)
```

## Framework Integration

### FastAPI

```python
from fastapi import FastAPI, Request
from uuid import uuid4
import structlog
import time

app = FastAPI()
logger = structlog.get_logger(__name__)

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """
    WHY: Automatic request/response logging with correlation IDs.
    Traces entire request lifecycle without manual logging in every endpoint.
    """
    
    # WHY: Correlation ID traces request across services
    correlation_id = request.headers.get('X-Correlation-ID') or str(uuid4())
    
    # WHY: Bind to context so all logs in this request include these fields
    request_logger = logger.bind(
        correlation_id=correlation_id,
        method=request.method,
        path=request.url.path,
        # WARNING: IP addresses are PII under GDPR. Log only if your privacy
        # policy covers it and log access is restricted. PIISanitizer does NOT
        # redact IPs by default — add a custom processor if needed.
        client_ip=request.client.host,
    )
    
    # WHY: Skip health check noise (thousands of logs per day)
    skip_paths = os.getenv("LOG_SKIP_PATHS", "/health,/ready").split(",")
    if request.url.path in skip_paths:
        return await call_next(request)
    
    request_logger.info("request_started")
    
    start = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start) * 1000
    
    # WHY: Log response metrics for monitoring and alerting
    request_logger.info("request_completed",
        status_code=response.status_code,
        duration_ms=duration_ms
    )
    
    # WHY: Add correlation ID to response for client-side tracing
    response.headers["X-Correlation-ID"] = correlation_id
    
    return response

@app.get("/api/users/{user_id}")
async def get_user(user_id: str):
    # Logger automatically includes correlation_id from middleware
    logger.info("user_lookup_started", user_id=user_id)
    
    user = await db.get_user(user_id)
    
    logger.info("user_lookup_completed", user_id=user_id, found=user is not None)
    return user
```

### Flask

```python
from flask import Flask, request, g
from uuid import uuid4
import structlog
import time

app = Flask(__name__)
logger = structlog.get_logger(__name__)

@app.before_request
def before_request():
    """WHY: Set up correlation ID and timing for each request."""
    g.correlation_id = request.headers.get('X-Correlation-ID') or str(uuid4())
    g.start_time = time.time()
    g.logger = logger.bind(
        correlation_id=g.correlation_id,
        method=request.method,
        path=request.path
    )
    
    # Skip health checks
    if request.path not in ["/health", "/ready"]:
        g.logger.info("request_started")

@app.after_request
def after_request(response):
    """WHY: Log response metrics automatically."""
    if hasattr(g, 'logger') and request.path not in ["/health", "/ready"]:
        duration_ms = (time.time() - g.start_time) * 1000
        g.logger.info("request_completed",
            status_code=response.status_code,
            duration_ms=duration_ms
        )
        response.headers["X-Correlation-ID"] = g.correlation_id
    return response
```

### Django

```python
# middleware.py
import structlog
import time
from uuid import uuid4

logger = structlog.get_logger(__name__)

class LoggingMiddleware:
    """
    WHY: Django middleware for automatic request/response logging.
    Add to MIDDLEWARE in settings.py.
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Set up correlation ID
        correlation_id = request.META.get('HTTP_X_CORRELATION_ID') or str(uuid4())
        request.correlation_id = correlation_id
        
        # Bind logger
        request.logger = logger.bind(
            correlation_id=correlation_id,
            method=request.method,
            path=request.path
        )
        
        # Skip health checks
        if request.path not in ["/health", "/ready"]:
            request.logger.info("request_started")
        
        start = time.time()
        response = self.get_response(request)
        duration_ms = (time.time() - start) * 1000
        
        if request.path not in ["/health", "/ready"]:
            request.logger.info("request_completed",
                status_code=response.status_code,
                duration_ms=duration_ms
            )
        
        response["X-Correlation-ID"] = correlation_id
        return response
```

## Common Patterns

### Database Operations

```python
import structlog

logger = structlog.get_logger(__name__)

async def get_user(user_id: str):
    """
    WHY: Log database operations for performance monitoring and debugging.
    """
    logger.info("database_query_started", 
        table="users",
        operation="SELECT",
        user_id=user_id
    )
    
    start = time.time()
    try:
        user = await db.users.find_one({"id": user_id})
        duration_ms = (time.time() - start) * 1000
        
        logger.info("database_query_completed",
            table="users",
            operation="SELECT",
            user_id=user_id,
            found=user is not None,
            duration_ms=duration_ms
        )
        
        return user
    except Exception as e:
        logger.error("database_query_failed",
            table="users",
            operation="SELECT",
            user_id=user_id,
            error=str(e),
            exc_info=True
        )
        raise
```

### Background Tasks (Celery)

```python
from celery import Celery
import structlog

app = Celery('tasks')
logger = structlog.get_logger(__name__)

@app.task
def process_order(order_id: str):
    """
    WHY: Background tasks need logging for monitoring and debugging.
    Generate correlation ID for task tracing.
    """
    task_logger = logger.bind(
        task_id=process_order.request.id,
        order_id=order_id
    )
    
    task_logger.info("task_started")
    
    try:
        # Process order
        result = perform_processing(order_id)
        
        task_logger.info("task_completed",
            result=result,
            duration_ms=result.get('duration_ms')
        )
        
        return result
    except Exception as e:
        task_logger.error("task_failed",
            error=str(e),
            exc_info=True
        )
        raise
```

### Async Operations

```python
import asyncio
import structlog

logger = structlog.get_logger(__name__)

async def fetch_multiple_apis(endpoints: list[str]):
    """
    WHY: Log parallel operations to track which APIs are slow.
    """
    logger.info("parallel_fetch_started", endpoint_count=len(endpoints))
    
    async def fetch_one(endpoint: str):
        start = time.time()
        try:
            response = await http_client.get(endpoint)
            duration_ms = (time.time() - start) * 1000
            
            logger.info("api_call_completed",
                endpoint=endpoint,
                status_code=response.status_code,
                duration_ms=duration_ms
            )
            
            return response
        except Exception as e:
            logger.error("api_call_failed",
                endpoint=endpoint,
                error=str(e)
            )
            raise
    
    results = await asyncio.gather(*[fetch_one(ep) for ep in endpoints])
    
    logger.info("parallel_fetch_completed", 
        endpoint_count=len(endpoints),
        successful=len([r for r in results if r])
    )
    
    return results
```

## Testing

### Capturing Logs in Tests

```python
import pytest
import structlog
from io import StringIO
import json

@pytest.fixture
def capture_logs():
    """
    WHY: Capture logs in tests to verify logging behavior.
    """
    stream = StringIO()
    
    structlog.configure(
        processors=[
            structlog.processors.JSONRenderer()
        ],
        logger_factory=structlog.PrintLoggerFactory(file=stream),
        cache_logger_on_first_use=False,
    )
    
    yield stream
    
    # Reset configuration
    structlog.reset_defaults()

def test_user_creation_logs(capture_logs):
    """Verify user creation logs structured data."""
    logger = structlog.get_logger()
    
    # Trigger action
    logger.info("user_created", user_id="usr-123", method="oauth")
    
    # Verify log output
    log_output = capture_logs.getvalue()
    log_data = json.loads(log_output)
    
    assert log_data["event"] == "user_created"
    assert log_data["user_id"] == "usr-123"
    assert log_data["method"] == "oauth"
```

### Testing PII Sanitization

```python
def test_email_redaction(capture_logs):
    """Verify emails are redacted in logs."""
    from structlog_pii import PIISanitizer
    
    structlog.configure(
        processors=[
            PIISanitizer(),
            structlog.processors.JSONRenderer()
        ],
        logger_factory=structlog.PrintLoggerFactory(file=capture_logs),
    )
    
    logger = structlog.get_logger()
    logger.info("user_registered", email="test@example.com")
    
    log_output = capture_logs.getvalue()
    
    # Email should be redacted
    assert "test@example.com" not in log_output
    assert "***@***.com" in log_output
```

## Performance Considerations

### Lazy Evaluation

```python
# WHY: Avoid expensive operations if log level won't show them
if logger.isEnabledFor(logging.DEBUG):
    logger.debug("detailed_data", 
        data=expensive_serialization(large_object)
    )
```

### Batch Logging

```python
# WHY: Log summaries instead of individual items in loops
successful = []
failed = []

for item in items:
    try:
        process(item)
        successful.append(item.id)
    except Exception as e:
        failed.append({"id": item.id, "error": str(e)})

# Single log with summary
logger.info("batch_processing_completed",
    total=len(items),
    successful=len(successful),
    failed=len(failed),
    failure_rate=len(failed) / len(items) if items else 0
)
```

## Environment Configuration

```python
# config.py
import os
from typing import Literal

class LoggingConfig:
    """
    WHY: Centralized configuration from environment variables.
    """
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    LOG_FORMAT: Literal["json", "dev"] = os.getenv("LOG_FORMAT", "json")
    LOG_SKIP_PATHS: list[str] = os.getenv("LOG_SKIP_PATHS", "/health,/ready").split(",")
    LOG_CORRELATION_HEADER: str = os.getenv("LOG_CORRELATION_HEADER", "X-Correlation-ID")
```

## Full Example

```python
# main.py
import structlog
import logging
import os
from fastapi import FastAPI, Request
from uuid import uuid4
import time

# Configure logging at startup
def configure_logging():
    log_format = os.getenv("LOG_FORMAT", "json")
    renderer = (
        structlog.processors.JSONRenderer() 
        if log_format == "json" 
        else structlog.dev.ConsoleRenderer(colors=True)
    )
    
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            renderer,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    logging.basicConfig(
        format="%(message)s",
        level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper()),
    )

configure_logging()

app = FastAPI()
logger = structlog.get_logger(__name__)

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    correlation_id = request.headers.get('X-Correlation-ID') or str(uuid4())
    request_logger = logger.bind(
        correlation_id=correlation_id,
        method=request.method,
        path=request.url.path
    )
    
    skip_paths = os.getenv("LOG_SKIP_PATHS", "/health,/ready").split(",")
    if request.url.path in skip_paths:
        return await call_next(request)
    
    request_logger.info("request_started")
    
    start = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start) * 1000
    
    request_logger.info("request_completed",
        status_code=response.status_code,
        duration_ms=duration_ms
    )
    
    response.headers["X-Correlation-ID"] = correlation_id
    return response

@app.get("/api/orders/{order_id}")
async def get_order(order_id: str):
    logger.info("order_lookup_started", order_id=order_id)
    
    try:
        order = await db.get_order(order_id)
        logger.info("order_lookup_completed", 
            order_id=order_id,
            found=order is not None
        )
        return order
    except Exception as e:
        logger.error("order_lookup_failed",
            order_id=order_id,
            error=str(e),
            exc_info=True
        )
        raise

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

## See Also

- [Logging Standard](../LOGGING.md) - Full specification
- [Quick Start Guide](../../docs/LOGGING-GUIDE.md) - 5-minute setup
- [structlog Documentation](https://www.structlog.org/) - Official docs
