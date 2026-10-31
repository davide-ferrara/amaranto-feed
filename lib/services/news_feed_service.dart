import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/news_article.dart';

class NewsFeedService {
  NewsFeedService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  static const cacheTtl = Duration(minutes: 5);
  static const _cacheKey = 'news_feeds_v1';
  final DateTime Function() _clock;
  final Map<String, _CachedFeed> _cache = {};
  Future<List<NewsArticle>>? _inFlight;
  bool _cacheLoaded = false;

  final http.Client _client;

  void close() => _client.close();

  static const _feeds = [
    _FeedSource(
      name: 'Reggina 1914',
      url: 'https://www.reggina1914.it/feed/',
      isOfficial: true,
    ),
    _FeedSource(
      name: 'CityNow',
      url: 'https://www.citynow.it/tag/reggina/feed/',
    ),
    _FeedSource(
      name: 'TuttoReggina',
      url: 'https://www.tuttoreggina.com/rss/?section=44',
    ),
    _FeedSource(
      name: 'Il Tifoso Reggino',
      url: 'https://iltifosoreggino.it/category/calcio/reggina/feed/',
    ),
  ];

  /// Reuses parsed feeds for five minutes. Explicit refresh bypasses the TTL.
  /// Concurrent callers share a single fetch, including manual refreshes.
  Future<List<NewsArticle>> fetchLatest({bool forceRefresh = false}) {
    return _inFlight ??= _load(forceRefresh).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<List<NewsArticle>> _load(bool forceRefresh) async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      if (!_cacheLoaded) {
        final raw = preferences.getString(_cacheKey);
        if (raw != null) {
          final entries = jsonDecode(raw) as Map<String, dynamic>;
          for (final feed in _feeds) {
            try {
              if (entries[feed.url] != null) {
                _cache[feed.url] = _CachedFeed.fromJson(entries[feed.url]);
              }
            } catch (_) {
              // A damaged source must not discard other cached feeds.
            }
          }
        }
      }
    } catch (_) {
      // Storage failures must not prevent loading news.
    }
    _cacheLoaded = true;
    var changed = false;
    final results = await Future.wait(
      _feeds.map((feed) async {
        final cached = _cache[feed.url];
        if (!forceRefresh && cached != null) {
          final age = _clock().difference(cached.updatedAt);
          if (!age.isNegative && age < cacheTtl) {
            return _FeedResult(articles: cached.articles);
          }
        }
        try {
          final articles = await _fetchFeed(feed);
          _cache[feed.url] = _CachedFeed(_clock(), articles);
          changed = true;
          return _FeedResult(articles: articles);
        } catch (error) {
          return _FeedResult(
            articles: cached?.articles ?? const [],
            error: error,
          );
        }
      }),
    );
    if (changed) {
      try {
        await preferences?.setString(
          _cacheKey,
          jsonEncode({
            for (final entry in _cache.entries) entry.key: entry.value.toJson(),
          }),
        );
      } catch (_) {
        // Keep successfully fetched articles even if persistence fails.
      }
    }

    final articles = results.expand((result) => result.articles).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final seenUrls = <String>{};
    final uniqueArticles = articles
        .where((article) => seenUrls.add(article.url))
        .take(40)
        .toList(growable: false);

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
          headers: const {'User-Agent': 'AmarantoFeed/1.0 (RSS reader)'},
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
          final publishedAt = _parseDate(dateText);

          return NewsArticle(
            title: title,
            url: url,
            source: feed.name,
            publishedAt: publishedAt ?? _clock(),
            hasPublicationDate: publishedAt != null,
            imageUrl: imageUrl,
            isOfficial: feed.isOfficial,
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

  DateTime? _parseDate(String value) {
    final isoDate = DateTime.tryParse(value);
    if (isoDate != null) return isoDate;

    final match = RegExp(
      r'(?:\w+,\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+(GMT|UTC|[+-]\d{4})',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;

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
    if (month == null) return null;

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
  const _FeedSource({
    required this.name,
    required this.url,
    this.isOfficial = false,
  });

  final String name;
  final String url;
  final bool isOfficial;
}

class _FeedResult {
  const _FeedResult({this.articles = const [], this.error});

  final List<NewsArticle> articles;
  final Object? error;
}

/// Parsed articles and freshness belong to each source independently.
class _CachedFeed {
  const _CachedFeed(this.updatedAt, this.articles);

  final DateTime updatedAt;
  final List<NewsArticle> articles;

  factory _CachedFeed.fromJson(dynamic value) {
    final data = value as Map<String, dynamic>;
    return _CachedFeed(
      DateTime.parse(data['updated_at'] as String),
      (data['articles'] as List)
          .map((value) {
            final article = value as Map<String, dynamic>;
            final url = article['url'] as String;
            final uri = Uri.parse(url);
            if (uri.scheme != 'https' && uri.scheme != 'http') {
              throw const FormatException('URL non valido');
            }
            return NewsArticle(
              title: article['title'] as String,
              url: url,
              source: article['source'] as String,
              publishedAt: DateTime.parse(article['published_at'] as String),
              imageUrl: article['image_url'] as String?,
              isOfficial: article['is_official'] as bool,
              hasPublicationDate: article['has_publication_date'] as bool,
            );
          })
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'updated_at': updatedAt.toIso8601String(),
    'articles': articles
        .map(
          (article) => {
            'title': article.title,
            'url': article.url,
            'source': article.source,
            'published_at': article.publishedAt.toIso8601String(),
            'image_url': article.imageUrl,
            'is_official': article.isOfficial,
            'has_publication_date': article.hasPublicationDate,
          },
        )
        .toList(),
  };
}
