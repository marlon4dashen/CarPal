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


class DiagnosticResponseError(ServiceError):
    def __init__(
        self,
        message: str = "The vehicle returned diagnostic data that could not be parsed.",
    ) -> None:
        super().__init__(
            code="DIAGNOSTIC_RESPONSE_INVALID",
            message=message,
            status_code=422,
            retryable=True,
        )


class DiagnosticDataUnavailableError(ServiceError):
    def __init__(self) -> None:
        super().__init__(
            code="DIAGNOSTIC_DATA_UNAVAILABLE",
            message="The vehicle did not report data for this diagnostic capability.",
            status_code=422,
            retryable=True,
        )
