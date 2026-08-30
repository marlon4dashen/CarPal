from __future__ import annotations

from typing import Any

from carpal_backend.contracts import VehicleDecodeRequest
from carpal_backend.profiles import DiagnosticProfileRegistry
from carpal_backend.vehicle_identification import VehicleIdentificationService


def test_wrong_year_does_not_enable_health_scan(
    vpic_values: dict[str, Any],
    decode_payload: dict[str, Any],
) -> None:
    request = VehicleDecodeRequest.model_validate({**decode_payload, "model_year": 2021})
    candidate = VehicleIdentificationService._candidate(request, vpic_values)

    result = DiagnosticProfileRegistry.from_package().resolve(
        candidate, request.obd_identity, request.adapter
    )

    assert result.quick_scan.value == "supported"
    assert result.health_scan.value == "unsupported"
    assert result.profile_id is None


def test_unknown_adapter_disables_all_scans(
    vpic_values: dict[str, Any],
    decode_payload: dict[str, Any],
) -> None:
    decode_payload["adapter"]["model"] = "another-adapter"
    request = VehicleDecodeRequest.model_validate(decode_payload)
    candidate = VehicleIdentificationService._candidate(request, vpic_values)

    result = DiagnosticProfileRegistry.from_package().resolve(
        candidate, request.obd_identity, request.adapter
    )

    assert result.quick_scan.value == "unsupported"
    assert result.health_scan.value == "unsupported"


def test_quick_scan_is_limited_without_mode_01(
    vpic_values: dict[str, Any],
    decode_payload: dict[str, Any],
) -> None:
    decode_payload["obd_identity"]["supported_modes"] = [3, 7, 9]
    request = VehicleDecodeRequest.model_validate(decode_payload)
    candidate = VehicleIdentificationService._candidate(request, vpic_values)

    result = DiagnosticProfileRegistry.from_package().resolve(
        candidate, request.obd_identity, request.adapter
    )

    assert result.quick_scan.value == "limited"
    assert result.health_scan.value == "unsupported"
    assert result.collection_plan is None
    assert result.rule_set is None
