import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/release_update_service.dart';
import '../theme/app_theme.dart';
import 'release_update_install_page.dart';

class ReleaseUpdateButton extends StatefulWidget {
  const ReleaseUpdateButton({
    super.key,
    this.service,
    this.versionLoader,
    this.openDownload,
  });

  final ReleaseUpdateService? service;
  final Future<String> Function()? versionLoader;
  final Future<bool> Function(Uri)? openDownload;

  @override
  State<ReleaseUpdateButton> createState() => _ReleaseUpdateButtonState();
}

class _ReleaseUpdateButtonState extends State<ReleaseUpdateButton>
    with WidgetsBindingObserver {
  late final ReleaseUpdateService _service =
      widget.service ?? ReleaseUpdateService();
  ReleaseUpdate? _update;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final version = widget.versionLoader != null
          ? await widget.versionLoader!()
          : (await PackageInfo.fromPlatform()).version;
      final update = await _service.check(installedVersion: version);
      if (mounted) setState(() => _update = update);
    } on Exception {
      // Package information or networking may be unavailable during startup.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _download() async {
    final update = _update;
    if (update == null || _opening) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      if (widget.openDownload != null) {
        opened = await widget.openDownload!(update.downloadUrl);
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ReleaseUpdateInstallPage(update: update),
          ),
        );
        opened = true;
      }
    } on Exception {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile avviare il download. Riprova.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_update == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton.filled(
        tooltip: 'Scarica aggiornamento ${_update!.version}',
        onPressed: _opening ? null : _download,
        style: IconButton.styleFrom(
          backgroundColor: AppPalette.gold,
          foregroundColor: AppPalette.amarantoDark,
        ),
        icon: const Icon(Icons.system_update_rounded),
      ),
    );
  }
}
