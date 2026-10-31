import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_article.dart';

/// Background-only state. Async preferences avoid stale UI-isolate caches.
class NewsNotificationPoll {
  NewsNotificationPoll({
    required this.fetch,
    required this.notify,
    SharedPreferencesAsync? preferences,
    DateTime Function()? clock,
  }) : preferences = preferences ?? SharedPreferencesAsync(),
       clock = clock ?? DateTime.now;

  static const enabledKey = 'news_notifications_enabled';
  static const sinceKey = 'news_notifications_since';
  static const seenKey = 'news_notifications_seen_v1';
  static const lastCheckKey = 'news_notifications_last_check';
  final Future<List<NewsArticle>> Function() fetch;
  final Future<void> Function(List<NewsArticle>) notify;
  final SharedPreferencesAsync preferences;
  final DateTime Function() clock;

  Future<void> run() async {
    if (!(await preferences.getBool(enabledKey) ?? false)) return;
    final now = clock().toUtc();
    final since = DateTime.tryParse(
      await preferences.getString(sinceKey) ?? '',
    );
    if (since == null) {
      // Establish a baseline, including on upgraded or damaged installations.
      await preferences.setString(sinceKey, now.toIso8601String());
      return;
    }
    final articles = await fetch(); // Failed fetches leave all state intact.
    final raw = await preferences.getString(seenKey);
    final seen = <String, DateTime>{};
    if (raw != null) {
      try {
        final values = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in values.entries) {
          final timestamp = DateTime.tryParse('${entry.value}');
          if (timestamp != null &&
              now.difference(timestamp) < const Duration(days: 7)) {
            seen[entry.key] = timestamp;
          }
        }
      } catch (_) {
        // Recover safely without redisplaying already-notified headlines.
        await preferences.setString(sinceKey, now.toIso8601String());
        await preferences.setString(seenKey, '{}');
        await preferences.setString(lastCheckKey, now.toIso8601String());
        return;
      }
    }
    final cutoff = now.subtract(const Duration(hours: 24));
    final unique = <String, NewsArticle>{};
    for (final article in articles) {
      if (article.hasPublicationDate &&
          article.publishedAt.isAfter(since) &&
          !article.publishedAt.isBefore(cutoff) &&
          !article.publishedAt.isAfter(now) &&
          !seen.containsKey(article.url)) {
        unique.putIfAbsent(article.url, () => article);
      }
    }
    final fresh = unique.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    // Recheck after network I/O so switching notifications off takes effect.
    if (!(await preferences.getBool(enabledKey) ?? false)) return;
    if (fresh.isNotEmpty) {
      await notify(fresh);
      // Only acknowledge successfully delivered notifications.
      for (final article in fresh) {
        seen[article.url] = now;
      }
    }
    await preferences.setString(
      seenKey,
      jsonEncode({
        for (final entry in seen.entries)
          entry.key: entry.value.toIso8601String(),
      }),
    );
    await preferences.setString(lastCheckKey, now.toIso8601String());
  }
}
