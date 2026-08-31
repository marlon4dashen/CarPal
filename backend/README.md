# CarPal Backend

FastAPI service for VIN enrichment, diagnostic-profile resolution, and
standard OBD response parsing.

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

## DTC catalog

Plain-language DTC knowledge lives in
`src/carpal_backend/data/dtc_catalog.json`. The catalog is schema validated,
rejects duplicate or malformed codes, and provides fallback text for valid
codes without a curated description. Increment `catalog_version` whenever an
entry or fallback meaning changes; parsing responses include that version.
