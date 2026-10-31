import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/news_article.dart';
import 'models/lnd_data.dart';
import 'services/lnd_data_service.dart';
import 'services/news_feed_service.dart';
import 'services/news_fallback_images.dart';
import 'services/news_notifications.dart';
import 'widgets/release_update_button.dart';
import 'widgets/chat_page.dart';
import 'widgets/settings_page.dart';
import 'widgets/account_page.dart';
import 'widgets/auth_entry_gate.dart';
import 'theme/app_theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } on Exception catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }
  runApp(AmarantoFeedApp(firebaseReady: firebaseReady));
}

class AmarantoFeedApp extends StatefulWidget {
  const AmarantoFeedApp({this.firebaseReady = false, super.key});

  final bool firebaseReady;

  @override
  State<AmarantoFeedApp> createState() => _AmarantoFeedAppState();
}

class _AmarantoFeedAppState extends State<AmarantoFeedApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NewsNotifications.instance.initialize((article) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => ArticlePage(article: article),
          ),
        );
      });
    });
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        final stored = prefs.getString('theme_mode');
        final legacyDark = prefs.getBool('dark_mode') ?? false;
        setState(() {
          _themeMode = stored == 'light'
              ? ThemeMode.light
              : stored == 'dark' || (stored == null && legacyDark)
              ? ThemeMode.dark
              : ThemeMode.system;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NewsNotifications.instance.refreshPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() => _themeMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', value.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amaranto Feed',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AuthEntryGate(
        firebaseReady: widget.firebaseReady,
        appBuilder: (_) => AppShell(
          themeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
          firebaseReady: widget.firebaseReady,
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.firebaseReady,
    super.key,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool firebaseReady;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _feedIndex = 2;
  int _selectedIndex = _feedIndex;
  final GlobalKey<_FeedPageState> _feedKey = GlobalKey<_FeedPageState>();
  late final PageController _pageController = PageController(
    initialPage: _feedIndex,
  );
  final LndDataService _lndService = LndDataService();

  @override
  void dispose() {
    _pageController.dispose();
    _lndService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showGradient = AppTheme.isDark(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: showGradient ? AppPalette.amarantoGradient : null,
        ),
        child: SafeArea(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            children: [
              ChatPage(firebaseReady: widget.firebaseReady),
              LndFixturesPage(service: _lndService),
              FeedPage(key: _feedKey, lndService: _lndService),
              LndStandingsPage(service: _lndService),
              ProfilePage(
                themeMode: widget.themeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
                firebaseReady: widget.firebaseReady,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onSelected: _onNavigationSelected,
      ),
    );
  }

  Future<void> _onNavigationSelected(int index) async {
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    if (index == _feedIndex) {
      await _feedKey.currentState?.scrollToTopAndRefresh();
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.forum_outlined, Icons.forum_rounded, 'Chat'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Calendario'),
    (Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, 'Notizie'),
    (Icons.leaderboard_outlined, Icons.leaderboard_rounded, 'Classifica'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profilo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppPalette.amarantoGradient),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _BottomNavItem(
                    icon: _items[index].$1,
                    selectedIcon: _items[index].$2,
                    label: _items[index].$3,
                    selected: index == selectedIndex,
                    emphasized: _items[index].$3 == 'Feed',
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.emphasized,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 32,
                decoration: selected
                    ? const BoxDecoration(
                        gradient: AppPalette.goldGradient,
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      )
                    : null,
                alignment: Alignment.center,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: emphasized ? 29 : 23,
                  color: selected ? AppPalette.amaranto : AppPalette.navMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppPalette.navMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({required this.lndService, super.key});

  final LndDataService lndService;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();
  late final NewsFeedService _feedService;
  final NewsFallbackImages _fallbackImages = NewsFallbackImages();
  late Future<List<NewsArticle>> _articles;
  late Future<LndDataSnapshot> _sportsData;
  Future<void>? _refreshTask;
  bool _showMatchBanner = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _feedService = NewsFeedService();
    _articles = _feedService.fetchLatest();
    _sportsData = widget.lndService.load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedService.close();
    super.dispose();
  }

  Future<void> scrollToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    await _refreshFromGesture();
  }

  void _refresh() {
    setState(() => _articles = _feedService.fetchLatest());
  }

  Future<void> _refreshFromGesture() {
    return _refreshTask ??= _performRefresh().whenComplete(() {
      _refreshTask = null;
    });
  }

  Future<void> _performRefresh() async {
    final refresh = _feedService.fetchLatest();
    setState(() {
      _articles = refresh;
    });
    await refresh;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != null &&
        notification.metrics.axis == Axis.vertical) {
      final nextOffset = notification.metrics.pixels;
      final movingDown = nextOffset > _lastScrollOffset;
      if (nextOffset < 24 || !movingDown) {
        if (!_showMatchBanner) setState(() => _showMatchBanner = true);
      } else if (_showMatchBanner && nextOffset > 80) {
        setState(() => _showMatchBanner = false);
      }
      _lastScrollOffset = nextOffset;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<LndDataSnapshot>(
      future: _sportsData,
      builder: (context, sportsSnapshot) {
        final fixture = sportsSnapshot.hasData
            ? _nextRegginaFixture(sportsSnapshot.data!.fixtures)
            : null;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? null : Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: RefreshIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onRefresh: _refreshFromGesture,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          isDark ? 20 : 0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isDark ? 4 : 0),
                              decoration: BoxDecoration(
                                color: isDark ? AppPalette.surface : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.asset(
                                'assets/branding/amaranto_feed_mark.png',
                                width: 38,
                                height: 38,
                                excludeFromSemantics: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Amaranto Feed',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : null,
                                    ),
                              ),
                            ),
                            const ReleaseUpdateButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _NewsFeed(
                          future: _articles,
                          onRetry: _refresh,
                          fallbackImages: _fallbackImages,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _NewsAttribution(),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  offset: _showMatchBanner ? Offset.zero : const Offset(0, 1.5),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showMatchBanner ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showMatchBanner,
                      child: MatchMiniBanner(
                        fixture: fixture,
                        isLoading:
                            sportsSnapshot.connectionState ==
                            ConnectionState.waiting,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MatchDetailsPage(
                              fixture: fixture,
                              isLoading:
                                  sportsSnapshot.connectionState ==
                                  ConnectionState.waiting,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NewsFeed extends StatelessWidget {
  const _NewsFeed({
    required this.future,
    required this.onRetry,
    required this.fallbackImages,
  });

  final NewsFallbackImages fallbackImages;

  final Future<List<NewsArticle>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsArticle>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _FeedMessage(
            icon: Icons.wifi_off_rounded,
            text: snapshot.error.toString().replaceFirst('Exception: ', ''),
            action: 'Riprova',
            onPressed: onRetry,
          );
        }

        final articles = snapshot.data ?? const <NewsArticle>[];
        if (articles.isEmpty) {
          return _FeedMessage(
            icon: Icons.article_outlined,
            text: 'Al momento non ci sono notizie disponibili.',
            action: 'Aggiorna',
            onPressed: onRetry,
          );
        }

        return Column(
          children: [
            for (var index = 0; index < articles.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              NewsArticleCard(
                article: articles[index],
                fallbackImages: fallbackImages,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.panel(context, 20),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 9),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          TextButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    );
  }
}

class NewsArticleCard extends StatelessWidget {
  const NewsArticleCard({
    required this.article,
    required this.fallbackImages,
    super.key,
  });

  final NewsArticle article;
  final NewsFallbackImages fallbackImages;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: isDark
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArticlePage(article: article),
          ),
        ),
        borderRadius: BorderRadius.circular(23),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: isDark ? AppPalette.amarantoGradient : null,
            borderRadius: BorderRadius.circular(23),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: isDark
                  ? AppPalette.gold
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isDark ? 1.25 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null)
                Image.network(
                  article.imageUrl!,
                  height: 156,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _NewsImagePlaceholder(
                        imagePath: fallbackImages.forArticle(article.url),
                      ),
                )
              else
                _NewsImagePlaceholder(
                  imagePath: fallbackImages.forArticle(article.url),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  article.source.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : AppPalette.amaranto,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                              ),
                              if (article.isOfficial) ...[
                                const SizedBox(width: 5),
                                const Tooltip(
                                  message: 'Fonte ufficiale',
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: AppPalette.goldDark,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatPublishedAt(article.publishedAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: secondaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Leggi dalla fonte',
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: secondaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      height: 156,
      width: double.infinity,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
  }
}

class ArticlePage extends StatefulWidget {
  const ArticlePage({required this.article, super.key});

  final NewsArticle article;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.article.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notizia'),
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

String _formatPublishedAt(DateTime value) {
  const months = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

LeagueFixture? _nextRegginaFixture(List<LeagueFixture> fixtures) {
  final regginaFixtures = fixtures.where((fixture) {
    final home = fixture.homeTeam.toLowerCase();
    final away = fixture.awayTeam.toLowerCase();
    return home.contains('reggina') || away.contains('reggina');
  }).toList();
  if (regginaFixtures.isEmpty) return null;
  final today = DateTime.now();
  final upcoming =
      regginaFixtures.where((fixture) {
        final date = _parseFixtureDate(fixture.date);
        return date != null &&
            !date.isBefore(DateTime(today.year, today.month, today.day));
      }).toList()..sort(
        (a, b) =>
            _parseFixtureDate(a.date)!.compareTo(_parseFixtureDate(b.date)!),
      );
  return upcoming.isNotEmpty ? upcoming.first : regginaFixtures.first;
}

DateTime? _parseFixtureDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return parsed;
  final italian = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$')
      .firstMatch(value.trim());
  if (italian == null) return null;
  return DateTime(
    int.parse(italian.group(3)!),
    int.parse(italian.group(2)!),
    int.parse(italian.group(1)!),
  );
}

String _formatFixtureDate(String value) {
  final parsed = _parseFixtureDate(value);
  if (parsed == null) return value;
  const months = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

class MatchMiniBanner extends StatelessWidget {
  const MatchMiniBanner({
    required this.fixture,
    required this.isLoading,
    required this.onTap,
    super.key,
  });

  final LeagueFixture? fixture;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = fixture == null
        ? (isLoading ? 'Caricamento partita…' : 'Prossima partita')
        : '${_formatFixtureDate(fixture!.date)}${fixture!.time.isEmpty ? '' : ' · ${fixture!.time}'}';
    return Container(
      height: 70,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: AppPalette.goldGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.5),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppPalette.amarantoGradient,
            borderRadius: BorderRadius.circular(16.5),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  _MiniTeam(
                    logoUrl: fixture?.homeLogoUrl,
                    initials: _teamInitials(fixture?.homeTeam ?? 'RGN'),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          fixture == null
                              ? (isLoading
                                    ? 'PROSSIMA PARTITA'
                                    : 'PARTITA NON DISPONIBILE')
                              : '${fixture!.homeTeam}  ·  ${fixture!.awayTeam}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: const TextStyle(
                            color: AppPalette.bannerMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  _MiniTeam(
                    logoUrl: fixture?.awayLogoUrl,
                    initials: _teamInitials(fixture?.awayTeam ?? '—'),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTeam extends StatelessWidget {
  const _MiniTeam({required this.logoUrl, required this.initials});

  final String? logoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      child: logoUrl == null
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppPalette.amaranto,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppPalette.amaranto,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class MatchDetailsPage extends StatelessWidget {
  const MatchDetailsPage({
    required this.fixture,
    required this.isLoading,
    super.key,
  });

  final LeagueFixture? fixture;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final venue = fixture == null
        ? ''
        : (fixture!.venue.isNotEmpty ? fixture!.venue : fixture!.address);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prossima partita'),
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            MatchBanner(fixture: fixture, isLoading: isLoading, onTap: () {}),
            const SizedBox(height: 20),
            _MatchInfoTile(
              icon: Icons.emoji_events_outlined,
              label: 'Competizione',
              value: fixture == null
                  ? 'Serie D · Girone I'
                  : 'Serie D · Girone I · ${fixture!.roundNumber}ª giornata',
            ),
            _MatchInfoTile(
              icon: Icons.calendar_month_rounded,
              label: 'Data e orario',
              value: fixture == null
                  ? 'In aggiornamento'
                  : '${_formatFixtureDate(fixture!.date)}${fixture!.time.isEmpty ? '' : ' · ${fixture!.time}'}',
            ),
            _MatchInfoTile(
              icon: Icons.stadium_outlined,
              label: 'Stadio',
              value: venue.isEmpty ? 'In aggiornamento' : venue,
            ),
            _MatchInfoTile(
              icon: Icons.location_on_outlined,
              label: 'Luogo',
              value: fixture?.address.isNotEmpty == true
                  ? fixture!.address
                  : 'Informazioni non disponibili',
            ),
            const SizedBox(height: 8),
            Text(
              'I dati della partita sono forniti dalla LND e possono essere aggiornati nel corso della stagione.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchInfoTile extends StatelessWidget {
  const _MatchInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: AppTheme.panel(context, 16),
    child: Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MatchBanner extends StatelessWidget {
  const MatchBanner({
    required this.onTap,
    required this.fixture,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback onTap;
  final LeagueFixture? fixture;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppPalette.amarantoGradient,
        boxShadow: const [
          BoxShadow(
            color: AppPalette.brandShadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                right: -35,
                top: -53,
                child: Container(
                  width: 175,
                  height: 175,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppPalette.glass, width: 28),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sports_soccer_rounded,
                          size: 16,
                          color: AppPalette.labelOnBrand,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            fixture == null
                                ? (isLoading
                                      ? 'SERIE D · CARICAMENTO'
                                      : 'SERIE D · PROSSIMA PARTITA')
                                : 'SERIE D · ${fixture!.leg == 'first' ? 'ANDATA' : 'RITORNO'} · ${fixture!.roundNumber}ª GIORNATA',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppPalette.detailOnBrand,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppPalette.goldGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'LND',
                            style: TextStyle(
                              color: AppPalette.amarantoDark,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _TeamColumn(
                            initials: _teamInitials(fixture?.homeTeam ?? '—'),
                            name: fixture?.homeTeam ?? 'In aggiornamento',
                            alignment: CrossAxisAlignment.start,
                            logoUrl: fixture?.homeLogoUrl,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: _VersusBadge(),
                        ),
                        Expanded(
                          child: _TeamColumn(
                            initials: _teamInitials(fixture?.awayTeam ?? '—'),
                            name: fixture?.awayTeam ?? (isLoading ? '…' : '—'),
                            alignment: CrossAxisAlignment.end,
                            logoUrl: fixture?.awayLogoUrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Container(height: 1, color: AppPalette.glassLine),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppPalette.labelOnBrand,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            fixture == null
                                ? (isLoading
                                      ? 'Recupero dati partita…'
                                      : 'Dati partita non disponibili')
                                : '${_formatFixtureDate(fixture!.date)}${fixture!.time.isEmpty ? '' : ' · ${fixture!.time}'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.stadium_outlined,
                          size: 15,
                          color: AppPalette.labelOnBrand,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            fixture == null
                                ? ''
                                : (fixture!.venue.isNotEmpty
                                      ? fixture!.venue
                                      : fixture!.address),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppPalette.captionOnBrand,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: AppPalette.subtleOnBrand,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dettagli della partita',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppPalette.subtleOnBrand,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _teamInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (words.isEmpty) return '—';
  if (words.length == 1) {
    return words.first
        .substring(0, words.first.length.clamp(0, 3))
        .toUpperCase();
  }
  return words.take(3).map((word) => word[0]).join().toUpperCase();
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.initials,
    required this.name,
    required this.alignment,
    this.logoUrl,
  });

  final String initials;
  final String name;
  final CrossAxisAlignment alignment;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          width: 58,
          height: 64,
          decoration: BoxDecoration(
            color: AppPalette.lightTile,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppPalette.lightTileBorder),
          ),
          child: logoUrl == null
              ? _TeamInitials(initials: initials)
              : Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _TeamInitials(initials: initials),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : _TeamInitials(initials: initials),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _TeamInitials extends StatelessWidget {
  const _TeamInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 19, color: AppPalette.amaranto),
        const SizedBox(height: 1),
        Text(
          initials,
          style: const TextStyle(
            color: AppPalette.amaranto,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: AppPalette.goldGradient,
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.goldDark),
      ),
      child: const Center(
        child: Text(
          'VS',
          style: TextStyle(
            color: AppPalette.amaranto,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class NewsMockCard extends StatelessWidget {
  const NewsMockCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppTheme.panel(context, 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 146,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.placeholderTop,
                  AppPalette.placeholderBottom,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 20,
                  top: -32,
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    size: 180,
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'IMMAGINE ANTEPRIMA',
                      style: TextStyle(
                        color: AppPalette.amaranto,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 18,
                  bottom: 13,
                  child: Icon(
                    Icons.image_outlined,
                    size: 25,
                    color: AppPalette.placeholderInk,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ESEMPIO FEED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppPalette.amaranto,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Anteprima',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Qui troverai le ultime notizie sulla Reggina',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Le notizie saranno raccolte dai feed RSS e apriranno la pagina originale della fonte.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewsPreviewRow extends StatelessWidget {
  const NewsPreviewRow({
    required this.category,
    required this.title,
    required this.time,
    required this.icon,
    super.key,
  });

  final String category;
  final String title;
  final String time;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.panel(context, 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppPalette.iconTile,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppPalette.amaranto),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.amaranto,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _NewsAttribution extends StatelessWidget {
  const _NewsAttribution();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Titoli e anteprime dalle fonti · apri ogni articolo sul sito originale',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class LndStandingsPage extends StatefulWidget {
  const LndStandingsPage({required this.service, super.key});
  final LndDataService service;

  @override
  State<LndStandingsPage> createState() => _LndStandingsPageState();
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? AppPalette.amarantoDark
                  : AppPalette.chatIconTile,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 37),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 9),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: AppTheme.panel(context, 30),
            child: Text(
              'IN ARRIVO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.firebaseReady,
    super.key,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
    children: [
      Text(
        'Profilo',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      if (firebaseReady)
        StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final user = snapshot.data;
            if (user == null) {
              return _ProfileAccountCard(
                title: 'Ciao tifoso',
                subtitle: 'Accedi con Google dalla scheda Chat',
                icon: Icons.person_outline_rounded,
              );
            }
            return _ProfileAccountCard(
              title: user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : 'Google account',
              subtitle: user.email ?? '',
              photoUrl: user.photoURL,
              icon: Icons.person_rounded,
              signedIn: true,
            );
          },
        )
      else
        const _ProfileAccountCard(
          title: 'Account non disponibile',
          subtitle: 'Firebase non è connesso',
          icon: Icons.cloud_off_outlined,
        ),
      const SizedBox(height: 16),
      _ProfileNavigationTile(
        icon: Icons.manage_accounts_outlined,
        title: 'Account',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountPage(firebaseReady: firebaseReady),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _ProfileNavigationTile(
        icon: Icons.settings_outlined,
        title: 'Impostazioni',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsPage(
              themeMode: themeMode,
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
        ),
      ),
    ],
  );
}

class _ProfileNavigationTile extends StatelessWidget {
  const _ProfileNavigationTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.isDark(context)
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: AppTheme.isDark(context) ? 0.35 : 1),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.photoUrl,
    this.signedIn = false,
  });

  final String title;
  final String subtitle;
  final String? photoUrl;
  final IconData icon;
  final bool signedIn;

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.subtlePanel(context, 18),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
          child: photoUrl == null ? Icon(icon, size: 30) : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (signedIn) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppTheme.isDark(context)
                          ? AppPalette.gold
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Accesso effettuato con Google',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _LndStandingsPageState extends State<LndStandingsPage> {
  late Future<LndDataSnapshot> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.service.load();
  }

  Future<void> _refresh() async {
    final future = widget.service.load(forceRefresh: true);
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder presents the existing retry state on errors.
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<LndDataSnapshot>(
      future: _data,
      builder: (context, snapshot) {
        final standings = snapshot.data?.standings ?? const <LeagueStanding>[];
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (snapshot.connectionState == ConnectionState.waiting &&
                standings.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError && standings.isEmpty)
              SliverFillRemaining(child: _LndError(onRetry: _refresh))
            else ...[
              SliverToBoxAdapter(
                child: _LndUpdatedLabel(updatedAt: snapshot.data?.updatedAt),
              ),
              SliverToBoxAdapter(child: _StandingsHeader()),
              SliverList.builder(
                itemCount: standings.length,
                itemBuilder: (context, index) =>
                    _StandingRow(standing: standings[index]),
              ),
              const SliverToBoxAdapter(child: _StandingsLegend()),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Text(
                    'Fonte: LND · dati a scopo informativo; fanno fede i Comunicati Ufficiali.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class LndFixturesPage extends StatefulWidget {
  const LndFixturesPage({required this.service, super.key});
  final LndDataService service;
  @override
  State<LndFixturesPage> createState() => _LndFixturesPageState();
}

class _LndFixturesPageState extends State<LndFixturesPage> {
  late Future<LndDataSnapshot> _data;
  int? _selectedRoundNumber;
  String? _selectedLeg;
  @override
  void initState() {
    super.initState();
    _data = widget.service.load();
  }

  Future<void> _refresh() async {
    final future = widget.service.load(
      forceRefresh: true,
      roundNumber: _selectedRoundNumber,
      leg: _selectedLeg ?? 'first',
    );
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder presents the existing retry state on errors.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LndDataSnapshot>(
    future: _data,
    builder: (context, snapshot) {
      final allFixtures = snapshot.data?.fixtures ?? const <LeagueFixture>[];
      final loadedMatch = allFixtures.isEmpty ? null : allFixtures.first;
      final roundNumber = _selectedRoundNumber ?? loadedMatch?.roundNumber;
      final leg = _selectedLeg ?? loadedMatch?.leg;
      final fixtures = roundNumber == null || leg == null
          ? const <LeagueFixture>[]
          : allFixtures
                .where((f) => f.roundNumber == roundNumber && f.leg == leg)
                .toList();
      return RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (snapshot.data != null)
              SliverToBoxAdapter(
                child: _LndUpdatedLabel(updatedAt: snapshot.data?.updatedAt),
              ),
            if (roundNumber != null && leg != null)
              SliverToBoxAdapter(
                child: _MatchdayLabel(
                  roundNumber: roundNumber,
                  leg: leg,
                  onPrevious: leg == 'first' && roundNumber == 1
                      ? null
                      : () => _navigate(roundNumber, leg, -1),
                  onNext: leg == 'second' && roundNumber == 17
                      ? null
                      : () => _navigate(roundNumber, leg, 1),
                ),
              ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                fixtures.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError && fixtures.isEmpty)
              SliverFillRemaining(child: _LndError(onRetry: _refresh))
            else ...[
              SliverList.builder(
                itemCount: fixtures.length,
                itemBuilder: (context, index) =>
                    _FixtureCard(fixture: fixtures[index]),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: Text(
                    'Fonte: LND · dati a scopo informativo; fanno fede i Comunicati Ufficiali.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  void _navigate(int currentNumber, String currentLeg, int delta) {
    var number = currentNumber + delta;
    var leg = currentLeg;
    if (number > 17) {
      number = 1;
      leg = 'second';
    }
    if (number < 1) {
      number = 17;
      leg = 'first';
    }
    final future = widget.service.load(roundNumber: number, leg: leg);
    setState(() {
      _selectedRoundNumber = number;
      _selectedLeg = leg;
      _data = future;
    });
  }
}

class _LndError extends StatelessWidget {
  const _LndError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Non riesco a caricare i dati LND. Controlla la connessione e riprova.',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    ),
  );
}

class _LndUpdatedLabel extends StatelessWidget {
  const _LndUpdatedLabel({required this.updatedAt});
  final DateTime? updatedAt;
  @override
  Widget build(BuildContext context) {
    final value = updatedAt == null
        ? 'Dati LND'
        : 'Aggiornata ${_formatPublishedAt(updatedAt!.toLocal())}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Text(value, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(16, 6, 16, 7),
    child: Row(
      children: [
        SizedBox(width: 34),
        Expanded(child: Text('SQUADRA', style: _tableHead)),
        SizedBox(width: 29, child: Text('PG', style: _tableHead)),
        SizedBox(width: 24, child: Text('V', style: _tableHead)),
        SizedBox(width: 24, child: Text('N', style: _tableHead)),
        SizedBox(width: 24, child: Text('S', style: _tableHead)),
        SizedBox(width: 34, child: Text('DR', style: _tableHead)),
        SizedBox(width: 29, child: Text('PT', style: _tableHead)),
      ],
    ),
  );
}

const _tableHead = TextStyle(fontSize: 9, fontWeight: FontWeight.w800);

class _StandingsLegend extends StatelessWidget {
  const _StandingsLegend();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _StandingsLegendItem(
          color: Color.alphaBlend(
            AppPalette.promotion.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.surface,
          ),
          borderColor: AppPalette.promotion.withValues(alpha: 0.45),
          label: 'Promozione diretta · 1ª',
        ),
        _StandingsLegendItem(
          color: Color.alphaBlend(
            AppPalette.playoff.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.surface,
          ),
          borderColor: AppPalette.playoff.withValues(alpha: 0.45),
          label: 'Playoff · 2ª–5ª',
        ),
        _StandingsLegendItem(
          color: Color.alphaBlend(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.surface,
          ),
          borderColor: Theme.of(context).colorScheme.primary,
          label: 'Reggina',
        ),
      ],
    ),
  );
}

class _StandingsLegendItem extends StatelessWidget {
  const _StandingsLegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color, borderColor;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing});
  final LeagueStanding standing;
  @override
  Widget build(BuildContext context) {
    final isReggina = standing.team.toLowerCase().contains('reggina');
    final isDirectPromotion = !isReggina && standing.position == 1;
    final isPlayoff =
        !isReggina && standing.position >= 2 && standing.position <= 5;
    final rowColor = isReggina
        ? Color.alphaBlend(
            AppPalette.amaranto.withValues(alpha: 0.14),
            Theme.of(context).colorScheme.surface,
          )
        : isPlayoff
        ? Color.alphaBlend(
            AppPalette.playoff.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.surface,
          )
        : isDirectPromotion
        ? Color.alphaBlend(
            AppPalette.promotion.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.surface,
          )
        : Theme.of(context).colorScheme.surface;
    final statusColor = isReggina
        ? (AppTheme.isDark(context) ? AppPalette.gold : AppPalette.amaranto)
        : isPlayoff
        ? AppPalette.playoff
        : isDirectPromotion
        ? AppPalette.promotion
        : Theme.of(context).colorScheme.outlineVariant;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      decoration: BoxDecoration(
        gradient: AppTheme.isDark(context) ? AppPalette.amarantoGradient : null,
        color: AppTheme.isDark(context) ? null : rowColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.isDark(context)
              ? Theme.of(context).colorScheme.outlineVariant
              : statusColor.withValues(alpha: 0.55),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 29,
            child: Text(
              '${standing.position}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isReggina || isPlayoff || isDirectPromotion
                    ? statusColor
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _TeamLogo(url: standing.logoUrl, team: standing.team, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              standing.team,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isReggina
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: isReggina ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          _cell('${standing.played}', 29),
          _cell('${standing.wins}', 24),
          _cell('${standing.draws}', 24),
          _cell('${standing.losses}', 24),
          _cell(
            '${standing.goalDifference > 0 ? '+' : ''}${standing.goalDifference}',
            34,
          ),
          _cell('${standing.points}', 29, bold: true),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool bold = false}) => SizedBox(
    width: width,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
      ),
    ),
  );
}

class _MatchdayLabel extends StatelessWidget {
  const _MatchdayLabel({
    required this.roundNumber,
    required this.leg,
    required this.onPrevious,
    required this.onNext,
  });
  final int roundNumber;
  final String leg;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            '${leg == 'first' ? 'Andata' : 'Ritorno'} · $roundNumberª giornata',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({required this.fixture});
  final LeagueFixture fixture;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    padding: const EdgeInsets.all(14),
    decoration: AppTheme.panel(context, 19),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${_formatFixtureDate(fixture.date)}${fixture.time.isEmpty ? '' : ' · ${fixture.time}'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _FixtureTeam(
                name: fixture.homeTeam,
                logo: fixture.homeLogoUrl,
              ),
            ),
            SizedBox(
              width: 58,
              child: Center(
                child: fixture.homeScore != null && fixture.awayScore != null
                    ? Text(
                        '${fixture.homeScore}-${fixture.awayScore}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      )
                    : Text(
                        'VS',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: _FixtureTeam(
                name: fixture.awayTeam,
                logo: fixture.awayLogoUrl,
              ),
            ),
          ],
        ),
        if (fixture.venue.isNotEmpty || fixture.address.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                Icons.stadium_outlined,
                size: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    fixture.venue,
                    fixture.address,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _FixtureTeam extends StatelessWidget {
  const _FixtureTeam({required this.name, required this.logo});
  final String name;
  final String? logo;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _TeamLogo(url: logo, team: name, size: 36),
      const SizedBox(height: 5),
      Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.url, required this.team, required this.size});
  final String? url;
  final String team;
  final double size;

  String? get _assetPath {
    final name = team.toLowerCase();
    if (name.contains('vigor lamezia')) {
      return 'assets/team_logos/vigor_lamezia.png';
    }
    if (name.startsWith('trapani')) {
      return 'assets/team_logos/trapani.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size + 8,
    height: size + 8,
    padding: const EdgeInsets.all(4),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppPalette.teamLogoBackground,
      borderRadius: BorderRadius.circular(size / 4),
    ),
    // Replace faded/off-center source images with unchanged official crests,
    // including when displaying an older cached round.
    child: _assetPath != null
        ? Image.asset(_assetPath!, fit: BoxFit.contain)
        : url == null
        ? Icon(Icons.shield_outlined, color: AppPalette.teamLogoForeground)
        : Image.network(
            url!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.shield_outlined,
              color: AppPalette.teamLogoForeground,
            ),
          ),
  );
}
