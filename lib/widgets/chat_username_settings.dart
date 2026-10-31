import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../theme/app_theme.dart';

class ChatUsernameSettings extends StatefulWidget {
  const ChatUsernameSettings({super.key});

  @override
  State<ChatUsernameSettings> createState() => _ChatUsernameSettingsState();
}

class _ChatUsernameSettingsState extends State<ChatUsernameSettings> {
  final _controller = TextEditingController();
  User? _user;
  bool _loading = true;
  bool _saving = false;
  bool _hasCustomName = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _user = user;
    try {
      final customName = await ChatService.instance.getCustomUserName(user);
      if (!mounted) return;
      _hasCustomName = customName != null;
      _controller.text = customName ?? user.displayName?.trim() ?? '';
    } catch (_) {
      if (!mounted) return;
      _controller.text = user.displayName?.trim() ?? '';
      _showMessage('Impossibile caricare il nome della chat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final user = _user;
    final name = _controller.text.trim();
    if (user == null) return;
    if (!ChatService.isAllowedUserName(name)) {
      _showMessage(
        'Scegli un nome da 1 a 60 caratteri. I nomi Admin, Moderatore, '
        'Staff, Ufficiale e Sistema sono riservati.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ChatService.instance.setCustomUserName(user, name);
      if (mounted) {
        setState(() => _hasCustomName = true);
        _showMessage('Nome della chat aggiornato.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Impossibile salvare il nome. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final user = _user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await ChatService.instance.clearCustomUserName(user);
      if (!mounted) return;
      setState(() {
        _hasCustomName = false;
        _controller.text = user.displayName?.trim() ?? '';
      });
      _showMessage('Userai di nuovo il nome del tuo account Google.');
    } catch (_) {
      if (mounted) _showMessage('Impossibile ripristinare il nome.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.subtlePanel(context, 18),
    padding: const EdgeInsets.all(16),
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _user == null
        ? const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.visibility_outlined),
            title: Text('Nome nella chat'),
            subtitle: Text('Accedi con Google per scegliere un nome.'),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 12),
                  Text(
                    'Nome nella chat',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Gli altri vedranno questo nome al posto del nome Google.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLength: ChatService.maxUserNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome pubblico',
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Salvataggio…' : 'Salva'),
                    ),
                  ),
                  if (_hasCustomName) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Usa il nome Google',
                      onPressed: _saving ? null : _reset,
                      icon: const Icon(Icons.restart_alt_rounded),
                    ),
                  ],
                ],
              ),
            ],
          ),
  );
}
