from __future__ import annotations

import json
import re
from importlib.resources import files
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from carpal_backend.contracts import (
    AdapterMetadata,
    DiagnosticEligibility,
    OBDIdentity,
    SupportLevel,
    VehicleCandidate,
)


class ProfileModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ProfileMatch(ProfileModel):
    makes: list[str] = Field(min_length=1)
    models: list[str] = Field(min_length=1)
    years: list[int] = Field(min_length=1)
    engine_models: list[str] = Field(default_factory=list)
    fuel_types: list[str] = Field(default_factory=list)
    markets: list[Literal["CA", "US"]] = Field(default_factory=list)


class ProfileHealthScan(ProfileModel):
    enabled: bool
    collection_plan: str | None = None
    rule_set: str | None = None


class DiagnosticProfile(ProfileModel):
    id: str
    version: str
    state: Literal["draft", "enabled", "disabled"]
    match: ProfileMatch
    health_scan: ProfileHealthScan
    limitations: list[str] = Field(default_factory=list)


class DiagnosticProfileFile(ProfileModel):
    schema_version: Literal["1"]
    supported_adapters: list[str] = Field(min_length=1)
    profiles: list[DiagnosticProfile]


class DiagnosticProfileRegistry:
    def __init__(self, data: DiagnosticProfileFile) -> None:
        self._profiles = tuple(data.profiles)
        self._supported_adapters = frozenset(_normalize(value) for value in data.supported_adapters)

    @classmethod
    def from_package(cls) -> DiagnosticProfileRegistry:
        resource = files("carpal_backend.data").joinpath("diagnostic_profiles.json")
        return cls(DiagnosticProfileFile.model_validate_json(resource.read_text(encoding="utf-8")))

    @classmethod
    def from_path(cls, path: Path) -> DiagnosticProfileRegistry:
        contents = json.loads(path.read_text(encoding="utf-8"))
        return cls(DiagnosticProfileFile.model_validate(contents))

    def resolve(
        self,
        identity: VehicleCandidate,
        obd_identity: OBDIdentity,
        adapter: AdapterMetadata,
    ) -> DiagnosticEligibility:
        if _normalize(adapter.model) not in self._supported_adapters:
            return DiagnosticEligibility(
                quick_scan=SupportLevel.UNSUPPORTED,
                health_scan=SupportLevel.UNSUPPORTED,
                limitations=["This adapter model is not supported by the MVP."],
            )

        quick_level = (
            SupportLevel.SUPPORTED if 1 in obd_identity.supported_modes else SupportLevel.LIMITED
        )
        quick_limitations = (
            []
            if quick_level is SupportLevel.SUPPORTED
            else ["Quick Scan support requires standard OBD capability discovery."]
        )
        matches = [
            profile
            for profile in self._profiles
            if profile.state == "enabled" and self._matches(profile.match, identity, adapter)
        ]

        if len(matches) != 1:
            limitations = quick_limitations.copy()
            limitations.append(
                "No enabled Health Scan profile matches the confirmed vehicle identity."
                if not matches
                else "Vehicle identity matches more than one diagnostic profile."
            )
            return DiagnosticEligibility(
                quick_scan=quick_level,
                health_scan=SupportLevel.UNSUPPORTED,
                limitations=limitations,
            )

        profile = matches[0]
        health_supported = profile.health_scan.enabled and quick_level is SupportLevel.SUPPORTED
        health_level = SupportLevel.SUPPORTED if health_supported else SupportLevel.UNSUPPORTED
        return DiagnosticEligibility(
            profile_id=profile.id,
            profile_version=profile.version,
            quick_scan=quick_level,
            health_scan=health_level,
            collection_plan=profile.health_scan.collection_plan if health_supported else None,
            rule_set=profile.health_scan.rule_set if health_supported else None,
            limitations=[*profile.limitations, *quick_limitations],
        )

    @staticmethod
    def _matches(
        criteria: ProfileMatch,
        identity: VehicleCandidate,
        adapter: AdapterMetadata,
    ) -> bool:
        make = _attribute_text(identity.make.value)
        model = _attribute_text(identity.model.value)
        year = identity.model_year.value
        if make not in {_normalize(value) for value in criteria.makes}:
            return False
        if model not in {_normalize(value) for value in criteria.models}:
            return False
        if year not in criteria.years:
            return False
        if criteria.markets and adapter.market and adapter.market not in criteria.markets:
            return False

        engine = _attribute_text(identity.engine_model.value)
        if (
            engine
            and criteria.engine_models
            and engine not in {_normalize(value) for value in criteria.engine_models}
        ):
            return False
        fuel = _attribute_text(identity.fuel_type_primary.value)
        fuel_mismatch = (
            fuel
            and criteria.fuel_types
            and fuel not in {_normalize(value) for value in criteria.fuel_types}
        )
        return not fuel_mismatch


def _attribute_text(value: str | None) -> str:
    return _normalize(value or "")


def _normalize(value: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "", value.upper())
