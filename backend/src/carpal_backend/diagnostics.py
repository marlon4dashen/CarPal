from __future__ import annotations

import re

from carpal_backend.contracts import (
    DiagnosticCodeState,
    ParsedDiagnosticCode,
    ReadinessIgnitionType,
    ReadinessMonitorResult,
    ReadinessParseResponse,
    TroubleCodeParseResponse,
)
from carpal_backend.dtc_catalog import DTCCatalog, packaged_dtc_catalog
from carpal_backend.errors import DiagnosticDataUnavailableError, DiagnosticResponseError

_TOKEN_SPLITTER = re.compile(r"[\s:]+")


def parse_trouble_codes(
    confirmed: str,
    pending: str,
    permanent: str,
    catalog: DTCCatalog | None = None,
) -> TroubleCodeParseResponse:
    """Parse Mode 03/07/0A responses into normalized, catalog-enriched DTCs.

    Each request mode has a distinct positive response byte: 0x43 for confirmed,
    0x47 for pending, and 0x4A for permanent codes. Every subsequent two-byte
    value encodes the P/C/B/U family and four hexadecimal digits of one DTC.
    Codes are deduplicated within an evidence state, then enriched from the
    versioned catalog; valid unknown codes retain their value and use the
    catalog fallback summary. ``NO DATA`` means that state contains no codes,
    while a non-empty response without its expected mode is treated as malformed.
    """
    active_catalog = catalog or packaged_dtc_catalog()
    definitions = (
        (DiagnosticCodeState.CONFIRMED, confirmed, 0x43),
        (DiagnosticCodeState.PENDING, pending, 0x47),
        (DiagnosticCodeState.PERMANENT, permanent, 0x4A),
    )
    codes: list[ParsedDiagnosticCode] = []
    for state, response, response_mode in definitions:
        for code in _parse_dtc_response(response, response_mode):
            codes.append(
                ParsedDiagnosticCode(
                    code=code,
                    summary=active_catalog.summary(code),
                    state=state,
                )
            )
    return TroubleCodeParseResponse(catalog_version=active_catalog.version, codes=codes)


def parse_readiness(response: str) -> ReadinessParseResponse:
    """Decode the first valid Mode 01 PID 01 emissions-readiness payload.

    The four data bytes report MIL state and confirmed-DTC count, availability
    and completion of the three continuous monitors, ignition type, and the
    availability/completion bitmaps for spark- or compression-specific monitors.
    Unsupported monitors are omitted; supported monitors are returned as either
    complete or not ready. ``NO DATA`` is a supported-capability failure, while
    a missing or truncated 0x41/0x01 payload is a malformed vehicle response.
    """
    if _is_no_data(response):
        raise DiagnosticDataUnavailableError
    payloads = _mode_pid_payloads(response, response_mode=0x41, pid=0x01)
    if not payloads or len(payloads[0]) < 4:
        raise DiagnosticResponseError

    status, common, supported_specific, incomplete_specific = payloads[0][:4]
    ignition_type = (
        ReadinessIgnitionType.SPARK if common & 0x08 == 0 else ReadinessIgnitionType.COMPRESSION
    )
    monitors: list[ReadinessMonitorResult] = []
    common_definitions = (
        ("misfire", "Misfire", 0x80, 0x04),
        ("fuelSystem", "Fuel system", 0x40, 0x02),
        ("components", "Comprehensive components", 0x20, 0x01),
    )
    for monitor_id, name, supported_mask, incomplete_mask in common_definitions:
        if common & supported_mask:
            monitors.append(
                ReadinessMonitorResult(
                    id=monitor_id,
                    name=name,
                    is_complete=common & incomplete_mask == 0,
                )
            )

    specific_definitions: tuple[tuple[str, str, int], ...]
    if ignition_type is ReadinessIgnitionType.SPARK:
        specific_definitions = (
            ("catalyst", "Catalyst", 0x80),
            ("heatedCatalyst", "Heated catalyst", 0x40),
            ("evaporativeSystem", "Evaporative system", 0x20),
            ("secondaryAir", "Secondary air system", 0x10),
            ("airConditioning", "A/C refrigerant", 0x08),
            ("oxygenSensor", "Oxygen sensor", 0x04),
            ("oxygenSensorHeater", "Oxygen sensor heater", 0x02),
            ("egrSystem", "EGR system", 0x01),
        )
    else:
        specific_definitions = (
            ("nmhcCatalyst", "NMHC catalyst", 0x80),
            ("noxScr", "NOx/SCR system", 0x40),
            ("boostPressure", "Boost pressure", 0x10),
            ("exhaustGasSensor", "Exhaust gas sensor", 0x04),
            ("particulateMatterFilter", "Particulate matter filter", 0x02),
            ("egrVvtSystem", "EGR/VVT system", 0x01),
        )
    for monitor_id, name, mask in specific_definitions:
        if supported_specific & mask:
            monitors.append(
                ReadinessMonitorResult(
                    id=monitor_id,
                    name=name,
                    is_complete=incomplete_specific & mask == 0,
                )
            )

    return ReadinessParseResponse(
        is_mil_on=status & 0x80 != 0,
        confirmed_dtc_count=status & 0x7F,
        ignition_type=ignition_type,
        monitors=monitors,
    )


def _parse_dtc_response(response: str, response_mode: int) -> list[str]:
    if _is_no_data(response):
        return []
    payloads = _mode_pid_payloads(response, response_mode=response_mode)
    if not payloads:
        raise DiagnosticResponseError

    codes: list[str] = []
    for payload in payloads:
        for index in range(0, len(payload) - 1, 2):
            high = payload[index]
            low = payload[index + 1]
            if high == 0 and low == 0:
                break
            family = ("P", "C", "B", "U")[high >> 6]
            value = ((high & 0x3F) << 8) | low
            code = f"{family}{value:04X}"
            if code not in codes:
                codes.append(code)
    return codes


def _mode_pid_payloads(
    response: str,
    response_mode: int,
    pid: int | None = None,
) -> list[list[int]]:
    payloads: list[list[int]] = []
    for line in response.splitlines():
        values = _bytes_in_line(line)
        for index, value in enumerate(values):
            if value != response_mode:
                continue
            if pid is not None and (index + 1 >= len(values) or values[index + 1] != pid):
                continue
            payload_start = index + (2 if pid is not None else 1)
            payloads.append(values[payload_start:])
            break
    return payloads


def _bytes_in_line(line: str) -> list[int]:
    values: list[int] = []
    for token in _TOKEN_SPLITTER.split(line.strip()):
        if not token or any(character not in "0123456789abcdefABCDEF" for character in token):
            continue
        if len(token) == 2:
            values.append(int(token, 16))
        elif len(token) > 2 and len(token) % 2 == 0:
            values.extend(int(token[index : index + 2], 16) for index in range(0, len(token), 2))
        elif len(token) > 3:
            payload = token[3:]
            if len(payload) % 2 == 0:
                values.extend(
                    int(payload[index : index + 2], 16) for index in range(0, len(payload), 2)
                )
    return values


def _is_no_data(response: str) -> bool:
    return "NO DATA" in response.upper()
