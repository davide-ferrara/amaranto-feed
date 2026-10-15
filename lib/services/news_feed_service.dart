import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/news_article.dart';

class NewsFeedService {
  NewsFeedService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  static const _feeds = [
    _FeedSource(
      name: 'TuttoReggina',
      url: 'https://www.tuttoreggina.com/rss/?section=44',
    ),
    _FeedSource(
      name: 'Il Tifoso Reggino',
      url: 'https://iltifosoreggino.it/category/calcio/reggina/feed/',
    ),
  ];

  Future<List<NewsArticle>> fetchLatest() async {
    final results = await Future.wait(
      _feeds.map((feed) async {
        try {
          return _FeedResult(articles: await _fetchFeed(feed));
        } catch (error) {
          return _FeedResult(error: error);
        }
      }),
    );

    final articles = results.expand((result) => result.articles).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final seenUrls = <String>{};
    final uniqueArticles = articles
        .where((article) => seenUrls.add(article.url))
        .take(40)
        .toList();

    if (uniqueArticles.isEmpty &&
        results.every((result) => result.error != null)) {
      throw Exception('Le fonti non sono raggiungibili. Riprova tra poco.');
    }
    return uniqueArticles;
  }

  Future<List<NewsArticle>> _fetchFeed(_FeedSource feed) async {
    final response = await _client
        .get(
          Uri.parse(feed.url),
          headers: const {'User-Agent': 'RGNNews/1.0 (RSS reader)'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.body);
    return document
        .findAllElements('item')
        .map((item) {
          final title = item.getElement('title')?.innerText.trim() ?? '';
          final url = item.getElement('link')?.innerText.trim() ?? '';
          final dateText = item.getElement('pubDate')?.innerText.trim() ?? '';
          final imageUrl = _imageUrl(item);

          return NewsArticle(
            title: title,
            url: url,
            source: feed.name,
            publishedAt: _parseDate(dateText),
            imageUrl: imageUrl,
          );
        })
        .where((article) => article.title.isNotEmpty && _isHttpUrl(article.url))
        .toList();
  }

  String? _imageUrl(XmlElement item) {
    final enclosure = item.getElement('enclosure')?.getAttribute('url');
    if (_isHttpUrl(enclosure ?? '')) return enclosure;

    for (final element in item.descendants.whereType<XmlElement>()) {
      if (element.name.local == 'content' && element.name.prefix == 'media') {
        final url = element.getAttribute('url');
        if (_isHttpUrl(url ?? '')) return url;
      }
    }
    return null;
  }

  DateTime _parseDate(String value) {
    final isoDate = DateTime.tryParse(value);
    if (isoDate != null) return isoDate;

    final match = RegExp(
      r'(?:\w+,\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+(GMT|UTC|[+-]\d{4})',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return DateTime.now();

    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return DateTime.now();

    final localTime = DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
    final timezone = match.group(7)!.toUpperCase();
    if (timezone == 'GMT' || timezone == 'UTC') return localTime;

    final offset = timezone.substring(1);
    final offsetMinutes =
        int.parse(offset.substring(0, 2)) * 60 + int.parse(offset.substring(2));
    return timezone.startsWith('+')
        ? localTime.subtract(Duration(minutes: offsetMinutes))
        : localTime.add(Duration(minutes: offsetMinutes));
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}

class _FeedSource {
  const _FeedSource({required this.name, required this.url});

  final String name;
  final String url;
}

class _FeedResult {
  const _FeedResult({this.articles = const [], this.error});

  final List<NewsArticle> articles;
  final Object? error;
}
