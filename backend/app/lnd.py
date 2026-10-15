from __future__ import annotations

import json
import os
import sqlite3
import urllib.error
import urllib.parse
import urllib.request
from contextlib import closing, contextmanager
from datetime import UTC, datetime, timedelta
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterator


SOURCE = "https://gare.lnd.it/competizione/dipartimento-interregionale/"
CACHE_TTL = timedelta(hours=6)
DEFAULT_DB = Path(__file__).resolve().parents[1] / "data" / "rgn_news.sqlite3"

# LND publishes registered company names. Keep the public-facing names here,
# one explicit alias per club (with known spelling variants as extra keys).
TEAM_ALIASES = {
    "athletic club palermo": "Athletic Club Palermo",
    "athletic club palermo ssdarl": "Athletic Club Palermo",
    "calcio avola 1949": "Calcio Avola 1949",
    "calcio avola 1949 asd": "Calcio Avola 1949",
    "calcio avola 1949 sd": "Calcio Avola 1949",
    "castrumfavara": "CastrumFavara",
    "castrumfavara ssdarl": "CastrumFavara",
    "digiesse praiatortora": "Digiesse PraiaTortora",
    "enna calcio scsd": "Enna",
    "gela": "Gela",
    "gela calcio": "Gela",
    "licata calcio": "Licata",
    "licata calcio ssd": "Licata",
    "milazzo": "Milazzo 1937",
    "milazzo 1937": "Milazzo 1937",
    "milazzo ssd a rl": "Milazzo 1937",
    "modica calcio": "Modica",
    "pol modica calcio": "Modica",
    "nissa fc": "Nissa",
    "nissa fc srl": "Nissa",
    "nuova igea virtus": "Nuova Igea Virtus",
    "nuova igea virtus ssdarl": "Nuova Igea Virtus",
    "ragusa": "Ragusa 1949",
    "ragusa calcio": "Ragusa 1949",
    "ragusa 1949": "Ragusa 1949",
    "regina1914ssdarl": "Reggina 1914",
    "reggina 1914": "Reggina 1914",
    "reggina 1914 ssd a rl": "Reggina 1914",
    "sambiase2023": "Sambiase 2023",
    "sanbiase2023": "Sambiase 2023",
    "sambiase 2023": "Sambiase 2023",
    "siracusa calcio 1924": "Siracusa",
    "trapani": "Trapani 1905",
    "trapani 1905 fc": "Trapani 1905",
    "trapani 1905 fc srl": "Trapani 1905",
    "vibonesecalciosrl": "Vibonese",
    "vibonese calcio srl": "Vibonese",
    "vigor lamezia calcio 1919": "Vigor Lamezia",
    "vigor lamezia calcio 1919 asd": "Vigor Lamezia",
}

# Only replace LND's shared placeholder image. These are rasterized Wikimedia
# thumbnails so Flutter's standard Image.network can render the SVG club marks.
GENERIC_LND_LOGO_PATH = "/lndimg/0/logo-societa-generico.png"
TEAM_LOGO_FALLBACKS = {
    "gela": "https://thumb.wikimedia.org/wikipedia/en/thumb/7/7d/SSD_Citt%C3%A0_di_Gela_logo.svg/250px-SSD_Citt%C3%A0_di_Gela_logo.svg.png",
    "licata": "https://thumb.wikimedia.org/wikipedia/fr/thumb/e/e3/ASD_Licata_Calcio_%28logo%29.svg/250px-ASD_Licata_Calcio_%28logo%29.svg.png",
}


class LndError(RuntimeError):
    pass


def _team_key(name: str) -> str:
    """Normalize case and punctuation only, for exact manual alias matching."""
    return "".join(character for character in name.casefold() if character.isalnum())


def _display_team(name: str, aliases: dict[str, str]) -> str:
    return aliases.get(_team_key(name), name.title())


def _is_played(value: Any) -> bool:
    if value is True or value == 1:
        return True
    return isinstance(value, str) and value.strip().casefold() in {"true", "1", "yes"}


def _score_value(value: Any) -> int | None:
    if value is None or isinstance(value, str) and not value.strip():
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _logo_with_fallback(team: str, logo_url: str | None) -> str | None:
    """Use a club-specific image only when LND supplied its generic badge."""
    if not logo_url:
        return logo_url
    path = urllib.parse.urlparse(logo_url).path.casefold()
    if path.endswith(GENERIC_LND_LOGO_PATH):
        return TEAM_LOGO_FALLBACKS.get(_team_key(team), logo_url)
    return logo_url


