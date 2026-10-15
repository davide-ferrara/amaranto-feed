import 'package:flutter_test/flutter_test.dart';
import 'package:rgn_news/models/lnd_data.dart';

void main() {
  test('deserializza l’overview REST per classifica e calendario', () {
    final data = LndDataSnapshot.fromJson({
      'updated_at': '2026-10-15T18:00:00+00:00',
      'source': 'https://gare.lnd.it/',
      'matchday': {'number': 8, 'leg': 'first'},
      'standings': [
        {
          'position': 1,
          'team': 'Reggina 1914',
          'logo_url': 'https://play.lnd.it/reggina.png',
          'played': 7,
          'wins': 5,
          'draws': 1,
          'losses': 1,
          'goal_difference': 14,
          'points': 16,
        },
      ],
      'fixtures': [
        {
          'id': '123',
          'matchday': 'first:8',
          'round_number': 8,
          'leg': 'first',
          'date': '2026-10-18',
          'time': '15:00',
          'venue': 'Granillo',
          'address': 'Reggio Calabria',
          'home_team': 'Nissa',
          'home_logo_url': 'https://play.lnd.it/nissa.png',
          'away_team': 'Reggina 1914',
          'away_logo_url': 'https://play.lnd.it/reggina.png',
          'home_score': null,
          'away_score': null,
        },
      ],
    });

    expect(data.standings.single.position, 1);
    expect(data.standings.single.goalDifference, 14);
    expect(data.fixtures.single.roundNumber, 8);
    expect(data.fixtures.single.awayLogoUrl, 'https://play.lnd.it/reggina.png');
    expect(data.fixtures.single.homeScore, isNull);
    expect(data.updatedAt, isNotNull);
  });
}
