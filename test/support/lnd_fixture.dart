Map<String, dynamic> lndPage({
  int round = 8,
  String leg = 'first',
  bool played = false,
}) => {
  'props': {
    'currentMatchday': {'number': round, 'leg': leg},
    'standings': List.generate(
      10,
      (index) => {
        'position': index + 1,
        'team': index == 0 ? 'Regina1914SSDARL' : 'Club $index',
        'played': 7,
        'wins': 5,
        'draws': 1,
        'losses': 1,
        'goalsFor': 16,
        'goalsAgainst': 2,
        'points': 16,
      },
    ),
    'matches': [
      {
        'id': round,
        'home': 'REGGINA 1914',
        'away': 'NISSA F.C.',
        'date': '2026-10-18',
        'time': '15:00:00',
        'field': 'Granillo',
        'fieldAddress': 'Reggio Calabria',
        'homeGoals': '1',
        'awayGoals': '1',
        'isPlayed': played,
      },
    ],
  },
};