class _InertiaPageParser(HTMLParser):
    """Extract the JSON page payload embedded by the LND Inertia app."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._inside_payload = False
        self._parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "script":
            attributes = dict(attrs)
            self._inside_payload = (
                attributes.get("data-page") == "app"
                and attributes.get("type") == "application/json"
            )

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self._inside_payload:
            self._inside_payload = False

    def handle_data(self, data: str) -> None:
        if self._inside_payload:
            self._parts.append(data)

    def payload(self) -> dict[str, Any] | None:
        if not self._parts:
            return None
        value = json.loads("".join(self._parts))
        return value if isinstance(value, dict) else None


def season_for(today: datetime | None = None) -> int:
    current = today or datetime.now(UTC)
    # Serie D seasons begin in late summer; a calendar-year season key is used
    # from July onward, and the previous year during the spring/summer break.
    return current.year if current.month >= 7 else current.year - 1


def parse_lnd_response(body: bytes | str) -> dict[str, Any]:
    text = body.decode("utf-8", errors="replace") if isinstance(body, bytes) else body
    stripped = text.lstrip()
    if stripped.startswith("{"):
        page = json.loads(stripped)
    else:
        parser = _InertiaPageParser()
        parser.feed(text)
        page = parser.payload()
    if not isinstance(page, dict) or not isinstance(page.get("props"), dict):
        raise LndError("La risposta LND non contiene il payload dati atteso")
    props = page["props"]
    if not isinstance(props.get("standings"), list) or not isinstance(props.get("matches"), list):
        raise LndError("La risposta LND non include classifica e calendario")
    current = props.get("currentMatchday")
    if not isinstance(current, dict) or current.get("leg") not in {"first", "second"}:
        raise LndError("La giornata corrente LND non è disponibile")
    try:
        number = int(current["number"])
    except (KeyError, TypeError, ValueError) as exc:
        raise LndError("Numero giornata LND non valido") from exc
    return {"props": props, "round_number": number, "leg": current["leg"]}


def _normalize(
    payload: dict[str, Any], aliases: dict[str, str] | None = None
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], int, str]:
    props = payload["props"]
    alias_map = {
        _team_key(source): display for source, display in (aliases or TEAM_ALIASES).items()
    }
    standings: list[dict[str, Any]] = []
    for item in props["standings"]:
        if not isinstance(item, dict):
            continue
        try:
            goals_for = int(item.get("goalsFor") or 0)
            goals_against = int(item.get("goalsAgainst") or 0)
            row = {
                "position": int(item["position"]),
                "team": _display_team(str(item.get("team") or ""), alias_map),
                "logo_url": item.get("logo"),
                "played": int(item.get("played") or 0),
                "wins": int(item.get("wins") or 0),
                "draws": int(item.get("draws") or 0),
                "losses": int(item.get("losses") or 0),
                "goal_difference": goals_for - goals_against,
                "points": int(item.get("points") or 0),
            }
        except (KeyError, TypeError, ValueError):
            continue
        if row["team"]:
            standings.append(row)

    number, leg = payload["round_number"], payload["leg"]
    fixtures: list[dict[str, Any]] = []
    for item in props["matches"]:
        if not isinstance(item, dict) or item.get("isRest"):
            continue
        home, away = str(item.get("home") or ""), str(item.get("away") or "")
        if not home or not away:
            continue
        try:
            match_id = str(item["id"])
        except KeyError:
            match_id = f"{number}-{len(fixtures)}-{home}-{away}"
        played = _is_played(item.get("isPlayed"))
        home_score = _score_value(item.get("homeGoals"))
        away_score = _score_value(item.get("awayGoals"))
        fixtures.append(
            {
                "id": match_id,
                "matchday": f"{leg}:{number}",
                "round_number": number,
                "leg": leg,
                "date": str(item.get("date") or ""),
                "time": str(item.get("time") or "")[:5],
                "venue": str(item.get("field") or ""),
                "address": str(item.get("fieldAddress") or ""),
                "home_team": _display_team(home, alias_map),
                "home_logo_url": item.get("homeLogo"),
                "away_team": _display_team(away, alias_map),
                "away_logo_url": item.get("awayLogo"),
                "home_score": home_score if played else None,
                "away_score": away_score if played else None,
            }
        )
    if len(standings) < 10 or not fixtures:
        raise LndError("La risposta LND contiene dati incompleti")
    return standings, fixtures, number, leg


class LndRepository:
    def __init__(self, db_path: str | Path | None = None, ttl: timedelta = CACHE_TTL) -> None:
        self.db_path = Path(db_path or os.environ.get("RGN_DB_PATH", DEFAULT_DB))
        self.ttl = ttl
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path, timeout=15)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA busy_timeout = 15000")
        return connection

    @contextmanager
    def _session(self) -> Iterator[sqlite3.Connection]:
        connection = self._connect()
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    def _initialize(self) -> None:
        with self._session() as db:
            db.executescript(
                """
                PRAGMA journal_mode = WAL;
                CREATE TABLE IF NOT EXISTS standings (
                    position INTEGER PRIMARY KEY, team TEXT NOT NULL, logo_url TEXT,
                    played INTEGER NOT NULL, wins INTEGER NOT NULL, draws INTEGER NOT NULL,
                    losses INTEGER NOT NULL, goal_difference INTEGER NOT NULL,
                    points INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS fixtures (
                    id TEXT PRIMARY KEY, matchday TEXT NOT NULL, round_number INTEGER NOT NULL,
                    leg TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL,
                    venue TEXT NOT NULL, address TEXT NOT NULL, home_team TEXT NOT NULL,
                    home_logo_url TEXT, away_team TEXT NOT NULL, away_logo_url TEXT,
                    home_score INTEGER, away_score INTEGER
                );
                CREATE INDEX IF NOT EXISTS fixtures_round_idx ON fixtures(leg, round_number);
                CREATE TABLE IF NOT EXISTS cache_meta (
                    key TEXT PRIMARY KEY, value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS team_aliases (
                    source_key TEXT PRIMARY KEY, display_name TEXT NOT NULL
                );
                """
            )
            db.executemany(
                "INSERT OR IGNORE INTO team_aliases(source_key, display_name) VALUES (?, ?)",
                [(_team_key(source), display) for source, display in TEAM_ALIASES.items()],
            )
            self._migrate_cached_team_names(db)

    def _migrate_cached_team_names(self, db: sqlite3.Connection) -> None:
        aliases = self._read_aliases(db)
        for row in db.execute("SELECT position, team FROM standings").fetchall():
            display = aliases.get(_team_key(row["team"]))
            if display:
                db.execute("UPDATE standings SET team = ? WHERE position = ?", (display, row["position"]))
        for row in db.execute("SELECT id, home_team, away_team FROM fixtures").fetchall():
            home = aliases.get(_team_key(row["home_team"]))
            away = aliases.get(_team_key(row["away_team"]))
            if home or away:
                db.execute(
                    "UPDATE fixtures SET home_team = ?, away_team = ? WHERE id = ?",
                    (home or row["home_team"], away or row["away_team"], row["id"]),
                )

    @staticmethod
    def _read_aliases(db: sqlite3.Connection) -> dict[str, str]:
        return {row["source_key"]: row["display_name"] for row in db.execute("SELECT source_key, display_name FROM team_aliases")}

    def _aliases(self) -> dict[str, str]:
        with closing(self._connect()) as db:
            return self._read_aliases(db)

    def _cache_time(self, key: str) -> datetime | None:
        with self._session() as db:
            row = db.execute("SELECT value FROM cache_meta WHERE key = ?", (key,)).fetchone()
        if row is None:
            return None
        try:
            return datetime.fromisoformat(row["value"])
        except ValueError:
            return None

    def _is_fresh(self, key: str) -> bool:
        timestamp = self._cache_time(key)
        return timestamp is not None and datetime.now(UTC) - timestamp < self.ttl

    def _fetch(self, round_number: int | None = None, leg: str | None = None) -> dict[str, Any]:
        params: dict[str, str] = {
            "campionato": "ID",
            "girone": "I",
            "stagione": str(season_for()),
        }
        if round_number is not None:
            params["giornata"] = str(round_number)
            params["leg"] = str(leg)
        url = f"{SOURCE}?{urllib.parse.urlencode(params)}"
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": "RGN-News/1.0 (public LND competition data)",
                "Accept": "text/html,application/xhtml+xml",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                body = response.read()
        except (urllib.error.URLError, TimeoutError) as exc:
            raise LndError(f"Impossibile leggere la pagina LND: {exc}") from exc
        return parse_lnd_response(body)

    def _save(
        self, payload: dict[str, Any], *, update_latest: bool
    ) -> tuple[int, str, datetime]:
        standings, fixtures, number, leg = _normalize(payload, self._aliases())
        season = int(payload["props"].get("season") or season_for())
        now = datetime.now(UTC)
        stamp = now.isoformat()
        round_key = f"round:{leg}:{number}"
        with self._session() as db:
            cached_season = db.execute("SELECT value FROM cache_meta WHERE key = 'season'").fetchone()
            if cached_season is not None and cached_season["value"] != str(season):
                db.execute("DELETE FROM fixtures")
                db.execute("DELETE FROM cache_meta WHERE key != 'season'")
            db.execute("DELETE FROM standings")
            db.executemany(
                """INSERT OR REPLACE INTO standings
                (position, team, logo_url, played, wins, draws, losses, goal_difference, points)
                VALUES (:position, :team, :logo_url, :played, :wins, :draws, :losses, :goal_difference, :points)""",
                standings,
            )
            db.executemany(
                """INSERT OR REPLACE INTO fixtures
                (id, matchday, round_number, leg, date, time, venue, address,
                 home_team, home_logo_url, away_team, away_logo_url, home_score, away_score)
                VALUES (:id, :matchday, :round_number, :leg, :date, :time, :venue, :address,
                        :home_team, :home_logo_url, :away_team, :away_logo_url, :home_score, :away_score)""",
                fixtures,
            )
            metadata = [("standings", stamp), (round_key, stamp), ("last_updated", stamp), ("season", str(season))]
            if update_latest:
                metadata.append(("latest_round", f"{leg}:{number}"))
            db.executemany("INSERT OR REPLACE INTO cache_meta(key, value) VALUES (?, ?)", metadata)
        return number, leg, now

    def _refresh(self, round_number: int | None = None, leg: str | None = None) -> tuple[int, str, datetime]:
        return self._save(
            self._fetch(round_number, leg), update_latest=round_number is None
        )

    def get_standings(self, force_refresh: bool = False) -> dict[str, Any]:
        if force_refresh or not self._is_fresh("standings"):
            try:
                self._refresh()
            except LndError:
                if not self._read_standings():
                    raise
        return {"updated_at": self._cache_time("standings"), "source": SOURCE, "standings": self._read_standings()}

    def get_calendar(
        self, round_number: int | None = None, leg: str | None = None, force_refresh: bool = False
    ) -> dict[str, Any]:
        latest_request = round_number is None and leg is None
        refresh_failed = False
        if latest_request:
            latest = self._meta("latest_round")
            if latest:
                latest_leg, latest_num = latest.split(":", 1)
                cached_number, cached_leg = int(latest_num), latest_leg
                latest_fresh = self._is_fresh(f"round:{cached_leg}:{cached_number}")
                if not force_refresh and latest_fresh:
                    round_number, leg = cached_number, cached_leg
                else:
                    stale_fixtures = self._read_fixtures(cached_leg, cached_number)
                    try:
                        round_number, leg, _ = self._refresh()
                    except LndError:
                        if not stale_fixtures:
                            raise
                        round_number, leg = cached_number, cached_leg
                        refresh_failed = True
            if round_number is None:
                try:
                    round_number, leg, _ = self._refresh()
                except LndError:
                    raise
                # The base page has already been fetched and saved.
                force_refresh = False
        elif round_number is None or leg is None:
            raise ValueError("round_number e leg devono essere specificati insieme")
        if leg not in {"first", "second"} or not 1 <= round_number <= 17:
            raise ValueError("Giornata non valida: leg deve essere first/second e round 1..17")
        key = f"round:{leg}:{round_number}"
        fixtures = self._read_fixtures(leg, round_number)
        if not refresh_failed and (force_refresh or not fixtures or not self._is_fresh(key)):
            try:
                self._refresh(round_number, leg)
            except LndError:
                if not fixtures:
                    raise
        fixtures = self._read_fixtures(leg, round_number)
        updated_at = self._cache_time(key)
        return {
            "updated_at": updated_at,
            "source": SOURCE,
            "matchday": {"number": round_number, "leg": leg},
            "fixtures": fixtures,
        }

    def get_overview(
        self,
        round_number: int | None = None,
        leg: str | None = None,
        force_refresh: bool = False,
    ) -> dict[str, Any]:
        if round_number is None:
            calendar = self.get_calendar()
            round_number = calendar["matchday"]["number"]
            leg = calendar["matchday"]["leg"]
        calendar = self.get_calendar(round_number, leg, force_refresh)
        standings = self.get_standings()
        return {
            "updated_at": max(
                value for value in [calendar["updated_at"], standings["updated_at"]] if value is not None
            ),
            "source": SOURCE,
            "matchday": calendar["matchday"],
            "standings": standings["standings"],
            "fixtures": calendar["fixtures"],
        }

    def _meta(self, key: str) -> str | None:
        with self._session() as db:
            row = db.execute("SELECT value FROM cache_meta WHERE key = ?", (key,)).fetchone()
        return str(row["value"]) if row else None

    def _read_standings(self) -> list[dict[str, Any]]:
        with self._session() as db:
            rows = [dict(row) for row in db.execute("SELECT * FROM standings ORDER BY position")]
        for row in rows:
            row["logo_url"] = _logo_with_fallback(row["team"], row["logo_url"])
        return rows

    def _read_fixtures(self, leg: str, number: int) -> list[dict[str, Any]]:
        with self._session() as db:
            rows = [dict(row) for row in db.execute(
                "SELECT * FROM fixtures WHERE leg = ? AND round_number = ? ORDER BY date, time, id",
                (leg, number),
            )]
        for row in rows:
            row["home_logo_url"] = _logo_with_fallback(row["home_team"], row["home_logo_url"])
            row["away_logo_url"] = _logo_with_fallback(row["away_team"], row["away_logo_url"])
        return rows
