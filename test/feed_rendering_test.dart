import 'dart:async';
import 'dart:convert';

import 'package:amaranto_feed/main.dart';
import 'package:amaranto_feed/models/news_article.dart';
import 'package:amaranto_feed/services/lnd_data_service.dart';
import 'package:amaranto_feed/services/news_feed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lnd_fixture.dart';

class _FeedService extends NewsFeedService {
  int calls = 0;
  Completer<List<NewsArticle>>? refresh;
  final articles = List.generate(
    40,
    (index) => NewsArticle(
      title: 'Notizia $index',
      url: 'https://example.org/$index',
      source: 'Fonte',
      publishedAt: DateTime.utc(2026, 10, 31),
    ),
  );

  @override
  Future<List<NewsArticle>> fetchLatest({bool forceRefresh = false}) {
    calls++;
    return forceRefresh && refresh != null
        ? refresh!.future
        : Future.value(articles);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('news cards are lazy and remain visible during refresh', (
    tester,
  ) async {
    final feed = _FeedService();
    final lnd = LndDataService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(lndPage()), 200),
      ),
    );
    addTearDown(feed.close);
    addTearDown(lnd.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedPage(lndService: lnd, feedService: feed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialCount = tester.widgetList(find.byType(NewsArticleCard)).length;
    expect(initialCount, greaterThan(0));
    expect(
      initialCount,
      lessThan(8),
      reason: 'offscreen cards must not be eagerly built',
    );
    expect(find.text('Notizia 39'), findsNothing);

    // The floating banner reacts to scroll without replacing the feed.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(feed.calls, 1);
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();

    feed.refresh = Completer<List<NewsArticle>>();
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Notizia 0'), findsOneWidget);
    feed.refresh!.complete(feed.articles);
    await tester.pumpAndSettle();
    await refresh;
    expect(feed.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to news retains scroll position and loaded data', (
    tester,
  ) async {
    final feed = _FeedService();
    final lnd = LndDataService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(lndPage()), 200),
      ),
    );
    final pages = PageController();
    addTearDown(feed.close);
    addTearDown(lnd.close);
    addTearDown(pages.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageView(
            controller: pages,
            children: [
              FeedPage(lndService: lnd, feedService: feed),
              const SizedBox(),
              const SizedBox(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    final offset = scrollable.position.pixels;
    pages.jumpToPage(2);
    await tester.pumpAndSettle();
    pages.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(feed.calls, 1);
    expect(scrollable.mounted, isTrue);
    expect(scrollable.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browser initialization errors offer retry and back navigation', (
    tester,
  ) async {
    final article = _FeedService().articles.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, animation, secondaryAnimation) =>
                    ArticlePage(article: article),
              ),
            ),
            child: const Text('Apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Riprova'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'an unavailable native browser must show a recoverable error',
    );
    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();
    expect(find.text('Apri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
