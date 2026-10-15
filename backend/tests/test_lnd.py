from __future__ import annotations

import json
import tempfile
import unittest
from datetime import timedelta
from pathlib import Path
from unittest.mock import patch

from app.lnd import (
    GENERIC_LND_LOGO_PATH,
    TEAM_ALIASES,
    TEAM_LOGO_FALLBACKS,
    LndError,
    LndRepository,
    _logo_with_fallback,
    _normalize,
    parse_lnd_response,
)


def sample_page() -> dict:
    standings = [
        {
            "position": index + 1,
            "team": "reggina 1914" if index == 0 else f"club {index}",
            "logo": f"https://play.lnd.it/{index}.png",
            "played": 7,
            "wins": 5,
            "draws": 1,
            "losses": 1,
            "goalsFor": 16,
            "goalsAgainst": 2,
            "points": 16,
        }
        for index in range(10)
    ]
    return {
        "component": "QuadroGare/Home",
        "props": {
            "currentMatchday": {"number": 8, "leg": "first"},
            "standings": standings,
            "matches": [
                {
                    "id": 123,
                    "date": "2026-10-18",
                    "time": "15:00:00",
                    "home": "NISSA F.C.",
                    "away": "REGGINA 1914",
                    "homeGoals": 0,
                    "awayGoals": 0,
                    "isPlayed": False,
                    "field": "Granillo",
                    "fieldAddress": "Reggio Calabria",
                    "homeLogo": "https://play.lnd.it/nissa.png",
                    "awayLogo": "https://play.lnd.it/reggina.png",
                }
            ],
        },
    }


class LndParserTests(unittest.TestCase):
    def test_generic_team_badges_use_manual_fallbacks_only_for_mapped_clubs(self) -> None:
        generic = f"https://play.lnd.it{GENERIC_LND_LOGO_PATH}"
        self.assertEqual(_logo_with_fallback("Licata", generic), TEAM_LOGO_FALLBACKS["licata"])
        self.assertEqual(_logo_with_fallback("Gela", generic), TEAM_LOGO_FALLBACKS["gela"])
        self.assertEqual(_logo_with_fallback("Nissa", generic), generic)
        real_logo = "https://play.lnd.it/lndimg/123/123-web.png"
        self.assertEqual(_logo_with_fallback("Licata", real_logo), real_logo)
        self.assertIsNone(_logo_with_fallback("Licata", None))

    def test_parse_embedded_inertia_json(self) -> None:
        page = sample_page()
        html = (
            '<html><script data-page="app" type="application/json">'
            + json.dumps(page)
            + "</script></html>"
        )
        parsed = parse_lnd_response(html)
        standings, fixtures, number, leg = _normalize(parsed)
        self.assertEqual((number, leg), (8, "first"))
        self.assertEqual(standings[0]["goal_difference"], 14)
        self.assertEqual(standings[0]["logo_url"], "https://play.lnd.it/0.png")
        self.assertEqual(fixtures[0]["time"], "15:00")
        self.assertIsNone(fixtures[0]["home_score"])
        self.assertEqual(fixtures[0]["away_logo_url"], "https://play.lnd.it/reggina.png")
        self.assertEqual(standings[0]["team"], "Reggina 1914")
        self.assertEqual(fixtures[0]["home_team"], "Nissa")
        self.assertEqual(fixtures[0]["away_team"], "Reggina 1914")

    def test_manual_aliases_remove_company_suffixes(self) -> None:
        teams = [
            {"position": index + 1, "team": name, "played": 0, "wins": 0,
             "draws": 0, "losses": 0, "goalsFor": 0, "goalsAgainst": 0,
             "points": 0}
            for index, name in enumerate(
                ["Regina1914SSDARL", "Sanbiase2023", "CalcioAvola1949SD", "VibonesecalcioSRL"]
                + [f"Squadra {index}" for index in range(6)]
            )
        ]
        payload = parse_lnd_response(json.dumps({"props": {
            "currentMatchday": {"number": 1, "leg": "first"},
            "standings": teams,
            "matches": [{"id": 1, "home": "Regina1914SSDARL", "away": "VibonesecalcioSRL"}],
        }}))
        standings, fixtures, _, _ = _normalize(payload)
        self.assertEqual(
            [team["team"] for team in standings[:4]],
            ["Reggina 1914", "Sambiase 2023", "Calcio Avola 1949", "Vibonese"],
        )
        self.assertEqual(fixtures[0]["home_team"], "Reggina 1914")
        self.assertEqual(fixtures[0]["away_team"], "Vibonese")
        self.assertEqual(len(set(TEAM_ALIASES.values())), 18)

    def test_parse_direct_inertia_json_response(self) -> None:
        parsed = parse_lnd_response(json.dumps(sample_page()))
        self.assertEqual(parsed["round_number"], 8)

    def test_match_scores_parse_from_numeric_strings_when_played(self) -> None:
        page = sample_page()
        match = page["props"]["matches"][0]
        match.update({"homeGoals": "2", "awayGoals": "1", "isPlayed": "true"})
        _, fixtures, _, _ = _normalize(parse_lnd_response(json.dumps(page)))
        self.assertEqual((fixtures[0]["home_score"], fixtures[0]["away_score"]), (2, 1))

    def test_unplayed_zero_placeholders_are_not_reported_as_a_result(self) -> None:
        _, fixtures, _, _ = _normalize(parse_lnd_response(json.dumps(sample_page())))
        self.assertEqual((fixtures[0]["home_score"], fixtures[0]["away_score"]), (None, None))


