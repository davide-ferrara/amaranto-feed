import 'package:flutter/material.dart';

import '../services/news_notifications.dart';
import '../theme/app_theme.dart';

class NewsNotificationSettings extends StatelessWidget {
  const NewsNotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = NewsNotifications.instance;
    if (!notifications.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: notifications,
      builder: (context, _) => Container(
        decoration: AppTheme.subtlePanel(context, 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Notizie in background'),
                secondary: const Icon(Icons.notifications_outlined),
                subtitle: const Text(
                  'Avvisami quando arrivano nuove notizie RSS.',
                ),
                value: notifications.enabled && notifications.permissionGranted,
                onChanged: notifications.ready && !notifications.busy
                    ? notifications.setEnabled
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Controllo ogni 30 minuti circa, con connessione internet. Il sistema può posticiparlo per risparmiare batteria.',
                ),
              ),
              if (notifications.enabled &&
                  !notifications.permissionGranted &&
                  notifications.ready)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Consenti le notifiche quando richiesto. Se sono bloccate, abilita le notifiche di Amaranto Feed nelle impostazioni del dispositivo.',
                  ),
                ),
              if (notifications.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    notifications.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
