import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:amaranto_feed/main.dart';
import 'package:amaranto_feed/models/lnd_data.dart';
import 'package:amaranto_feed/services/lnd_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lnd_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('le frecce cambiano giornata e mostrano il risultato', (
    tester,
  ) async {
    final service = LndDataService(
      client: MockClient((request) async {
        final round = int.parse(request.url.queryParameters['giornata'] ?? '8');
        return http.Response(
          jsonEncode(lndPage(round: round, played: round == 7)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LndFixturesPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Andata · 8ª giornata'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Andata · 7ª giornata'), findsOneWidget);
    expect(find.text('1-1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Andata · 8ª giornata'), findsOneWidget);

    service.close();
  });

  testWidgets('la pagina della partita offre un tasto indietro visibile', (
    tester,
  ) async {
    const fixture = LeagueFixture(
      id: '1',
      matchday: 'first:8',
      roundNumber: 8,
      leg: 'first',
      date: '2026-10-18',
      time: '15:00',
      venue: 'Granillo',
      address: 'Reggio Calabria',
      homeTeam: 'Reggina 1914',
      homeLogoUrl: null,
      awayTeam: 'Avversaria',
      awayLogoUrl: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MatchDetailsPage(
                    fixture: fixture,
                    isLoading: false,
                  ),
                ),
              ),
              child: const Text('Apri partita'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri partita'));
    await tester.pumpAndSettle();
    expect(find.text('Prossima partita'), findsOneWidget);
    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();
    expect(find.text('Apri partita'), findsOneWidget);
  });
}
