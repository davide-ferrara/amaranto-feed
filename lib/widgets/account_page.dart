import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import '../theme/app_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _busy = false;

  Future<void> _signOut() => _runAccountAction(
    GoogleAuthService.instance.signOut,
    'Disconnessione completata.',
  );

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare l’account?'),
        content: const Text(
          'L’account Firebase Authentication verrà eliminato definitivamente. '
          'Questa operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAccountAction(
      GoogleAuthService.instance.deleteAccount,
      'Account eliminato.',
    );
  }

  Future<void> _runAccountAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _showMessage(successMessage);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage(
          error.code == 'requires-recent-login'
              ? 'Accedi di nuovo e riprova.'
              : 'Impossibile completare l’operazione. Riprova.',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Impossibile completare l’operazione.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
      ),
      body: !widget.firebaseReady
          ? const Center(child: Text('Firebase non è disponibile.'))
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = snapshot.data;
                if (user == null) {
                  return const _AccountMessage(
                    icon: Icons.person_off_outlined,
                    message: 'Accedi con Google dalla scheda Chat.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _AccountPanel(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundImage: user.photoURL == null
                                ? null
                                : NetworkImage(user.photoURL!),
                            child: user.photoURL == null
                                ? const Icon(Icons.person_rounded, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName?.trim().isNotEmpty == true
                                      ? user.displayName!.trim()
                                      : 'Account Google',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                if (user.email != null)
                                  Text(
                                    user.email!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AccountPanel(
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _signOut,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Esci'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _busy ? null : _deleteAccount,
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Elimina account'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                            ),
                          ),
                          if (_busy) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    ),
  );
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.subtlePanel(context, 18),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _AccountMessage extends StatelessWidget {
  const _AccountMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
