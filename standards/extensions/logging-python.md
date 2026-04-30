# Python Logging Extension

Extends `standards/LOGGING.md` with Python-specific patterns.

## Setup

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)

def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
```

## Usage

```python
logger = get_logger(__name__)

# Good
logger.info("order_placed", extra={"order_id": order_id, "amount": amount})

# Never: logging secrets
logger.info("payment", extra={"card_number": card, "cvv": cvv})
```

## Log Levels

```python
logger.debug("cache_miss")               # Dev details
logger.info("request_completed")         # Normal events
logger.warning("rate_limit_near")        # Handled edge cases
logger.error("db_connection_failed")     # Action needed
```
