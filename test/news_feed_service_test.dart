import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:amaranto_feed/services/news_feed_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'parsed cache survives recreation, expires and supports forced refresh',
    () async {
      var now = DateTime.utc(2026, 10, 31);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(_rss(request.url.host), 200);
      });
      var service = NewsFeedService(client: client, clock: () => now);
      final original = await service.fetchLatest();
      expect(calls, 4);
      expect(original, hasLength(4));
      await service.fetchLatest();
      expect(calls, 4);
      service = NewsFeedService(client: client, clock: () => now);
      final cached = await service.fetchLatest();
      expect(calls, 4);
      expect(cached.first.title, original.first.title);
      expect(cached.first.hasPublicationDate, isFalse);
      expect(cached.first.isOfficial, original.first.isOfficial);
      await service.fetchLatest(forceRefresh: true);
      expect(calls, 8);
      now = now.add(NewsFeedService.cacheTtl);
      await service.fetchLatest();
      expect(calls, 12);
      service.close();
    },
  );

  test(
    'failed sources retain their articles without renewing freshness',
    () async {
      var now = DateTime.utc(2026, 10, 31);
      var offline = false;
      final calls = <String, int>{};
      final service = NewsFeedService(
        clock: () => now,
        client: MockClient((request) async {
          final host = request.url.host;
          calls[host] = (calls[host] ?? 0) + 1;
          if (offline && host != 'www.citynow.it') {
            return http.Response('', 503);
          }
          return http.Response(_rss(host), 200);
        }),
      );
      await service.fetchLatest();
      now = now.add(NewsFeedService.cacheTtl);
      offline = true;
      expect(await service.fetchLatest(), hasLength(4));
      expect(await service.fetchLatest(), hasLength(4));
      expect(calls['www.citynow.it'], 2);
      expect(calls['www.reggina1914.it'], 3);
      service.close();
    },
  );

  test('concurrent loads share requests and corrupt cache recovers', () async {
    SharedPreferences.setMockInitialValues({'news_feeds_v1': '{invalid'});
    final ready = Completer<void>();
    var calls = 0;
    final service = NewsFeedService(
      client: MockClient((request) async {
        calls++;
        await ready.future;
        return http.Response(_rss(request.url.host), 200);
      }),
    );
    final first = service.fetchLatest();
    final second = service.fetchLatest(forceRefresh: true);
    ready.complete();
    await Future.wait([first, second]);
    expect(calls, 4);
    service.close();
  });

  test(
    'all sources offline uses persisted articles, or throws without cache',
    () async {
      var offline = false;
      final client = MockClient(
        (request) async => offline
            ? http.Response('', 503)
            : http.Response(_rss(request.url.host), 200),
      );
      await NewsFeedService(client: client).fetchLatest();
      offline = true;
      final service = NewsFeedService(client: client);
      expect(await service.fetchLatest(forceRefresh: true), hasLength(4));
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        NewsFeedService(client: client).fetchLatest(),
        throwsException,
      );
      service.close();
    },
  );

  test(
    'missing RSS dates remain visible but cannot trigger news notifications',
    () async {
      final service = NewsFeedService(
        client: MockClient(
          (request) async => http.Response('''
      <rss><channel><item><title>Notizia senza data</title><link>https://example.org/news</link></item></channel></rss>
    ''', 200),
        ),
      );
      final articles = await service.fetchLatest();
      expect(articles.single.hasPublicationDate, isFalse);
      service.close();
    },
  );

  test('parses RSS publication timezone and preserves working feeds during outages', () async {
    final service = NewsFeedService(
      client: MockClient((request) async {
        if (request.url.host != 'www.citynow.it') {
          return http.Response('offline', 503);
        }
        return http.Response('''
        <rss><channel><item><title>Nuova notizia</title><link>https://example.org/new</link>
        <pubDate>Sat, 31 Oct 2026 12:00:00 +0100</pubDate></item></channel></rss>
      ''', 200);
      }),
    );
    final articles = await service.fetchLatest();
    expect(articles.single.source, 'CityNow');
    expect(articles.single.hasPublicationDate, isTrue);
    expect(articles.single.publishedAt, DateTime.utc(2026, 10, 31, 11));
    service.close();
  });
}

String _rss(String host) =>
    '<rss><channel><item><title>$host</title>'
    '<link>https://$host/news</link></item></channel></rss>';
