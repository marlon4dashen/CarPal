from __future__ import annotations

from typing import Any

from carpal_backend.contracts import (
    AttributeSource,
    DiagnosticProfileResolveRequest,
    DiagnosticProfileResolveResponse,
    VehicleAttribute,
    VehicleCandidate,
    VehicleDecodeRequest,
    VehicleDecodeResponse,
)
from carpal_backend.errors import DependencyResponseError, DependencyUnavailableError
from carpal_backend.profiles import DiagnosticProfileRegistry
from carpal_backend.vpic import (
    VINDecodeProvider,
    VINProviderResponseError,
    VINProviderUnavailableError,
)


class VehicleIdentificationService:
    def __init__(
        self,
        provider: VINDecodeProvider,
        registry: DiagnosticProfileRegistry,
    ) -> None:
        self._provider = provider
        self._registry = registry

    async def decode(self, request: VehicleDecodeRequest) -> VehicleDecodeResponse:
        try:
            decoded = await self._provider.decode(request.vin, request.model_year)
        except VINProviderUnavailableError as error:
            raise DependencyUnavailableError from error
        except VINProviderResponseError as error:
            raise DependencyResponseError from error

        values = decoded.values
        warnings = list(decoded.warnings)
        self._append_consistency_warnings(request, values, warnings)
        candidate = self._candidate(request, values)
        self._append_missing_data_warnings(candidate, warnings)
        eligibility = self._registry.resolve(candidate, request.obd_identity, request.adapter)
        return VehicleDecodeResponse(
            candidate=candidate,
            decode_warnings=_deduplicate(warnings),
            eligibility=eligibility,
        )

    def resolve(
        self,
        request: DiagnosticProfileResolveRequest,
    ) -> DiagnosticProfileResolveResponse:
        return DiagnosticProfileResolveResponse(
            eligibility=self._registry.resolve(
                request.identity,
                request.obd_identity,
                request.adapter,
            )
        )

    @staticmethod
    def _candidate(request: VehicleDecodeRequest, values: dict[str, Any]) -> VehicleCandidate:
        return VehicleCandidate(
            vin=VehicleAttribute(
                value=request.vin,
                source=AttributeSource.OBD,
            ),
            model_year=VehicleAttribute(
                value=request.model_year,
                source=AttributeSource.USER,
            ),
            make=_text_attribute(values, "Make"),
            model=_model_attribute(values),
            series=_text_attribute(values, "Series"),
            vehicle_type=_text_attribute(values, "VehicleType"),
            body_class=_text_attribute(values, "BodyClass"),
            engine_model=_text_attribute(values, "EngineModel"),
            engine_configuration=_text_attribute(values, "EngineConfiguration"),
            displacement_l=_float_attribute(values, "DisplacementL"),
            engine_cylinders=_int_attribute(values, "EngineCylinders"),
            fuel_type_primary=_text_attribute(values, "FuelTypePrimary"),
            fuel_type_secondary=_text_attribute(values, "FuelTypeSecondary"),
            drive_type=_text_attribute(values, "DriveType"),
            transmission_style=_text_attribute(values, "TransmissionStyle"),
            manufacturer=_text_attribute(values, "Manufacturer"),
            plant_country=_text_attribute(values, "PlantCountry"),
        )

    @staticmethod
    def _append_consistency_warnings(
        request: VehicleDecodeRequest,
        values: dict[str, Any],
        warnings: list[str],
    ) -> None:
        decoded_vin = _clean(values.get("VIN"))
        if decoded_vin and decoded_vin.upper() != request.vin:
            warnings.append("The VIN decoder returned a different VIN than the vehicle reported.")
        decoded_year = _parse_int(values.get("ModelYear"))
        if decoded_year and decoded_year != request.model_year:
            warnings.append("The decoded model year differs from the user-confirmed model year.")

    @staticmethod
    def _append_missing_data_warnings(
        candidate: VehicleCandidate,
        warnings: list[str],
    ) -> None:
        if not candidate.make.value or not candidate.model.value:
            warnings.append("Make or model could not be decoded and requires confirmation.")
        optional_missing = [
            label
            for label, attribute in [
                ("engine", candidate.engine_model),
                ("fuel type", candidate.fuel_type_primary),
                ("drive type", candidate.drive_type),
            ]
            if attribute.value is None
        ]
        if optional_missing:
            warnings.append("The VIN decoder did not provide: " + ", ".join(optional_missing) + ".")


def _text_attribute(
    values: dict[str, Any],
    key: str,
) -> VehicleAttribute[str]:
    value = _clean(values.get(key))
    return VehicleAttribute(
        value=value,
        source=AttributeSource.VIN_DECODER,
        requires_confirmation=value is None,
    )


def _model_attribute(values: dict[str, Any]) -> VehicleAttribute[str]:
    model = _clean(values.get("Model"))
    series = _clean(values.get("Series"))
    # vPIC can put a badge-level model such as "NX 300" in Series while Model is "NX".
    has_specific_series = series and model and _normalized(series).startswith(_normalized(model))
    value = series if has_specific_series else model
    return VehicleAttribute(
        value=value,
        source=AttributeSource.VIN_DECODER,
        requires_confirmation=value is None,
    )


def _float_attribute(
    values: dict[str, Any],
    key: str,
) -> VehicleAttribute[float]:
    value = _parse_float(values.get(key))
    return VehicleAttribute(
        value=value,
        source=AttributeSource.VIN_DECODER,
        requires_confirmation=value is None,
    )


def _int_attribute(
    values: dict[str, Any],
    key: str,
) -> VehicleAttribute[int]:
    value = _parse_int(values.get(key))
    return VehicleAttribute(
        value=value,
        source=AttributeSource.VIN_DECODER,
        requires_confirmation=value is None,
    )


def _clean(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.upper() in {"NULL", "N/A", "NOT APPLICABLE"}:
        return None
    return text


def _normalized(value: str) -> str:
    return "".join(character for character in value.upper() if character.isalnum())


def _parse_float(value: Any) -> float | None:
    cleaned = _clean(value)
    if cleaned is None:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _parse_int(value: Any) -> int | None:
    parsed = _parse_float(value)
    if parsed is None or not parsed.is_integer():
        return None
    return int(parsed)


def _deduplicate(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))
