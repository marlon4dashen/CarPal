from __future__ import annotations

import asyncio
from typing import Any

import httpx
from conftest import SYNTHETIC_VIN, FakeVINProvider

from carpal_backend.main import create_app
from carpal_backend.vpic import VINProviderUnavailableError


def test_health() -> None:
    response = _request(FakeVINProvider({}), "GET", "/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_decode_normalizes_identity_and_resolves_profile(
    vpic_values: dict[str, Any],
    decode_payload: dict[str, Any],
) -> None:
    provider = FakeVINProvider(vpic_values)
    response = _request(
        provider,
        "POST",
        "/v1/vehicle-identification/decode",
        decode_payload,
    )

    assert response.status_code == 200
    body = response.json()
    assert provider.calls == [(SYNTHETIC_VIN, 2020)]
    assert body["candidate"]["model"] == {
        "value": "NX 300",
        "source": "VIN_DECODER",
        "requires_confirmation": False,
    }
    assert body["candidate"]["vin"]["source"] == "OBD"
    assert body["candidate"]["model_year"]["source"] == "USER"
    assert body["eligibility"]["profile_id"] == "lexus-nx300-2020-na"
    assert body["eligibility"]["health_scan"] == "supported"


def test_partial_decode_preserves_unknown_values(
    decode_payload: dict[str, Any],
) -> None:
    values = {"VIN": SYNTHETIC_VIN, "ModelYear": "2020", "Make": "LEXUS"}
    response = _request(
        FakeVINProvider(values),
        "POST",
        "/v1/vehicle-identification/decode",
        decode_payload,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["candidate"]["model"]["value"] is None
    assert body["candidate"]["model"]["requires_confirmation"] is True
    assert body["eligibility"]["health_scan"] == "unsupported"
    assert any("requires confirmation" in warning for warning in body["decode_warnings"])


def test_invalid_request_does_not_echo_vin(decode_payload: dict[str, Any]) -> None:
    invalid_vin = "INVALID-VIN-SECRET"
    decode_payload["vin"] = invalid_vin
    response = _request(
        FakeVINProvider({}),
        "POST",
        "/v1/vehicle-identification/decode",
        decode_payload,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "REQUEST_INVALID"
    assert invalid_vin not in response.text


def test_provider_unavailable_returns_retryable_error(
    decode_payload: dict[str, Any],
) -> None:
    class UnavailableProvider:
        async def decode(self, vin: str, model_year: int) -> Any:
            raise VINProviderUnavailableError

    response = _request(
        UnavailableProvider(),
        "POST",
        "/v1/vehicle-identification/decode",
        decode_payload,
    )

    assert response.status_code == 503
    assert response.json()["error"] == {
        "code": "VIN_PROVIDER_UNAVAILABLE",
        "message": "Vehicle identification is temporarily unavailable.",
        "retryable": True,
        "details": [],
    }
    assert SYNTHETIC_VIN not in response.text


def test_profile_can_be_resolved_after_user_correction(
    vpic_values: dict[str, Any],
    decode_payload: dict[str, Any],
) -> None:
    provider = FakeVINProvider(vpic_values)
    decoded = _request(
        provider,
        "POST",
        "/v1/vehicle-identification/decode",
        decode_payload,
    ).json()
    decoded["candidate"]["engine_model"] = {
        "value": "8AR-FTS",
        "source": "USER",
        "requires_confirmation": False,
    }
    response = _request(
        provider,
        "POST",
        "/v1/diagnostic-profiles/resolve",
        {
            "schema_version": "1",
            "identity": decoded["candidate"],
            "obd_identity": decode_payload["obd_identity"],
            "adapter": decode_payload["adapter"],
        },
    )

    assert response.status_code == 200
    assert response.json()["eligibility"]["health_scan"] == "supported"


def _request(
    provider: Any,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
) -> httpx.Response:
    async def run() -> httpx.Response:
        app = create_app(provider)
        async with app.router.lifespan_context(app):
            transport = httpx.ASGITransport(app=app, raise_app_exceptions=False)
            async with httpx.AsyncClient(
                transport=transport,
                base_url="https://carpal.test",
            ) as client:
                return await client.request(method, path, json=payload)

    return asyncio.run(run())
