from __future__ import annotations

import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from carpal_backend.dtc_catalog import DTCCatalog


def test_packaged_catalog_resolves_known_and_unknown_codes() -> None:
    catalog = DTCCatalog.from_package()

    assert catalog.version == "1.0.0"
    assert catalog.summary("P0171") == "System too lean (bank 1)"
    assert catalog.summary("U9999") == "Vehicle-reported diagnostic trouble code"


def test_catalog_rejects_duplicate_codes(tmp_path: Path) -> None:
    path = tmp_path / "duplicate-catalog.json"
    path.write_text(
        json.dumps(
            {
                "schema_version": "1",
                "catalog_version": "1.0.0",
                "fallback_summary": "Unknown code",
                "entries": [
                    {"code": "P0171", "summary": "First", "scope": "generic"},
                    {"code": "P0171", "summary": "Second", "scope": "generic"},
                ],
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(ValidationError, match="unique codes"):
        DTCCatalog.from_path(path)


def test_catalog_rejects_invalid_code_format(tmp_path: Path) -> None:
    path = tmp_path / "invalid-catalog.json"
    path.write_text(
        json.dumps(
            {
                "schema_version": "1",
                "catalog_version": "1.0.0",
                "fallback_summary": "Unknown code",
                "entries": [{"code": "0171", "summary": "Invalid", "scope": "generic"}],
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(ValidationError):
        DTCCatalog.from_path(path)
