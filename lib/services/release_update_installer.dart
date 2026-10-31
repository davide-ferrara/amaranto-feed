import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'release_update_service.dart';

enum ApkInstallResult { installerOpened, permissionRequired }

class ReleaseUpdateInstaller {
  ReleaseUpdateInstaller({http.Client? client})
    : _client = client ?? http.Client();

  static const _channel = MethodChannel('it.davideferrara.amarantofeed/update');
  final http.Client _client;

  void close() => _client.close();

  Future<File> download(ReleaseUpdate update) async {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(update.version) ||
        update.downloadUrl.scheme != 'https' ||
        update.downloadUrl.host != 'github.com' ||
        !update.downloadUrl.path.startsWith(
          '/${ReleaseUpdateService.repository}/releases/download/',
        ) ||
        update.downloadUrl.pathSegments.length != 6 ||
        (update.downloadUrl.pathSegments[4] != update.version &&
            update.downloadUrl.pathSegments[4] != 'v${update.version}') ||
        update.downloadUrl.pathSegments[5] !=
            'amaranto-feed-${update.version}.apk') {
      throw const FormatException('Download URL non valido.');
    }
    final directory = Directory('${Directory.systemTemp.path}/updates');
    await directory.create(recursive: true);
    final file = File('${directory.path}/amaranto-feed-${update.version}.apk');
    final response = await _client
        .send(http.Request('GET', update.downloadUrl))
        .timeout(const Duration(minutes: 3));
    if (response.statusCode != HttpStatus.ok) {
      await response.stream.drain<void>();
      throw HttpException(
        'Download APK non riuscito.',
        uri: update.downloadUrl,
      );
    }
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    if (await file.length() == 0) {
      await file.delete();
      throw const FormatException('Il file APK scaricato è vuoto.');
    }
    return file;
  }

  Future<ApkInstallResult> downloadAndInstall(ReleaseUpdate update) async {
    final file = await download(update);
    return install(file);
  }

  Future<ApkInstallResult> install(File file) async {
    final status = await _channel.invokeMethod<String>('installApk', {
      'path': file.path,
    });
    return switch (status) {
      'permission_required' => ApkInstallResult.permissionRequired,
      'installer_opened' => ApkInstallResult.installerOpened,
      _ => throw PlatformException(
        code: 'install_failed',
        message: 'Android non è riuscito ad aprire l’installer.',
      ),
    };
  }
}
