# Logging Guide

See `standards/LOGGING.md` for the core rules.

## Quick Reference

- Structured format (key-value or JSON), not f-string concatenation
- Log levels: DEBUG / INFO / WARN / ERROR
- Never log secrets, credentials, or tokens
- Log the event and relevant IDs, not a prose sentence

## Python Setup

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)

logger.info("order_placed", extra={"order_id": order_id, "amount": amount})
```

## TypeScript Setup

```typescript
const log = (level: string, event: string, data?: object) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, event, ...data }));

log("INFO", "order_placed", { orderId, amount });
```
