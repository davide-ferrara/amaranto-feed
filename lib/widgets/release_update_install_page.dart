import 'dart:io';

import 'package:flutter/material.dart';

import '../services/release_update_installer.dart';
import '../services/release_update_service.dart';
import '../theme/app_theme.dart';

class ReleaseUpdateInstallPage extends StatefulWidget {
  const ReleaseUpdateInstallPage({required this.update, super.key});

  final ReleaseUpdate update;

  @override
  State<ReleaseUpdateInstallPage> createState() =>
      _ReleaseUpdateInstallPageState();
}

class _ReleaseUpdateInstallPageState extends State<ReleaseUpdateInstallPage> {
  final _installer = ReleaseUpdateInstaller();
  File? _apk;
  bool _busy = false;
  String? _message;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _apk = null;
      _busy = true;
      _message = 'Download dell’aggiornamento…';
    });
    try {
      final result = await _installer.downloadAndInstall(widget.update);
      _apk = File(
        '${Directory.systemTemp.path}/updates/amaranto-feed-${widget.update.version}.apk',
      );
      if (!mounted) return;
      setState(() {
        _message = result == ApkInstallResult.permissionRequired
            ? 'Consenti ad Amaranto Feed di installare app da questa origine. '
                  'Poi torna qui e tocca “Installa aggiornamento”.'
            : 'Conferma l’installazione nella schermata di Android.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Download o installazione non riusciti. Riprova.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installDownloaded() async {
    final apk = _apk;
    if (apk == null || !await apk.exists()) {
      await _downloadAndInstall();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _installer.install(apk);
      if (mounted) {
        setState(() {
          _message = result == ApkInstallResult.permissionRequired
              ? 'Consenti l’installazione da questa origine nelle impostazioni, '
                    'poi torna qui e riprova.'
              : 'Conferma l’installazione nella schermata di Android.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Impossibile aprire l’installer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _installer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.isDark(context)
          ? null
          : Theme.of(context).scaffoldBackgroundColor,
      gradient: AppTheme.isDark(context) ? AppPalette.amarantoGradient : null,
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Aggiornamento'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Amaranto Feed ${widget.update.version}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  _message ??
                      'Scarica l’APK e completa l’aggiornamento con Android.',
                  textAlign: TextAlign.center,
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _installDownloaded,
                    icon: const Icon(Icons.install_mobile_rounded),
                    label: Text(
                      _apk == null
                          ? 'Scarica e installa'
                          : 'Installa aggiornamento',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
