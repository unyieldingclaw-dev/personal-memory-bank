# Python Extension for Code Quality Standard

Python-specific code quality rules extending the generic standard.

## Formatting

### Tools
- **Formatter**: [black](https://github.com/psf/black) (opinionated, no config needed)
- **Import Sorter**: [isort](https://github.com/PyCQA/isort) (compatible with black)

### Configuration

```toml
# pyproject.toml
[tool.black]
line-length = 88
target-version = ['py311']

[tool.isort]
profile = "black"
line_length = 88
```

### Rules
- Line length: 88 characters (black default)
- Use double quotes for strings
- Trailing commas in multi-line structures
- No manual formatting - let black handle it

## Type Safety

### Tools
- **Type Checker**: [mypy](https://mypy.readthedocs.io/)
- **Runtime Validation**: [Pydantic](https://docs.pydantic.dev/) for data models

### Configuration

```toml
# pyproject.toml
[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_ignores = true
```

### Rules

| Rule | Example |
|------|---------|
| Type hints on all public functions | `def process(data: dict) -> Result:` |
| Type hints on class attributes | `name: str` |
| Use `Optional` for nullable | `user: Optional[User] = None` |
| Avoid `Any` unless necessary | Prefer specific types |

```python
# ✅ GOOD - Fully typed
def get_user(user_id: int) -> Optional[User]:
    """Fetch user by ID, returns None if not found."""
    ...

# ❌ BAD - Missing types
def get_user(user_id):
    ...
```

## Testing

### Framework
- **Test Runner**: [pytest](https://docs.pytest.org/)
- **Coverage**: [pytest-cov](https://pytest-cov.readthedocs.io/)
- **Async Testing**: [pytest-asyncio](https://pytest-asyncio.readthedocs.io/)

### Configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "--cov=app --cov-report=term-missing"

[tool.coverage.run]
branch = true
source = ["app"]

[tool.coverage.report]
fail_under = 80
```

### Rules

| Rule | Implementation |
|------|----------------|
| Test file naming | `test_*.py` or `*_test.py` |
| Test function naming | `test_<function>_<scenario>` |
| Fixtures for setup | Use `@pytest.fixture` |
| Minimum coverage | 80% for new code |

```python
# ✅ GOOD - Clear test structure
class TestUserService:
    def test_create_user_success(self, db_session):
        """Test successful user creation."""
        result = create_user(db_session, name="Alice")
        assert result.name == "Alice"
        assert result.id is not None

    def test_create_user_duplicate_email_raises(self, db_session):
        """Test that duplicate email raises ValueError."""
        create_user(db_session, email="test@example.com")
        with pytest.raises(ValueError, match="Email already exists"):
            create_user(db_session, email="test@example.com")
```

## Async Patterns

### Rules

| Rule | Rationale |
|------|-----------|
| Use `async def` for I/O operations | Non-blocking |
| Use `asyncio.gather()` for parallel | Faster than sequential |
| Always set timeouts on external calls | Prevent hanging |
| Use `httpx` over `requests` for async | Native async support |

```python
# ✅ GOOD - Parallel async with timeout
async def fetch_all_data() -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        results = await asyncio.gather(
            client.get("/api/users"),
            client.get("/api/orders"),
            return_exceptions=True,
        )
    return process_results(results)
```

## Error Handling

### Rules

| Rule | Implementation |
|------|----------------|
| Specific exceptions | Catch `ValueError`, not `Exception` |
| Context in errors | Include relevant data |
| Logging with structlog | Structured, queryable logs |
| Re-raise when appropriate | Don't swallow unexpectedly |

```python
# ✅ GOOD - Specific handling with context
try:
    user = await get_user(user_id)
except UserNotFoundError:
    logger.warning("user_not_found", user_id=user_id)
    raise HTTPException(status_code=404, detail="User not found")
except DatabaseError as e:
    logger.error("database_error", user_id=user_id, error=str(e))
    raise HTTPException(status_code=500, detail="Database unavailable")
```

## Anti-Patterns

### Avoid These

| Anti-Pattern | Better Approach |
|--------------|-----------------|
| `from module import *` | Import specific names |
| Mutable default arguments | Use `None` and check |
| Bare `except:` | Catch specific exceptions |
| Global state | Dependency injection |
| `type()` for type checking | `isinstance()` |
| String formatting with `%` | f-strings or `.format()` |

```python
# ❌ BAD - Mutable default
def add_item(item, items=[]):
    items.append(item)
    return items

# ✅ GOOD - None default
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

## Dependencies

### Rules

| Rule | Rationale |
|------|-----------|
| Pin versions in requirements.txt | Reproducible builds |
| Use `requirements.txt` or `pyproject.toml` | Standard locations |
| Separate dev dependencies | `requirements-dev.txt` |
| Check for security issues | `pip-audit` |

```text
# requirements.txt - Production
fastapi>=0.104.0,<0.105.0
uvicorn[standard]>=0.24.0,<0.25.0
pydantic>=2.0.0,<3.0.0

# requirements-dev.txt - Development
-r requirements.txt
pytest>=7.0.0
pytest-cov>=4.0.0
black>=23.0.0
mypy>=1.0.0
```

## IDE Integration

### Cursor

Add to `.cursor/rules/python.mdc`:

```yaml
---
globs: ["**/*.py"]
---

# Python Code Quality

## Formatting
- Use black for formatting (line length 88)
- Use isort for import sorting (black profile)
- Run: `black . && isort .`

## Type Safety
- Add type hints to all public functions
- Run mypy before committing: `mypy app/`

## Testing
- Use pytest for all tests
- Minimum 80% coverage for new code
- Run: `pytest --cov=app`

## Async
- Use httpx for async HTTP (not requests)
- Always set timeouts on external calls
- Use asyncio.gather() for parallel operations
```

### Pre-commit

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 23.12.0
    hooks:
      - id: black
  - repo: https://github.com/pycqa/isort
    rev: 5.13.0
    hooks:
      - id: isort
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.7.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic]
```

## Common AI Mistakes in Python

| Mistake | Prevention |
|---------|------------|
| Using `requests` in async code | Specify httpx for async |
| Missing `await` on coroutines | Type checker catches this |
| Mutable default arguments | Explicit rule in guidelines |
| Not handling async exceptions | Require try/except in async |
| Synchronous I/O in async functions | Audit for blocking calls |
