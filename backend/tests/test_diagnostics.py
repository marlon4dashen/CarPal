from __future__ import annotations

import pytest

from carpal_backend.contracts import DiagnosticCodeState, ReadinessIgnitionType
from carpal_backend.diagnostics import parse_readiness, parse_trouble_codes
from carpal_backend.errors import DiagnosticDataUnavailableError, DiagnosticResponseError


def test_parses_all_trouble_code_states_and_deduplicates_ecus() -> None:
    result = parse_trouble_codes(
        confirmed="7E8 04 43 01 71 00 00\n7E9 04 43 01 71 00 00",
        pending="47 03 00",
        permanent="4A 04 20",
    )

    assert [(item.code, item.state) for item in result.codes] == [
        ("P0171", DiagnosticCodeState.CONFIRMED),
        ("P0300", DiagnosticCodeState.PENDING),
        ("P0420", DiagnosticCodeState.PERMANENT),
    ]
    assert result.codes[0].summary == "System too lean (bank 1)"
    assert result.catalog_version == "1.0.0"


def test_unknown_dtc_uses_catalog_fallback_without_losing_code() -> None:
    result = parse_trouble_codes(
        confirmed="43 12 34",
        pending="NO DATA",
        permanent="NO DATA",
    )

    assert result.codes[0].code == "P1234"
    assert result.codes[0].summary == "Vehicle-reported diagnostic trouble code"


def test_no_data_is_a_valid_empty_trouble_code_state() -> None:
    result = parse_trouble_codes(
        confirmed="43 00 00",
        pending="NO DATA",
        permanent="NO DATA",
    )

    assert result.codes == []


def test_malformed_trouble_code_response_is_rejected() -> None:
    with pytest.raises(DiagnosticResponseError):
        parse_trouble_codes(confirmed="OK", pending="NO DATA", permanent="NO DATA")


def test_parses_spark_readiness_and_monitor_completion() -> None:
    result = parse_readiness("41 01 81 E0 A5 20")

    assert result.is_mil_on is True
    assert result.confirmed_dtc_count == 1
    assert result.ignition_type is ReadinessIgnitionType.SPARK
    assert len(result.monitors) == 7
    assert sum(monitor.is_complete for monitor in result.monitors) == 6
    evaporative = next(item for item in result.monitors if item.id == "evaporativeSystem")
    assert evaporative.is_complete is False


def test_readiness_no_data_is_reported_as_unavailable() -> None:
    with pytest.raises(DiagnosticDataUnavailableError):
        parse_readiness("NO DATA")
