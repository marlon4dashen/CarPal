from __future__ import annotations

import asyncio
import random
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any, Protocol

import httpx


@dataclass(frozen=True, slots=True)
class VINDecodeResult:
    values: dict[str, Any]
    warnings: tuple[str, ...] = field(default_factory=tuple)


class VINDecodeProvider(Protocol):
    async def decode(self, vin: str, model_year: int) -> VINDecodeResult: ...


class VINProviderUnavailableError(Exception):
    pass


class VINProviderResponseError(Exception):
    pass


@dataclass(frozen=True, slots=True)
class VPICConfig:
    base_url: str = "https://vpic.nhtsa.dot.gov/api"
    attempts: int = 3
    retry_backoff_seconds: float = 0.2


class VPICProvider:
    _RETRYABLE_STATUS_CODES = frozenset({408, 429, 500, 502, 503, 504})

    def __init__(
        self,
        client: httpx.AsyncClient,
        config: VPICConfig | None = None,
        sleeper: Callable[[float], Awaitable[None]] = asyncio.sleep,
        jitter: Callable[[], float] = random.random,
    ) -> None:
        self._client = client
        self._config = config or VPICConfig()
        self._sleeper = sleeper
        self._jitter = jitter

    async def decode(self, vin: str, model_year: int) -> VINDecodeResult:
        path = f"/vehicles/DecodeVinValuesExtended/{vin}"
        for attempt in range(self._config.attempts):
            try:
                response = await self._client.get(
                    path,
                    params={"format": "json", "modelyear": model_year},
                )
                if response.status_code in self._RETRYABLE_STATUS_CODES:
                    raise VINProviderUnavailableError
                response.raise_for_status()
                return self._parse_response(response)
            except (httpx.TimeoutException, httpx.NetworkError, VINProviderUnavailableError):
                if attempt + 1 >= self._config.attempts:
                    raise VINProviderUnavailableError from None
                jitter_factor = 0.75 + (0.5 * self._jitter())
                await self._sleeper(
                    self._config.retry_backoff_seconds * (2**attempt) * jitter_factor
                )
            except (httpx.HTTPStatusError, ValueError, TypeError, KeyError):
                raise VINProviderResponseError from None
        raise VINProviderUnavailableError

    @staticmethod
    def _parse_response(response: httpx.Response) -> VINDecodeResult:
        payload = response.json()
        if not isinstance(payload, dict):
            raise VINProviderResponseError
        results = payload.get("Results")
        if not isinstance(results, list) or not results or not isinstance(results[0], dict):
            raise VINProviderResponseError

        values = {str(key): value for key, value in results[0].items()}
        warnings: list[str] = []
        error_code = _clean_value(values.get("ErrorCode"))
        error_text = _clean_value(values.get("ErrorText"))
        if error_code and error_code != "0" and error_text:
            warnings.append(error_text)
        return VINDecodeResult(values=values, warnings=tuple(warnings))


def _clean_value(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
