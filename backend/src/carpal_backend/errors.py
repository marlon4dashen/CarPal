from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class ServiceError(Exception):
    code: str
    message: str
    status_code: int
    retryable: bool = False
    details: list[dict[str, Any]] = field(default_factory=list)


class DependencyUnavailableError(ServiceError):
    def __init__(self) -> None:
        super().__init__(
            code="VIN_PROVIDER_UNAVAILABLE",
            message="Vehicle identification is temporarily unavailable.",
            status_code=503,
            retryable=True,
        )


class DependencyResponseError(ServiceError):
    def __init__(self) -> None:
        super().__init__(
            code="VIN_PROVIDER_INVALID_RESPONSE",
            message="The vehicle identification provider returned an invalid response.",
            status_code=502,
            retryable=True,
        )
