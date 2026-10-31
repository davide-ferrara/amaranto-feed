import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lnd_data.dart';
import 'lnd_page_parser.dart';

/// Reads public LND data directly and keeps a season-scoped on-device cache.
class LndDataService {
  LndDataService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  static const source =
      'https://gare.lnd.it/competizione/dipartimento-interregionale/';
  static const cacheTtl = Duration(hours: 6);
  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, Future<LndDataSnapshot>> _inFlight = {};
  final Map<String, Map<String, dynamic>> _memory = {};

  Future<LndDataSnapshot> load({
    bool forceRefresh = false,
    int? roundNumber,
    String leg = 'first',
  }) {
    if ((roundNumber != null && (roundNumber < 1 || roundNumber > 17)) ||
        !const ['first', 'second'].contains(leg)) {
      return Future.error(const LndDataException('Giornata non valida'));
    }
    final now = _clock();
    final season = now.month >= 7 ? now.year : now.year - 1;
    final key =
        'lnd_v1_${season}_${roundNumber == null ? 'latest' : '$leg:$roundNumber'}';
    final requestKey = '$key:$forceRefresh';
    return _inFlight.putIfAbsent(requestKey, () async {
      try {
        return await _load(key, season, forceRefresh, roundNumber, leg);
      } finally {
        _inFlight.remove(requestKey);
      }
    });
  }

  Future<LndDataSnapshot> _load(
    String key,
    int season,
    bool forceRefresh,
    int? roundNumber,
    String leg,
  ) async {
    SharedPreferences? preferences;
    Map<String, dynamic>? cached = _memory[key];
    try {
      preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(key);
      if (cached == null && stored != null) {
        cached = jsonDecode(stored) as Map<String, dynamic>;
        // Ignore damaged or incomplete entries, rather than treating them as data.
        final snapshot = LndDataSnapshot.fromJson(cached);
        if (snapshot.standings.length < 10 || snapshot.fixtures.isEmpty) {
          cached = null;
        }
      }
    } catch (_) {
      // Storage failure must not prevent direct network access.
      cached = _memory[key];
    }
    if (cached != null && !forceRefresh) {
      final updated = DateTime.tryParse('${cached['updated_at']}');
      if (updated != null) {
        final age = _clock().difference(updated);
        if (!age.isNegative && age < cacheTtl) {
          return LndDataSnapshot.fromJson(cached);
        }
      }
    }
    try {
      final uri = Uri.parse(source).replace(
        queryParameters: {
          'campionato': 'ID',
          'girone': 'I',
          'stagione': '$season',
          if (roundNumber != null) 'giornata': '$roundNumber',
          if (roundNumber != null) 'leg': leg,
        },
      );
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'text/html,application/xhtml+xml,application/json',
              'User-Agent': 'AmarantoFeed/1.0 (public LND competition data)',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw LndDataException('LND: HTTP ${response.statusCode}');
      }
      final data = parseLndPage(utf8.decode(response.bodyBytes), _clock());
      final matchday = data['matchday'] as Map<String, dynamic>;
      if (roundNumber != null &&
          (matchday['number'] != roundNumber || matchday['leg'] != leg)) {
        throw const LndDataException('La giornata richiesta non è disponibile');
      }
      final snapshot = LndDataSnapshot.fromJson(data);
      _memory[key] = data;
      try {
        await preferences?.setString(key, jsonEncode(data));
      } catch (_) {
        // A full disk must not discard a successful refresh.
      }
      return snapshot;
    } catch (_) {
      if (cached != null) return LndDataSnapshot.fromJson(cached);
      rethrow;
    }
  }

  void close() => _client.close();
}

class LndDataException implements Exception {
  const LndDataException(this.message);
  final String message;
  @override
  String toString() => message;
}
