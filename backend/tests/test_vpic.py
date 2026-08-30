from __future__ import annotations

import asyncio

import httpx
import pytest
from conftest import SYNTHETIC_VIN

from carpal_backend.vpic import (
    VINProviderResponseError,
    VINProviderUnavailableError,
    VPICConfig,
    VPICProvider,
)


def test_vpic_sends_model_year_and_parses_first_result() -> None:
    async def run() -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            assert SYNTHETIC_VIN in request.url.path
            assert request.url.params["format"] == "json"
            assert request.url.params["modelyear"] == "2020"
            return httpx.Response(
                200,
                json={"Results": [{"VIN": SYNTHETIC_VIN, "Make": "LEXUS"}]},
            )

        async with httpx.AsyncClient(
            base_url="https://example.test",
            transport=httpx.MockTransport(handler),
        ) as client:
            result = await VPICProvider(client).decode(SYNTHETIC_VIN, 2020)
        assert result.values["Make"] == "LEXUS"

    asyncio.run(run())


def test_vpic_retries_only_bounded_retryable_failures() -> None:
    async def run() -> None:
        attempts = 0
        delays: list[float] = []

        def handler(_: httpx.Request) -> httpx.Response:
            nonlocal attempts
            attempts += 1
            return httpx.Response(503)

        async def sleeper(delay: float) -> None:
            delays.append(delay)

        async with httpx.AsyncClient(
            base_url="https://example.test",
            transport=httpx.MockTransport(handler),
        ) as client:
            provider = VPICProvider(
                client,
                config=VPICConfig(attempts=3, retry_backoff_seconds=0.1),
                sleeper=sleeper,
                jitter=lambda: 0.5,
            )
            with pytest.raises(VINProviderUnavailableError):
                await provider.decode(SYNTHETIC_VIN, 2020)
        assert attempts == 3
        assert delays == [0.1, 0.2]

    asyncio.run(run())


def test_vpic_rejects_malformed_payload_without_retry() -> None:
    async def run() -> None:
        attempts = 0

        def handler(_: httpx.Request) -> httpx.Response:
            nonlocal attempts
            attempts += 1
            return httpx.Response(200, json={"Results": []})

        async with httpx.AsyncClient(
            base_url="https://example.test",
            transport=httpx.MockTransport(handler),
        ) as client:
            with pytest.raises(VINProviderResponseError):
                await VPICProvider(client).decode(SYNTHETIC_VIN, 2020)
        assert attempts == 1

    asyncio.run(run())


def test_vpic_rejects_non_object_payload() -> None:
    async def run() -> None:
        def handler(_: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json=[])

        async with httpx.AsyncClient(
            base_url="https://example.test",
            transport=httpx.MockTransport(handler),
        ) as client:
            with pytest.raises(VINProviderResponseError):
                await VPICProvider(client).decode(SYNTHETIC_VIN, 2020)

    asyncio.run(run())
