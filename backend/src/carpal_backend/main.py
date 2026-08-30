from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import APIRouter, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.middleware.base import RequestResponseEndpoint
from starlette.responses import Response

from carpal_backend import __version__
from carpal_backend.contracts import (
    DiagnosticProfileResolveRequest,
    DiagnosticProfileResolveResponse,
    ErrorBody,
    ErrorDetail,
    ErrorResponse,
    HealthResponse,
    VehicleDecodeRequest,
    VehicleDecodeResponse,
)
from carpal_backend.errors import ServiceError
from carpal_backend.profiles import DiagnosticProfileRegistry
from carpal_backend.vehicle_identification import VehicleIdentificationService
from carpal_backend.vpic import VINDecodeProvider, VPICConfig, VPICProvider

logger = logging.getLogger("carpal_backend")


def create_app(provider: VINDecodeProvider | None = None) -> FastAPI:
    # vPIC requires VIN in the URL path, so dependency request logging must stay disabled.
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    registry = DiagnosticProfileRegistry.from_package()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        client: httpx.AsyncClient | None = None
        active_provider = provider
        if active_provider is None:
            config = VPICConfig()
            client = httpx.AsyncClient(
                base_url=config.base_url,
                timeout=httpx.Timeout(connect=2, read=5, write=5, pool=2),
                follow_redirects=False,
                headers={"User-Agent": f"CarPal/{__version__}"},
            )
            active_provider = VPICProvider(client=client, config=config)
        app.state.vehicle_identification = VehicleIdentificationService(
            provider=active_provider,
            registry=registry,
        )
        try:
            yield
        finally:
            if client is not None:
                await client.aclose()

    app = FastAPI(
        title="CarPal Backend",
        version=__version__,
        lifespan=lifespan,
    )
    app.include_router(_router())
    _register_error_handlers(app)
    _register_request_logging(app)
    return app


def _router() -> APIRouter:
    router = APIRouter()

    @router.get("/health", response_model=HealthResponse, tags=["operations"])
    async def health() -> HealthResponse:
        return HealthResponse(version=__version__)

    @router.post(
        "/v1/vehicle-identification/decode",
        response_model=VehicleDecodeResponse,
        responses={502: {"model": ErrorResponse}, 503: {"model": ErrorResponse}},
        tags=["vehicle-identification"],
    )
    async def decode_vehicle(
        payload: VehicleDecodeRequest,
        request: Request,
    ) -> VehicleDecodeResponse:
        service: VehicleIdentificationService = request.app.state.vehicle_identification
        return await service.decode(payload)

    @router.post(
        "/v1/diagnostic-profiles/resolve",
        response_model=DiagnosticProfileResolveResponse,
        tags=["diagnostic-profiles"],
    )
    async def resolve_profile(
        payload: DiagnosticProfileResolveRequest,
        request: Request,
    ) -> DiagnosticProfileResolveResponse:
        service: VehicleIdentificationService = request.app.state.vehicle_identification
        return service.resolve(payload)

    return router


def _register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ServiceError)
    async def service_error_handler(_: Request, error: ServiceError) -> JSONResponse:
        payload = ErrorResponse(
            error=ErrorBody(
                code=error.code,
                message=error.message,
                retryable=error.retryable,
                details=[ErrorDetail.model_validate(detail) for detail in error.details],
            )
        )
        return JSONResponse(status_code=error.status_code, content=payload.model_dump(mode="json"))

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        _: Request,
        error: RequestValidationError,
    ) -> JSONResponse:
        details = [
            ErrorDetail(
                location=list(item.get("loc", ())),
                message=str(item.get("msg", "Invalid value")),
                type=str(item.get("type", "validation_error")),
            )
            for item in error.errors()
        ]
        payload = ErrorResponse(
            error=ErrorBody(
                code="REQUEST_INVALID",
                message="The request did not match the API contract.",
                retryable=False,
                details=details,
            )
        )
        return JSONResponse(status_code=422, content=payload.model_dump(mode="json"))


def _register_request_logging(app: FastAPI) -> None:
    @app.middleware("http")
    async def log_request(
        request: Request,
        call_next: RequestResponseEndpoint,
    ) -> Response:
        response = await call_next(request)
        logger.info(
            "request method=%s path=%s status=%s",
            request.method,
            request.url.path,
            response.status_code,
        )
        return response


app = create_app()
