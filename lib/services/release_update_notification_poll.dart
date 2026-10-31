import 'package:shared_preferences/shared_preferences.dart';

import 'release_update_service.dart';

/// WorkManager runs at the RSS cadence; this gate limits GitHub checks to hourly.
class ReleaseUpdateNotificationPoll {
  ReleaseUpdateNotificationPoll({
    required this.check,
    required this.notify,
    SharedPreferencesAsync? preferences,
    DateTime Function()? clock,
  }) : preferences = preferences ?? SharedPreferencesAsync(),
       clock = clock ?? DateTime.now;

  static const _lastCheckKey = 'release_update_last_check';
  static const _notifiedVersionKey = 'release_update_notified_version';

  final Future<ReleaseUpdate?> Function(String installedVersion) check;
  final Future<void> Function(ReleaseUpdate update) notify;
  final SharedPreferencesAsync preferences;
  final DateTime Function() clock;

  Future<void> run({required String installedVersion}) async {
    final now = clock().toUtc();
    final lastCheck = DateTime.tryParse(
      await preferences.getString(_lastCheckKey) ?? '',
    );
    if (lastCheck != null &&
        now.difference(lastCheck) < const Duration(hours: 1)) {
      return;
    }

    final update = await check(installedVersion);
    if (update != null) {
      final notifiedVersion = await preferences.getString(_notifiedVersionKey);
      if (notifiedVersion != update.version) {
        await notify(update);
        await preferences.setString(_notifiedVersionKey, update.version);
      }
    } else if (await preferences.getString(_notifiedVersionKey) ==
        installedVersion) {
      await preferences.remove(_notifiedVersionKey);
    }
    await preferences.setString(_lastCheckKey, now.toIso8601String());
  }
}
