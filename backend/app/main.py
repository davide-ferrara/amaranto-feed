from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel

from .lnd import LndError, LndRepository


class Standing(BaseModel):
    position: int
    team: str
    logo_url: str | None = None
    played: int
    wins: int
    draws: int
    losses: int
    goal_difference: int
    points: int


class Fixture(BaseModel):
    id: str
    matchday: str
    round_number: int
    leg: Literal["first", "second"]
    date: str
    time: str
    venue: str
    address: str
    home_team: str
    home_logo_url: str | None = None
    away_team: str
    away_logo_url: str | None = None
    home_score: int | None = None
    away_score: int | None = None


class StandingsResponse(BaseModel):
    updated_at: datetime | None
    source: str
    standings: list[Standing]


class CalendarResponse(BaseModel):
    updated_at: datetime | None
    source: str
    matchday: dict[str, Any]
    fixtures: list[Fixture]


class OverviewResponse(CalendarResponse):
    standings: list[Standing]


app = FastAPI(
    title="RGN News API",
    version="0.1.0",
    description="Read-only Serie D Girone I standings and fixtures sourced from LND.",
)
repository = LndRepository()


def _service_call(operation):
    try:
        return operation()
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except LndError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/api/health", tags=["service"])
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/standings", response_model=StandingsResponse, tags=["Serie D"])
def standings(refresh: bool = False) -> dict[str, Any]:
    return _service_call(lambda: repository.get_standings(force_refresh=refresh))


@app.get("/api/calendar", response_model=CalendarResponse, tags=["Serie D"])
def calendar(
    round_number: int | None = Query(default=None, ge=1, le=17),
    leg: Literal["first", "second"] | None = None,
    refresh: bool = False,
) -> dict[str, Any]:
    if (round_number is None) != (leg is None):
        raise HTTPException(status_code=422, detail="round_number e leg vanno specificati insieme")
    return _service_call(lambda: repository.get_calendar(round_number, leg, refresh))


@app.get("/api/overview", response_model=OverviewResponse, tags=["Serie D"])
def overview(
    round_number: int | None = Query(default=None, ge=1, le=17),
    leg: Literal["first", "second"] | None = None,
    refresh: bool = False,
) -> dict[str, Any]:
    if (round_number is None) != (leg is None):
        raise HTTPException(status_code=422, detail="round_number e leg vanno specificati insieme")
    return _service_call(lambda: repository.get_overview(round_number, leg, refresh))
