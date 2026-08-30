from __future__ import annotations

import re
from datetime import datetime
from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

SCHEMA_VERSION: Literal["1"] = "1"
VIN_PATTERN = re.compile(r"^[A-HJ-NPR-Z0-9]{17}$")


class APIModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class AttributeSource(StrEnum):
    OBD = "OBD"
    VIN_DECODER = "VIN_DECODER"
    OEM_DATABASE = "OEM_DATABASE"
    USER = "USER"


class SupportLevel(StrEnum):
    SUPPORTED = "supported"
    LIMITED = "limited"
    UNSUPPORTED = "unsupported"


class OperatingCondition(StrEnum):
    UNKNOWN = "unknown"
    WARM_UP = "warm_up"
    WARM_IDLE = "warm_idle"
    DRIVING = "driving"


class VehicleAttribute[ValueT](APIModel):
    value: ValueT | None
    source: AttributeSource
    requires_confirmation: bool = False


class OBDIdentity(APIModel):
    calibration_ids: list[str] = Field(default_factory=list, max_length=20)
    ecu_names: list[str] = Field(default_factory=list, max_length=20)
    supported_modes: list[int] = Field(default_factory=list, max_length=10)


class AdapterMetadata(APIModel):
    model: str = Field(min_length=1, max_length=80)
    protocol: str | None = Field(default=None, max_length=80)
    market: Literal["CA", "US"] | None = None


class VehicleCandidate(APIModel):
    vin: VehicleAttribute[str]
    model_year: VehicleAttribute[int]
    make: VehicleAttribute[str]
    model: VehicleAttribute[str]
    series: VehicleAttribute[str]
    vehicle_type: VehicleAttribute[str]
    body_class: VehicleAttribute[str]
    engine_model: VehicleAttribute[str]
    engine_configuration: VehicleAttribute[str]
    displacement_l: VehicleAttribute[float]
    engine_cylinders: VehicleAttribute[int]
    fuel_type_primary: VehicleAttribute[str]
    fuel_type_secondary: VehicleAttribute[str]
    drive_type: VehicleAttribute[str]
    transmission_style: VehicleAttribute[str]
    manufacturer: VehicleAttribute[str]
    plant_country: VehicleAttribute[str]


class DiagnosticEligibility(APIModel):
    profile_id: str | None = None
    profile_version: str | None = None
    quick_scan: SupportLevel
    health_scan: SupportLevel
    collection_plan: str | None = None
    rule_set: str | None = None
    limitations: list[str] = Field(default_factory=list)


class DiagnosticObservation(APIModel):
    schema_version: Literal["1"] = SCHEMA_VERSION
    sequence_number: int = Field(ge=0)
    recorded_at: datetime
    mode: int = Field(ge=1, le=10)
    pid: str = Field(pattern=r"^[0-9A-F]{2}$")
    value: str | int | float | bool
    unit: str | None = Field(default=None, max_length=30)
    operating_condition: OperatingCondition = OperatingCondition.UNKNOWN


class VehicleDecodeRequest(APIModel):
    schema_version: Literal["1"] = SCHEMA_VERSION
    vin: str
    model_year: int = Field(ge=1981, le=2100)
    obd_identity: OBDIdentity = Field(default_factory=OBDIdentity)
    adapter: AdapterMetadata

    @field_validator("vin")
    @classmethod
    def normalize_vin(cls, value: str) -> str:
        normalized = value.strip().upper()
        if not VIN_PATTERN.fullmatch(normalized):
            raise ValueError("VIN must contain 17 valid characters")
        return normalized


class VehicleDecodeResponse(APIModel):
    schema_version: Literal["1"] = SCHEMA_VERSION
    candidate: VehicleCandidate
    decode_warnings: list[str] = Field(default_factory=list)
    eligibility: DiagnosticEligibility


class DiagnosticProfileResolveRequest(APIModel):
    schema_version: Literal["1"] = SCHEMA_VERSION
    identity: VehicleCandidate
    obd_identity: OBDIdentity = Field(default_factory=OBDIdentity)
    adapter: AdapterMetadata


class DiagnosticProfileResolveResponse(APIModel):
    schema_version: Literal["1"] = SCHEMA_VERSION
    eligibility: DiagnosticEligibility


class HealthResponse(APIModel):
    status: Literal["ok"] = "ok"
    service: Literal["carpal-backend"] = "carpal-backend"
    version: str


class ErrorDetail(APIModel):
    location: list[str | int] = Field(default_factory=list)
    message: str
    type: str


class ErrorBody(APIModel):
    code: str
    message: str
    retryable: bool
    details: list[ErrorDetail] = Field(default_factory=list)


class ErrorResponse(APIModel):
    error: ErrorBody
