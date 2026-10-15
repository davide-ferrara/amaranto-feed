# RGN News backend

Small read-only FastAPI service for LND Serie D, Girone I data. It fetches and parses LND server-side, stores standings and visited matchdays in SQLite, then exposes JSON to the Flutter app. SQLite and the HTTP client use Python's standard library.

## Run locally

Requires Python 3.11+ and [uv](https://docs.astral.sh/uv/).

```sh
cd backend
uv sync
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The database defaults to `backend/data/rgn_news.sqlite3`. Set `RGN_DB_PATH` to move it. Cache lifetime is six hours. Visiting a different round fetches that round once and stores it locally.

LND's registered club names are presented through the manually maintained `team_aliases` SQLite table. The backend seeds it with aliases for the 18 Girone I clubs and applies them to standings and fixtures; existing cached names are migrated at startup. Update the initial mapping in `app/lnd.py` when the league membership or preferred display names change.

## Endpoints

- `GET /api/health`
- `GET /api/standings`
- `GET /api/calendar` — current LND matchday
- `GET /api/calendar?round_number=8&leg=first`
- `GET /api/overview` — standings and current matchday in one response
- `GET /api/overview?round_number=8&leg=first`

Append `&refresh=true` to bypass the server cache manually. Interactive API docs are at `/docs`.

## Flutter client

For the Android emulator, the default client URL is `http://10.0.2.2:8000`; run the API on the host with `--host 0.0.0.0`. Android cleartext HTTP is enabled only by the debug manifest. Set the production API origin at build time, for example:

```sh
flutter build appbundle --dart-define=RGN_API_BASE_URL=https://api.example.it
```

Use HTTPS for a deployed service. The backend has no authentication because the endpoints contain public sports data; keep database and server access limited to the host.

## Tests

```sh
uv run python -m unittest discover -s tests -v
```
