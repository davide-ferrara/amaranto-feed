import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chat_username_settings.dart';
import 'news_notification_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
        title: const Text('Impostazioni'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _SettingsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6_rounded),
                    const SizedBox(width: 12),
                    Text(
                      'Aspetto',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Per impostazione predefinita segue il dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistema'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Chiaro'),
                    ),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Scuro')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) {
                    onThemeModeChanged(selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ChatUsernameSettings(),
          const SizedBox(height: 16),
          const NewsNotificationSettings(),
        ],
      ),
    ),
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.subtlePanel(context, 18),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: child,
  );
}
