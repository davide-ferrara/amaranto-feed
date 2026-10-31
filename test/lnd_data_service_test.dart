import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rgn_news/services/lnd_data_service.dart';
import 'package:rgn_news/services/lnd_page_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lnd_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime.utc(2026, 10, 31);

  test('parses HTML and JSON, aliases, stats, and unplayed scores', () {
    final page = lndPage();
    for (final body in [
      jsonEncode(page),
      '<html><script type="application/json" data-page="app">${jsonEncode(page)}</script></html>',
    ]) {
      final data = parseLndPage(body, now);
      expect((data['standings'] as List).first['team'], 'Reggina 1914');
      expect((data['standings'] as List).first['goal_difference'], 14);
      final match = (data['fixtures'] as List).single;
      expect(match['away_team'], 'Nissa');
      expect(match['time'], '15:00');
      expect(match['home_score'], isNull);
    }
  });

  test('played score strings and generic badge fallbacks are retained', () {
    final page = lndPage(played: true);
    final props = page['props'] as Map;
    (props['matches'] as List).first.addAll({
      'home': 'Gela',
      'homeLogo': 'https://play.lnd.it/lndimg/0/logo-societa-generico.png',
      'awayLogo': 'https://play.lnd.it/real.png',
      'isPlayed': 'true',
    });
    final match =
        (parseLndPage(jsonEncode(page), now)['fixtures'] as List).single;
    expect(match['home_score'], 1);
    expect(match['home_logo_url'], contains('wikimedia'));
    expect(match['away_logo_url'], 'https://play.lnd.it/real.png');
    expect(
      () => parseLndPage('<html>Unavailable</html>', now),
      throwsFormatException,
    );
    props['standings'] = [];
    expect(() => parseLndPage(jsonEncode(page), now), throwsFormatException);
  });

  test(
    'direct requests, persistent cache, expiry, refresh and offline fallback',
    () async {
      var calls = 0;
      var offline = false;
      var clock = now;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.host, 'gare.lnd.it');
        expect(request.url.scheme, 'https');
        expect(request.url.queryParameters['stagione'], '2026');
        if (offline) return http.Response('unavailable', 503);
        final round = int.parse(request.url.queryParameters['giornata'] ?? '8');
        return http.Response(
          jsonEncode(
            lndPage(
              round: round,
              leg: request.url.queryParameters['leg'] ?? 'first',
            ),
          ),
          200,
        );
      });
      var service = LndDataService(client: client, clock: () => clock);
      final first = await service.load();
      expect(calls, 1);
      service = LndDataService(client: client, clock: () => clock);
      await service.load();
      expect(calls, 1, reason: 'cache survives service recreation');
      await service.load(forceRefresh: true);
      expect(calls, 2);
      await service.load(roundNumber: 7);
      expect(calls, 3);
      expect((await service.load()).fixtures.single.roundNumber, 8);
      clock = now.add(const Duration(hours: 7));
      offline = true;
      expect((await service.load()).updatedAt, first.updatedAt);
      expect(calls, 4);
      await expectLater(
        service.load(roundNumber: 6),
        throwsA(isA<LndDataException>()),
      );
      service.close();
    },
  );

  test(
    'rejects wrong matchdays and isolates cache at the July season boundary',
    () async {
      var clock = DateTime.utc(2026, 6, 30);
      var calls = 0;
      final service = LndDataService(
        clock: () => clock,
        client: MockClient((request) async {
          calls++;
          expect(
            request.url.queryParameters['stagione'],
            clock.month == 6 ? '2025' : '2026',
          );
          if (clock.month == 7) return http.Response('offline', 503);
          return http.Response(jsonEncode(lndPage()), 200);
        }),
      );
      await expectLater(
        service.load(roundNumber: 7),
        throwsA(isA<LndDataException>()),
      );
      await service.load();
      clock = DateTime.utc(2026, 7, 1);
      await expectLater(service.load(), throwsA(isA<LndDataException>()));
      await expectLater(
        service.load(roundNumber: 18),
        throwsA(isA<LndDataException>()),
      );
      expect(calls, 3);
      service.close();
    },
  );

  test(
    'deduplicates simultaneous requests and ignores corrupt cached data',
    () async {
      SharedPreferences.setMockInitialValues({
        'lnd_v1_2026_latest': '{bad json',
      });
      var calls = 0;
      final ready = Completer<void>();
      final service = LndDataService(
        clock: () => now,
        client: MockClient((request) async {
          calls++;
          await ready.future;
          return http.Response(jsonEncode(lndPage()), 200);
        }),
      );
      final first = service.load(), second = service.load();
      ready.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
      service.close();
    },
  );
}
