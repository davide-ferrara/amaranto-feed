import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rgn_news/services/news_feed_service.dart';

void main() {
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
