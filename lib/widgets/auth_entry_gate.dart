import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/google_auth_service.dart';
import '../theme/app_theme.dart';

class AuthEntryGate extends StatefulWidget {
  const AuthEntryGate({
    required this.firebaseReady,
    required this.appBuilder,
    super.key,
  });

  final bool firebaseReady;
  final WidgetBuilder appBuilder;

  @override
  State<AuthEntryGate> createState() => _AuthEntryGateState();
}

class _AuthEntryGateState extends State<AuthEntryGate> {
  static const _entryCompletedKey = 'auth_entry_completed';

  bool? _entryCompleted;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) async {
      if (mounted) {
        final hasSignedIn =
            widget.firebaseReady && FirebaseAuth.instance.currentUser != null;
        setState(() {
          _entryCompleted =
              (preferences.getBool(_entryCompletedKey) ?? false) || hasSignedIn;
        });
        if (hasSignedIn) {
          await preferences.setBool(_entryCompletedKey, true);
        }
      }
    });
    if (widget.firebaseReady) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (user != null) _completeEntry();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _completeEntry() async {
    if (_entryCompleted != true) {
      if (mounted) setState(() => _entryCompleted = true);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_entryCompletedKey, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entryCompleted == null) {
      return const _AuthEntryBackground(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!widget.firebaseReady) {
      return _entryCompleted!
          ? widget.appBuilder(context)
          : AuthEntryScreen(firebaseReady: false, onContinue: _completeEntry);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.data != null || _entryCompleted!) {
          return widget.appBuilder(context);
        }
        return AuthEntryScreen(firebaseReady: true, onContinue: _completeEntry);
      },
    );
  }
}

class AuthEntryScreen extends StatefulWidget {
  const AuthEntryScreen({
    required this.firebaseReady,
    required this.onContinue,
    super.key,
  });

  final bool firebaseReady;
  final Future<void> Function() onContinue;

  @override
  State<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends State<AuthEntryScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GoogleAuthService.instance.signIn();
    } catch (error) {
      if (mounted) {
        final details = error.toString();
        setState(() {
          _error = details.contains('canceled')
              ? 'Accesso annullato.'
              : 'Accesso con Google non riuscito. Riprova.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithoutSignIn() async {
    setState(() => _busy = true);
    await widget.onContinue();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final colors = Theme.of(context).colorScheme;
    return _AuthEntryBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(17),
                        child: Image.asset(
                          'assets/branding/amaranto_feed_mark.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'Amaranto Feed',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'La Reggina sempre con te!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: dark
                                  ? AppPalette.detailOnBrand
                                  : colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 38),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _busy || !widget.firebaseReady
                              ? null
                              : _signIn,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Login con Google'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton(
                          onPressed: _busy ? null : _continueWithoutSignIn,
                          child: const Text('Continua senza accesso'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                      if (!widget.firebaseReady) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Accesso Google non disponibile al momento.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: dark
                                    ? AppPalette.subtleOnBrand
                                    : colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthEntryBackground extends StatelessWidget {
  const _AuthEntryBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.isDark(context)
          ? null
          : Theme.of(context).scaffoldBackgroundColor,
      gradient: AppTheme.isDark(context) ? AppPalette.amarantoGradient : null,
    ),
    child: SizedBox.expand(child: child),
  );
}
