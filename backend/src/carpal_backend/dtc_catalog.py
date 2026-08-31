from __future__ import annotations

import json
from functools import lru_cache
from importlib.resources import files
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class CatalogModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class DTCEntry(CatalogModel):
    code: str = Field(pattern=r"^[PCBU][0-9A-F]{4}$")
    summary: str = Field(min_length=1, max_length=200)
    scope: Literal["generic", "manufacturer_specific"]


class DTCCatalogFile(CatalogModel):
    schema_version: Literal["1"]
    catalog_version: str = Field(pattern=r"^[0-9]+\.[0-9]+\.[0-9]+$")
    fallback_summary: str = Field(min_length=1, max_length=200)
    entries: list[DTCEntry]

    @model_validator(mode="after")
    def entries_must_have_unique_codes(self) -> DTCCatalogFile:
        codes = [entry.code for entry in self.entries]
        if len(codes) != len(set(codes)):
            raise ValueError("DTC catalog entries must have unique codes")
        return self


class DTCCatalog:
    def __init__(self, data: DTCCatalogFile) -> None:
        self.version = data.catalog_version
        self._fallback_summary = data.fallback_summary
        self._entries = {entry.code: entry for entry in data.entries}

    @classmethod
    def from_package(cls) -> DTCCatalog:
        resource = files("carpal_backend.data").joinpath("dtc_catalog.json")
        return cls(DTCCatalogFile.model_validate_json(resource.read_text(encoding="utf-8")))

    @classmethod
    def from_path(cls, path: Path) -> DTCCatalog:
        contents = json.loads(path.read_text(encoding="utf-8"))
        return cls(DTCCatalogFile.model_validate(contents))

    def summary(self, code: str) -> str:
        entry = self._entries.get(code)
        return entry.summary if entry is not None else self._fallback_summary


@lru_cache(maxsize=1)
def packaged_dtc_catalog() -> DTCCatalog:
    return DTCCatalog.from_package()