class LndRepositoryTests(unittest.TestCase):
    def test_cached_standings_and_fixtures_apply_logo_fallbacks(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = LndRepository(Path(temp_dir) / "cache.sqlite3")
            generic = f"https://play.lnd.it{GENERIC_LND_LOGO_PATH}"
            with repository._session() as db:
                db.execute(
                    """INSERT INTO standings
                    (position, team, logo_url, played, wins, draws, losses, goal_difference, points)
                    VALUES (1, 'Licata', ?, 0, 0, 0, 0, 0, 0)""",
                    (generic,),
                )
                db.execute(
                    """INSERT INTO fixtures
                    (id, matchday, round_number, leg, date, time, venue, address,
                     home_team, home_logo_url, away_team, away_logo_url)
                    VALUES ('gela-test', 'first:1', 1, 'first', '', '', '', '', 'Gela', ?, 'Other', ?)""",
                    (generic, generic),
                )
            self.assertEqual(repository._read_standings()[0]["logo_url"], TEAM_LOGO_FALLBACKS["licata"])
            fixture = repository._read_fixtures("first", 1)[0]
            self.assertEqual(fixture["home_logo_url"], TEAM_LOGO_FALLBACKS["gela"])
            self.assertEqual(fixture["away_logo_url"], generic)

    def test_manual_aliases_are_stored_and_migrate_cached_names(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "cache.sqlite3"
            repository = LndRepository(path)
            repository._save(parse_lnd_response(json.dumps(sample_page())), update_latest=True)
            with repository._session() as db:
                db.execute("UPDATE standings SET team = 'Regina1914SSDARL' WHERE position = 1")
                db.execute("UPDATE fixtures SET home_team = 'Nissa F.C.' WHERE id = '123'")

            migrated = LndRepository(path)
            self.assertEqual(migrated._read_standings()[0]["team"], "Reggina 1914")
            self.assertEqual(migrated._read_fixtures("first", 8)[0]["home_team"], "Nissa")
            with migrated._session() as db:
                stored_aliases = db.execute("SELECT COUNT(*) FROM team_aliases").fetchone()[0]
            self.assertGreaterEqual(stored_aliases, 18)

    def test_sqlite_cache_serves_standings_and_calendar(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = LndRepository(
                Path(temp_dir) / "cache.sqlite3", ttl=timedelta(hours=6)
            )
            repository._save(parse_lnd_response(json.dumps(sample_page())), update_latest=True)
            overview = repository.get_overview()
            self.assertEqual(len(overview["standings"]), 10)
            self.assertEqual(overview["matchday"], {"number": 8, "leg": "first"})
            self.assertEqual(len(overview["fixtures"]), 1)
            self.assertEqual(overview["fixtures"][0]["home_team"], "Nissa")
            historical = sample_page()
            historical["props"]["currentMatchday"] = {"number": 2, "leg": "first"}
            historical["props"]["matches"][0]["id"] = 456
            repository._save(parse_lnd_response(json.dumps(historical)), update_latest=False)
            self.assertEqual(repository.get_calendar()["matchday"], {"number": 8, "leg": "first"})
            self.assertEqual(
                repository.get_calendar(2, "first")["matchday"],
                {"number": 2, "leg": "first"},
            )

    def test_stale_cache_is_used_when_lnd_is_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = LndRepository(
                Path(temp_dir) / "cache.sqlite3", ttl=timedelta(seconds=-1)
            )
            repository._save(parse_lnd_response(json.dumps(sample_page())), update_latest=True)
            with patch.object(repository, "_refresh", side_effect=LndError("offline")):
                calendar = repository.get_calendar()
            self.assertEqual(calendar["matchday"], {"number": 8, "leg": "first"})
            self.assertEqual(len(calendar["fixtures"]), 1)


if __name__ == "__main__":
    unittest.main()
