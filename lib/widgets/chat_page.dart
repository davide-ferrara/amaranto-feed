import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import '../theme/app_theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _busy = false;

  Future<void> _signIn() => _runAuthAction(() async {
    await GoogleAuthService.instance.signIn();
  });

  Future<void> _signOut() => _runAuthAction(GoogleAuthService.instance.signOut);

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accesso non riuscito: ${_message(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) {
    final message = error.toString();
    if (message.contains('canceled')) return 'sign-in was canceled';
    if (message.contains('Web OAuth client')) {
      return 'check Google Sign-In setup and update google-services.json';
    }
    return 'check the setup and try again';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseReady) {
      return const _ChatMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Chat non configurata',
        message: 'Firebase non è disponibile.',
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data;
        if (user == null) return _SignInView(busy: _busy, onSignIn: _signIn);
        return _SignedInView(user: user, busy: _busy, onSignOut: _signOut);
      },
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView({required this.busy, required this.onSignIn});

  final bool busy;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => _ChatMessage(
    icon: Icons.forum_outlined,
    title: 'Chat',
    message: 'Accedi con Google per partecipare alla chat.',
    action: FilledButton.icon(
      onPressed: busy ? null : onSignIn,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login_rounded),
      label: const Text('Continua con Google'),
    ),
  );
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({
    required this.user,
    required this.busy,
    required this.onSignOut,
  });

  final User user;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => _ChatMessage(
    icon: Icons.verified_user_outlined,
    title: 'Ciao ${user.displayName ?? user.email ?? 'tifoso'}',
    message: 'Hai effettuato l’accesso. La chat sarà disponibile qui.',
    action: OutlinedButton.icon(
      onPressed: busy ? null : onSignOut,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout_rounded),
      label: const Text('Esci'),
    ),
  );
}

class _ChatMessage extends StatelessWidget {
  const _ChatMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
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
                    ? colors.surface
                    : colors.surfaceContainerHighest,
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
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
