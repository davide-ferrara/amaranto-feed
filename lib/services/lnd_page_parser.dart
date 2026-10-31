import 'dart:convert';

import 'lnd_team_names.dart';

/// Converts LND's embedded Inertia page (or direct JSON) to the local data model.
Map<String, dynamic> parseLndPage(String body, DateTime fetchedAt) {
  var payload = body.trim();
  if (!payload.startsWith('{')) {
    final scripts = RegExp(
      r'<script\b([^>]*)>([\s\S]*?)</script\s*>',
      caseSensitive: false,
    ).allMatches(payload);
    payload = scripts.firstWhere(
      (script) =>
          RegExp(
            r'''\bdata-page\s*=\s*["']app["']''',
            caseSensitive: false,
          ).hasMatch(script[1]!) &&
          RegExp(
            r'''\btype\s*=\s*["']application/json["']''',
            caseSensitive: false,
          ).hasMatch(script[1]!),
      orElse: () => throw const FormatException('Payload LND assente'),
    )[2]!;
  }
  final page = jsonDecode(payload);
  if (page is! Map<String, dynamic> || page['props'] is! Map<String, dynamic>) {
    throw const FormatException('Payload LND non valido');
  }
  final props = page['props'] as Map<String, dynamic>;
  final current = props['currentMatchday'];
  if (props['standings'] is! List ||
      props['matches'] is! List ||
      current is! Map ||
      !const ['first', 'second'].contains(current['leg'])) {
    throw const FormatException('Dati LND incompleti');
  }
  final number = _integer(current['number']);
  final leg = current['leg'] as String;
  if (number == null || number < 1 || number > 17) {
    throw const FormatException('Giornata LND non valida');
  }
  final standings = <Map<String, dynamic>>[];
  for (final row in (props['standings'] as List).whereType<Map>()) {
    final position = _integer(row['position']);
    if (position == null || '${row['team'] ?? ''}'.isEmpty) continue;
    final team = _team('${row['team']}');
    standings.add({
      'position': position,
      'team': team,
      'logo_url': _logo(team, row['logo']),
      for (final key in ['played', 'wins', 'draws', 'losses', 'points'])
        key: _integer(row[key]) ?? 0,
      'goal_difference':
          (_integer(row['goalsFor']) ?? 0) -
          (_integer(row['goalsAgainst']) ?? 0),
    });
  }
  standings.sort(
    (a, b) => (a['position'] as int).compareTo(b['position'] as int),
  );
  final fixtures = <Map<String, dynamic>>[];
  for (final row in (props['matches'] as List).whereType<Map>()) {
    if (_truth(row['isRest'])) continue;
    final home = '${row['home'] ?? ''}';
    final away = '${row['away'] ?? ''}';
    if (home.isEmpty || away.isEmpty) continue;
    final homeTeam = _team(home), awayTeam = _team(away);
    final time = '${row['time'] ?? ''}';
    fixtures.add({
      'id': '${row['id'] ?? '$leg-$number-${fixtures.length}-$home-$away'}',
      'matchday': '$leg:$number',
      'round_number': number,
      'leg': leg,
      'date': '${row['date'] ?? ''}',
      'time': time.length > 5 ? time.substring(0, 5) : time,
      'venue': '${row['field'] ?? ''}',
      'address': '${row['fieldAddress'] ?? ''}',
      'home_team': homeTeam,
      'away_team': awayTeam,
      'home_logo_url': _logo(homeTeam, row['homeLogo']),
      'away_logo_url': _logo(awayTeam, row['awayLogo']),
      'home_score': _truth(row['isPlayed']) ? _integer(row['homeGoals']) : null,
      'away_score': _truth(row['isPlayed']) ? _integer(row['awayGoals']) : null,
    });
  }
  fixtures.sort(
    (a, b) => '${a['date']} ${a['time']} ${a['id']}'.compareTo(
      '${b['date']} ${b['time']} ${b['id']}',
    ),
  );
  if (standings.length < 10 || fixtures.isEmpty) {
    throw const FormatException('La risposta LND contiene dati incompleti');
  }
  return {
    'updated_at': fetchedAt.toUtc().toIso8601String(),
    'matchday': {'number': number, 'leg': leg},
    'standings': standings,
    'fixtures': fixtures,
  };
}

int? _integer(Object? value) => value is int ? value : int.tryParse('$value');
bool _truth(Object? value) =>
    value == true ||
    const ['1', 'true', 'yes'].contains('$value'.trim().toLowerCase());
String _key(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
final _aliases = {
  for (final entry in lndTeamAliases.entries) _key(entry.key): entry.value,
};
String _team(String value) =>
    _aliases[_key(value)] ??
    value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
String? _logo(String team, Object? value) {
  if (value is! String) return null;
  if (Uri.tryParse(value)?.path
          .toLowerCase()
          .endsWith('/lndimg/0/logo-societa-generico.png') ??
      false) {
    return lndTeamLogoFallbacks[_key(team)] ?? value;
  }
  return value;
}
