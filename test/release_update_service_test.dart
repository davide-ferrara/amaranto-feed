import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:amaranto_feed/services/release_update_service.dart';

Map<String, dynamic> release(String version) => {
  'tag_name': 'v$version',
  'draft': false,
  'prerelease': false,
  'assets': [
    {
      'name': 'amaranto-feed-$version.apk',
      'state': 'uploaded',
      'browser_download_url':
          'https://github.com/davide-ferrara/amaranto-feed/releases/download/v$version/amaranto-feed-$version.apk',
    },
  ],
};

void main() {
  for (final example in [
    ('1.0.1', '1.0.0', true),
    ('1.1.0', '1.0.9', true),
    ('2.0.0', '1.99.99', true),
    ('1.10.0', '1.9.9', true),
    ('1.0.0', '1.0.0', false),
    ('1.0.0', '1.0.0+2', false),
    ('1.0.0', '1.0.1', false),
    ('1.0.0-beta.1', '1.0.0', false),
    ('invalid', '1.0.0', false),
  ]) {
    test('release ${example.$1} compared to installed ${example.$2}', () async {
      final service = ReleaseUpdateService(
        client: MockClient((request) async {
          expect(request.url, ReleaseUpdateService.latestRelease);
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(jsonEncode(release(example.$1)), 200);
        }),
      );
      addTearDown(service.close);
      final update = await service.check(installedVersion: example.$2);
      expect(update != null, example.$3);
      if (update != null) expect(update.version, example.$1);
    });
  }

  test('only complete stable releases with a trusted universal APK are offered', () async {
    final cases = <Map<String, dynamic>>[
      {...release('1.0.1'), 'draft': true},
      {...release('1.0.1'), 'prerelease': true},
      {...release('1.0.1'), 'assets': []},
      {...release('1.0.1'), 'assets': null},
      {...release('1.0.1'), 'tag_name': null},
    ];
    for (final change in [
      {'state': 'new'},
      {'name': 'source.zip'},
      {'name': 'amaranto-feed-arm64.apk'},
      {'browser_download_url': 'http://github.com/download.apk'},
      {'browser_download_url': 'https://example.com/download.apk'},
      {
        'browser_download_url':
            'https://github.com/someone/other/releases/download/v1.0.1/app.apk',
      },
    ]) {
      final data = release('1.0.1');
      (data['assets'] as List).single.addAll(change);
      cases.add(data);
    }
    for (final data in cases) {
      final service = ReleaseUpdateService(
        client: MockClient((_) async => http.Response(jsonEncode(data), 200)),
      );
      expect(await service.check(installedVersion: '1.0.0'), isNull);
      service.close();
    }
  });

  test(
    '404, rate limits, malformed data and offline failures stay silent',
    () async {
      for (final response in [
        http.Response('', 404),
        http.Response('', 403),
        http.Response('', 500),
        http.Response('invalid JSON', 200),
        http.Response('[]', 200),
      ]) {
        final service = ReleaseUpdateService(
          client: MockClient((_) async => response),
        );
        expect(await service.check(installedVersion: '1.0.0'), isNull);
        service.close();
      }
      final service = ReleaseUpdateService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(await service.check(installedVersion: '1.0.0'), isNull);
      service.close();
    },
  );

  test(
    'checks are deduplicated and successful results cached for six hours',
    () async {
      var now = DateTime.utc(2026, 10, 31);
      var requests = 0;
      final service = ReleaseUpdateService(
        clock: () => now,
        client: MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(release('1.0.1')), 200);
        }),
      );
      addTearDown(service.close);
      final updates = await Future.wait([
        service.check(installedVersion: '1.0.0'),
        service.check(installedVersion: '1.0.0'),
      ]);
      expect(updates.every((update) => update?.version == '1.0.1'), isTrue);
      expect(requests, 1);
      await service.check(installedVersion: '1.0.0');
      expect(requests, 1);
      now = now.add(const Duration(hours: 6));
      await service.check(installedVersion: '1.0.0');
      expect(requests, 2);
    },
  );

  test(
    'a failed check retries after five minutes and preserves a known update',
    () async {
      var now = DateTime.utc(2026, 10, 31);
      var requests = 0;
      final service = ReleaseUpdateService(
        clock: () => now,
        client: MockClient((_) async {
          requests++;
          if (requests == 1 || requests == 3) return http.Response('', 403);
          return http.Response(jsonEncode(release('1.0.1')), 200);
        }),
      );
      addTearDown(service.close);
      expect(await service.check(installedVersion: '1.0.0'), isNull);
      await service.check(installedVersion: '1.0.0');
      expect(requests, 1);
      now = now.add(const Duration(minutes: 5));
      expect(
        (await service.check(installedVersion: '1.0.0'))?.version,
        '1.0.1',
      );
      now = now.add(const Duration(hours: 6));
      expect(
        (await service.check(installedVersion: '1.0.0'))?.version,
        '1.0.1',
      );
      expect(requests, 3);
    },
  );
}
