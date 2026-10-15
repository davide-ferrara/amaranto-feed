import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lnd_data.dart';

/// REST client only. LND fetching, parsing and SQLite caching live in the
/// FastAPI backend.
class LndDataService {
  LndDataService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'RGN_API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8000',
          );

  final http.Client _client;
  final String _baseUrl;
  final Map<String, Future<LndDataSnapshot>> _inFlight = {};

  Future<LndDataSnapshot> load({
    bool forceRefresh = false,
    int? roundNumber,
    String leg = 'first',
  }) {
    final key = '$roundNumber:$leg:$forceRefresh';
    return _inFlight.putIfAbsent(key, () async {
      try {
        return await _request(
          forceRefresh: forceRefresh,
          roundNumber: roundNumber,
          leg: leg,
        );
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  Future<LndDataSnapshot> _request({
    required bool forceRefresh,
    int? roundNumber,
    required String leg,
  }) async {
    final query = <String, String>{};
    if (roundNumber != null) {
      query['round_number'] = '$roundNumber';
      query['leg'] = leg;
    }
    if (forceRefresh) query['refresh'] = 'true';
    final base = Uri.parse(_baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/');
    final uri = base.resolve('api/overview').replace(queryParameters: query);
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      String detail = 'HTTP ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] is String) {
          detail = body['detail'] as String;
        }
      } catch (_) {
        // Keep the HTTP status as the useful error when no JSON detail exists.
      }
      throw LndApiException(detail);
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const LndApiException('Risposta API non valida');
    }
    return LndDataSnapshot.fromJson(body);
  }

  void close() => _client.close();
}

class LndApiException implements Exception {
  const LndApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
