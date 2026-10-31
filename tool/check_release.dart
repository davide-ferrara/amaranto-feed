import 'dart:io';

import '../lib/services/release_update_service.dart';

/// Exercise the same public update check used by the app.
Future<void> main(List<String> arguments) async {
  final installed = arguments.isEmpty ? '0.0.0' : arguments.single;
  final service = ReleaseUpdateService();
  try {
    final update = await service.check(installedVersion: installed);
    if (update == null) {
      stdout.writeln('No newer published APK for $installed.');
    } else {
      stdout.writeln('Update available: ${update.version}');
      stdout.writeln(update.downloadUrl);
    }
  } finally {
    service.close();
  }
}
