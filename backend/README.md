# CarPal Backend

FastAPI service for VIN enrichment and diagnostic-profile resolution.

## Local setup

```bash
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
```

## Run

```bash
.venv/bin/uvicorn carpal_backend.main:app --reload
```

Interactive API documentation is available at `http://127.0.0.1:8000/docs`.

## Verify

```bash
.venv/bin/ruff check .
.venv/bin/ruff format --check .
.venv/bin/mypy src tests
.venv/bin/pytest
```

Tests replace the external vPIC provider with deterministic fixtures. They do
not require internet access or send VINs outside the test process.
