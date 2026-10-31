import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/news_article.dart';
import 'news_feed_service.dart';
import 'news_notification_poll.dart';

const newsCheckTask = 'it.davideferrara.amarantofeed.rss_check';
const _channel = AndroidNotificationChannel(
  'reggina_news',
  'Notizie Reggina',
  description: 'Nuove notizie dalle fonti RSS sulla Reggina',
  importance: Importance.defaultImportance,
);
const _settings = InitializationSettings(
  android: AndroidInitializationSettings('ic_news_notification'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);

@pragma('vm:entry-point')
void newsCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if (task != newsCheckTask) return true;
    final plugin = FlutterLocalNotificationsPlugin();
    final feed = NewsFeedService();
    try {
      await plugin.initialize(settings: _settings);
      if (!await _permissionGranted(plugin)) return true;
      await NewsNotificationPoll(
        fetch: feed.fetchLatest,
        notify: (articles) => _showNews(plugin, articles),
      ).run();
      debugPrint('RSS background check completed');
      return true;
    } catch (error, stack) {
      debugPrint('RSS background check failed: $error\n$stack');
      return false; // WorkManager retries transient errors with backoff.
    } finally {
      feed.close();
    }
  });
}

Future<bool> _permissionGranted(FlutterLocalNotificationsPlugin plugin) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }
  return (await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions())
          ?.isEnabled ??
      false;
}

Future<void> _showNews(
  FlutterLocalNotificationsPlugin plugin,
  List<NewsArticle> articles,
) async {
  final latest = articles.first;
  final title = articles.length == 1
      ? latest.source
      : '${articles.length} nuove notizie sulla Reggina';
  await plugin.show(
    id: 1914,
    title: title,
    body: latest.title,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        styleInformation: articles.length == 1
            ? BigTextStyleInformation(latest.title)
            : InboxStyleInformation(
                articles
                    .take(5)
                    .map((article) => '${article.source}: ${article.title}')
                    .toList(),
                contentTitle: title,
                summaryText: 'Tocca per leggere l’ultima notizia',
              ),
        onlyAlertOnce: true,
      ),
      iOS: const DarwinNotificationDetails(threadIdentifier: 'reggina_news'),
    ),
    payload: jsonEncode({
      'title': latest.title,
      'url': latest.url,
      'source': latest.source,
      'published_at': latest.publishedAt.toIso8601String(),
    }),
  );
}

class NewsNotifications extends ChangeNotifier {
  NewsNotifications._();
  static final instance = NewsNotifications._();
  final _plugin = FlutterLocalNotificationsPlugin();
  final _preferences = SharedPreferencesAsync();
  bool enabled = false;
  bool permissionGranted = false;
  bool ready = false;
  bool busy = false;
  String? error;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize(void Function(NewsArticle) onOpen) async {
    if (!supported) return;
    try {
      void open(String? payload) {
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final uri = Uri.parse(data['url'] as String);
          if (uri.scheme != 'https' && uri.scheme != 'http') return;
          onOpen(
            NewsArticle(
              title: data['title'] as String,
              url: uri.toString(),
              source: data['source'] as String,
              publishedAt: DateTime.parse(data['published_at'] as String),
            ),
          );
        } catch (_) {
          // Ignore obsolete or invalid notification payloads.
        }
      }

      await _plugin.initialize(
        settings: _settings,
        onDidReceiveNotificationResponse: (response) => open(response.payload),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      await Workmanager().initialize(newsCallbackDispatcher);
      enabled =
          await _preferences.getBool(NewsNotificationPoll.enabledKey) ?? true;
      if (await _preferences.getString(NewsNotificationPoll.sinceKey) == null) {
        await _preferences.setString(
          NewsNotificationPoll.sinceKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
      await _preferences.setBool(NewsNotificationPoll.enabledKey, enabled);
      permissionGranted = await _permissionGranted(_plugin);
      ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        open(launch?.notificationResponse?.payload);
      }
      if (enabled &&
          !(await _preferences.getBool(
                'news_notification_permission_requested',
              ) ??
              false)) {
        await _requestPermission();
      }
      await _schedule();
    } catch (failure, stack) {
      error =
          'Non riesco ad attivare le notifiche. Riapri l’app per riprovare.';
      debugPrint('Notification setup failed: $failure\n$stack');
    }
    notifyListeners();
  }

  Future<void> _requestPermission() async {
    await _preferences.setBool('news_notification_permission_requested', true);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: true);
    }
    permissionGranted = await _permissionGranted(_plugin);
  }

  Future<void> setEnabled(bool value) async {
    if (!ready || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final hadPermission = permissionGranted;
      if (value && !permissionGranted) await _requestPermission();
      if (value && (!enabled || !hadPermission)) {
        await _preferences.setString(
          NewsNotificationPoll.sinceKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
      enabled = value;
      await _preferences.setBool(NewsNotificationPoll.enabledKey, value);
      await _schedule();
      if (!value) await _plugin.cancel(id: 1914);
    } catch (failure) {
      error = 'Non riesco a salvare le notifiche. Riprova.';
      debugPrint('Notification settings failed: $failure');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshPermission() async {
    if (!ready || busy) return;
    try {
      final previouslyGranted = permissionGranted;
      permissionGranted = await _permissionGranted(_plugin);
      if (!previouslyGranted && permissionGranted && enabled) {
        await _preferences.setString(
          NewsNotificationPoll.sinceKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
      await _schedule();
      notifyListeners();
    } catch (failure) {
      debugPrint('Notification permission refresh failed: $failure');
    }
  }

  Future<void> _schedule() async {
    if (!enabled || !permissionGranted) {
      await Workmanager().cancelByUniqueName(newsCheckTask);
      return;
    }
    await Workmanager().registerPeriodicTask(
      newsCheckTask,
      newsCheckTask,
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }
}
