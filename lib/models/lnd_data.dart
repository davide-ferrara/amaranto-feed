class LeagueStanding {
  const LeagueStanding({
    required this.position,
    required this.team,
    required this.logoUrl,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalDifference,
    required this.points,
  });

  final int position;
  final String team;
  final String? logoUrl;
  final int played, wins, draws, losses, goalDifference, points;
}

class LeagueFixture {
  const LeagueFixture({
    required this.id,
    required this.matchday,
    required this.roundNumber,
    required this.leg,
    required this.date,
    required this.time,
    required this.venue,
    required this.address,
    required this.homeTeam,
    required this.homeLogoUrl,
    required this.awayTeam,
    required this.awayLogoUrl,
    this.homeScore,
    this.awayScore,
  });

  final String id, matchday, date, time, venue, address;
  final int roundNumber;
  final String leg;
  final String homeTeam, awayTeam;
  final String? homeLogoUrl, awayLogoUrl;
  final int? homeScore, awayScore;
}

class LndDataSnapshot {
  const LndDataSnapshot({
    required this.standings,
    required this.fixtures,
    required this.updatedAt,
  });
  final List<LeagueStanding> standings;
  final List<LeagueFixture> fixtures;
  final DateTime? updatedAt;

  factory LndDataSnapshot.fromJson(Map<String, dynamic> json) {
    final standings = (json['standings'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => LeagueStanding(
            position: _intValue(row['position']),
            team: row['team'] as String? ?? '',
            logoUrl: row['logo_url'] as String?,
            played: _intValue(row['played']),
            wins: _intValue(row['wins']),
            draws: _intValue(row['draws']),
            losses: _intValue(row['losses']),
            goalDifference: _intValue(row['goal_difference']),
            points: _intValue(row['points']),
          ),
        )
        .toList();
    final matchday = json['matchday'] as Map<String, dynamic>? ?? const {};
    final number = _intValue(matchday['number']);
    final leg = matchday['leg'] as String? ?? 'first';
    final fixtures = (json['fixtures'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => LeagueFixture(
            id: row['id'].toString(),
            matchday: row['matchday'] as String? ?? '$leg:$number',
            roundNumber: _intValue(row['round_number'] ?? number),
            leg: row['leg'] as String? ?? leg,
            date: row['date'] as String? ?? '',
            time: row['time'] as String? ?? '',
            venue: row['venue'] as String? ?? '',
            address: row['address'] as String? ?? '',
            homeTeam: row['home_team'] as String? ?? '',
            homeLogoUrl: row['home_logo_url'] as String?,
            awayTeam: row['away_team'] as String? ?? '',
            awayLogoUrl: row['away_logo_url'] as String?,
            homeScore: row['home_score'] as int?,
            awayScore: row['away_score'] as int?,
          ),
        )
        .toList();
    return LndDataSnapshot(
      standings: standings,
      fixtures: fixtures,
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}')?.toLocal(),
    );
  }
}

int _intValue(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
