import 'dart:convert';

import 'package:http/http.dart' as http;

class ReleaseUpdate {
  const ReleaseUpdate({required this.version, required this.downloadUrl});

  final String version;
  final Uri downloadUrl;
}

/// Public releases only: no account, token, or application server required.
class ReleaseUpdateService {
  ReleaseUpdateService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  static const repository = 'davide-ferrara/amaranto-feed';
  static final latestRelease = Uri.https(
    'api.github.com',
    '/repos/$repository/releases/latest',
  );
  final http.Client _client;
  final DateTime Function() _clock;
  DateTime? _nextCheck;
  ReleaseUpdate? _available;
  Future<ReleaseUpdate?>? _inFlight;

  void close() => _client.close();

  Future<ReleaseUpdate?> check({required String installedVersion}) {
    if (_inFlight != null) return _inFlight!;
    if (_nextCheck != null && _clock().isBefore(_nextCheck!)) {
      return Future.value(_available);
    }
    return _inFlight = _fetch(installedVersion).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<ReleaseUpdate?> _fetch(String installedVersion) async {
    // Retry transient failures on a later resume; avoid hammering GitHub.
    _nextCheck = _clock().add(const Duration(minutes: 5));
    try {
      final response = await _client
          .get(
            latestRelease,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Amaranto-Feed',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        _available = null;
      } else if (response.statusCode == 200) {
        final release = jsonDecode(response.body);
        if (release is! Map<String, dynamic>) return _available;
        _available = _parse(release, installedVersion);
      } else {
        return _available;
      }
      _nextCheck = _clock().add(const Duration(hours: 6));
    } on Exception {
      // Offline/rate-limited update checks must never interrupt normal app use.
    }
    return _available;
  }

  ReleaseUpdate? _parse(Map<String, dynamic> release, String installedVersion) {
    if (release['draft'] == true || release['prerelease'] == true) return null;
    final tag = release['tag_name'];
    if (tag is! String) return null;
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (!_isNewer(version, installedVersion)) return null;
    final assets = release['assets'];
    if (assets is! List) return null;
    // Release tooling publishes one universal APK, suitable for all Android ABIs.
    for (final asset in assets.whereType<Map<String, dynamic>>()) {
      if (asset['name'] != 'amaranto-feed-$version.apk' ||
          asset['state'] != 'uploaded') {
        continue;
      }
      final value = asset['browser_download_url'];
      if (value is! String) continue;
      final url = Uri.tryParse(value);
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'github.com' ||
          !url.path.startsWith('/$repository/releases/download/$tag/')) {
        continue;
      }
      return ReleaseUpdate(version: version, downloadUrl: url);
    }
    return null;
  }

  bool _isNewer(String remote, String installed) {
    final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$');
    final remoteMatch = pattern.firstMatch(remote);
    final installedMatch = pattern.firstMatch(installed);
    if (remoteMatch == null || installedMatch == null) return false;
    for (var index = 1; index <= 3; index++) {
      final difference =
          int.parse(remoteMatch[index]!) - int.parse(installedMatch[index]!);
      if (difference != 0) return difference > 0;
    }
    return false;
  }
}
