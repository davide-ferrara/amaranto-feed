import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgn_news/models/news_article.dart';
import 'package:rgn_news/services/news_notification_poll.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryPreferences implements SharedPreferencesAsync {
  final values = <String, Object>{};
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.utc(2026, 10, 31, 12);
  late MemoryPreferences storage;
  late List<NewsArticle> feed;
  late List<List<NewsArticle>> notifications;
  late NewsNotificationPoll poll;

  NewsArticle article(String id, DateTime date, {bool dated = true}) =>
      NewsArticle(
        title: id,
        url: 'https://example.org/$id',
        source: 'Fonte',
        publishedAt: date,
        hasPublicationDate: dated,
      );

  setUp(() {
    storage = MemoryPreferences();
    storage.values[NewsNotificationPoll.enabledKey] = true;
    storage.values[NewsNotificationPoll.sinceKey] = now
        .subtract(const Duration(hours: 2))
        .toIso8601String();
    notifications = [];
    feed = [];
    poll = NewsNotificationPoll(
      preferences: storage,
      clock: () => now,
      fetch: () async => feed,
      notify: (articles) async => notifications.add(articles),
    );
  });

  test('notifies recent unseen articles once, deduplicates URLs and sorts newest first', () async {
    final older = article('one', now.subtract(const Duration(hours: 1)));
    final newer = article('two', now.subtract(const Duration(minutes: 1)));
    feed = [older, newer, older];
    await poll.run();
    await poll.run();
    expect(notifications.length, 1);
    expect(notifications.single.map((item) => item.title), ['two', 'one']);
    expect(
      storage.values[NewsNotificationPoll.lastCheckKey],
      now.toIso8601String(),
    );
    final restarted = NewsNotificationPoll(
      preferences: storage,
      clock: () => now,
      fetch: () async => feed,
      notify: (articles) async => notifications.add(articles),
    );
    await restarted.run();
    expect(notifications.length, 1);
  });

  test('ignores articles before enabling, older than 24 hours, undated and future items', () async {
    feed = [
      article('old', now.subtract(const Duration(days: 2))),
      article('before-enabled', now.subtract(const Duration(hours: 3))),
      article('future', now.add(const Duration(hours: 1))),
      article(
        'undated',
        now.subtract(const Duration(minutes: 1)),
        dated: false,
      ),
    ];
    await poll.run();
    expect(notifications, isEmpty);
  });

  test(
    'first run establishes baseline without a historical notification burst',
    () async {
      storage.values.remove(NewsNotificationPoll.sinceKey);
      feed = [article('existing', now.subtract(const Duration(minutes: 1)))];
      await poll.run();
      expect(notifications, isEmpty);
      expect(
        storage.values[NewsNotificationPoll.sinceKey],
        now.toIso8601String(),
      );
    },
  );

  test('disabled checks perform no network requests', () async {
    storage.values[NewsNotificationPoll.enabledKey] = false;
    final disabled = NewsNotificationPoll(
      preferences: storage,
      clock: () => now,
      fetch: () async => throw StateError('Must not fetch'),
      notify: (_) async => fail('Must not notify'),
    );
    await disabled.run();
  });

  test(
    'fetch and notification failures preserve unseen articles for retry',
    () async {
      final failedFetch = NewsNotificationPoll(
        preferences: storage,
        clock: () => now,
        fetch: () async => throw StateError('offline'),
        notify: (_) async {},
      );
      await expectLater(failedFetch.run(), throwsStateError);
      expect(storage.values[NewsNotificationPoll.lastCheckKey], isNull);
      feed = [article('retry-me', now.subtract(const Duration(minutes: 1)))];
      final failedNotify = NewsNotificationPoll(
        preferences: storage,
        clock: () => now,
        fetch: () async => feed,
        notify: (_) async => throw StateError('failed'),
      );
      await expectLater(failedNotify.run(), throwsStateError);
      expect(storage.values[NewsNotificationPoll.seenKey], isNull);
      await poll.run();
      expect(notifications.single.single.title, 'retry-me');
    },
  );

  test('recovered sources are checked against URLs, not a global high-water timestamp', () async {
    feed = [article('source-one', now.subtract(const Duration(minutes: 10)))];
    await poll.run();
    feed.add(
      article('recovered-source', now.subtract(const Duration(minutes: 30))),
    );
    await poll.run();
    expect(notifications.last.single.title, 'recovered-source');
    final seen = jsonDecode(
      storage.values[NewsNotificationPoll.seenKey] as String,
    ) as Map;
    expect(seen.length, 2);
  });

  test('switching off during a fetch prevents notification delivery', () async {
    final changed = NewsNotificationPoll(
      preferences: storage,
      clock: () => now,
      fetch: () async {
        storage.values[NewsNotificationPoll.enabledKey] = false;
        return [article('new', now.subtract(const Duration(minutes: 1)))];
      },
      notify: (_) async => fail('Must not notify'),
    );
    await changed.run();
    expect(storage.values[NewsNotificationPoll.seenKey], isNull);
  });
  test(
    'a corrupt seen cache recovers without resending historical stories',
    () async {
      storage.values[NewsNotificationPoll.seenKey] = '{damaged';
      feed = [
        article('already-published', now.subtract(const Duration(minutes: 1))),
      ];
      await poll.run();
      expect(notifications, isEmpty);
      expect(storage.values[NewsNotificationPoll.seenKey], '{}');
      expect(
        storage.values[NewsNotificationPoll.sinceKey],
        now.toIso8601String(),
      );
    },
  );
}
