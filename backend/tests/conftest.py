from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from carpal_backend.vpic import VINDecodeResult

SYNTHETIC_VIN = "JTJYARBZ0L2000001"


class FakeVINProvider:
    def __init__(self, values: dict[str, Any], warnings: tuple[str, ...] = ()) -> None:
        self.values = values
        self.warnings = warnings
        self.calls: list[tuple[str, int]] = []

    async def decode(self, vin: str, model_year: int) -> VINDecodeResult:
        self.calls.append((vin, model_year))
        return VINDecodeResult(values=self.values, warnings=self.warnings)


@pytest.fixture
def vpic_values() -> dict[str, Any]:
    path = Path(__file__).parent / "fixtures" / "vpic_lexus_nx300_2020.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    return dict(payload["Results"][0])


@pytest.fixture
def decode_payload() -> dict[str, Any]:
    return {
        "schema_version": "1",
        "vin": SYNTHETIC_VIN,
        "model_year": 2020,
        "obd_identity": {
            "calibration_ids": ["CAL-NX300-TEST"],
            "ecu_names": ["ECM"],
            "supported_modes": [1, 3, 7, 9],
        },
        "adapter": {
            "model": "veepeak-obdcheck-ble",
            "protocol": "ISO 15765-4 CAN",
            "market": "CA",
        },
    }
