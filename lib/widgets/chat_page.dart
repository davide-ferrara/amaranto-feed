import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
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

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await GoogleAuthService.instance.signIn();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accesso non riuscito: ${_authError(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authError(Object error) {
    final message = error.toString();
    if (message.contains('canceled')) return 'accesso annullato';
    if (message.contains('Web OAuth client')) {
      return 'controlla la configurazione di Google Sign-In';
    }
    return 'controlla la connessione e riprova';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseReady) {
      return const _ChatNotice(
        icon: Icons.cloud_off_outlined,
        title: 'Chat non disponibile',
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
        if (user == null) {
          return _ChatNotice(
            icon: Icons.forum_outlined,
            title: 'Chat dei tifosi',
            message: 'Accedi con Google per leggere e inviare messaggi.',
            action: Column(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text('Accedi con Google'),
                ),
              ],
            ),
          );
        }
        return _SignedInChat(user: user);
      },
    );
  }
}

class _SignedInChat extends StatefulWidget {
  const _SignedInChat({required this.user});

  final User user;

  @override
  State<_SignedInChat> createState() => _SignedInChatState();
}

class _SignedInChatState extends State<_SignedInChat> {
  final _messageController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages = ChatService
      .instance
      .watchRecentMessages();
  bool _sending = false;
  int _streamKey = 0;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ChatService.instance.sendMessage(user: widget.user, text: text);
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_firestoreError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _firestoreError(Object error) {
    if (error is FirebaseException && error.plugin == 'cloud_firestore') {
      if (error.code == 'permission-denied') {
        return 'Accesso negato. Verifica le regole di Cloud Firestore.';
      }
      if (error.code == 'unavailable') {
        return 'Connessione assente. Riprova quando torni online.';
      }
      if (error.code == 'failed-precondition' || error.code == 'not-found') {
        return 'Crea il database Cloud Firestore e pubblica le regole del progetto.';
      }
    }
    return 'Impossibile inviare il messaggio. Riprova.';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Icon(
              Icons.forum_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chat dei tifosi',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            CircleAvatar(
              radius: 17,
              backgroundImage: widget.user.photoURL == null
                  ? null
                  : NetworkImage(widget.user.photoURL!),
              child: widget.user.photoURL == null
                  ? const Icon(Icons.person_rounded, size: 18)
                  : null,
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_streamKey),
          stream: _messages,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ChatNotice(
                icon: Icons.cloud_off_outlined,
                title: 'Chat non disponibile',
                message: _firestoreError(snapshot.error!),
                action: FilledButton.icon(
                  onPressed: () => setState(() => _streamKey++),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final messages = snapshot.data?.docs ?? const [];
            if (messages.isEmpty) {
              return const _ChatNotice(
                icon: Icons.mark_chat_unread_outlined,
                title: 'La chat è vuota',
                message: 'Scrivi tu il primo messaggio!',
              );
            }
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: messages.length,
              itemBuilder: (context, index) => _ChatBubble(
                data: messages[index].data(),
                isMine: messages[index].data()['userId'] == widget.user.uid,
              ),
            );
          },
        ),
      ),
      _MessageComposer(
        controller: _messageController,
        sending: _sending,
        readOnly: widget.user.isAnonymous,
        onSend: _sendMessage,
      ),
    ],
  );
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.readOnly,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool readOnly;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Container(
      decoration: AppTheme.subtlePanel(context, 20),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: ChatService.maxMessageLength,
              maxLines: 4,
              minLines: 1,
              readOnly: readOnly,
              textCapitalization: TextCapitalization.sentences,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: readOnly
                    ? 'Modalità ospite: sola lettura'
                    : 'Scrivi un messaggio…',
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox.square(
            dimension: 48,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: sending || readOnly ? null : onSend,
                customBorder: const CircleBorder(),
                child: Center(
                  child: sending
                      ? SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 21,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.data, required this.isMine});

  final Map<String, dynamic> data;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final colors = Theme.of(context).colorScheme;
    final background = isMine
        ? colors.primary
        : dark
        ? colors.surface.withValues(alpha: 0.92)
        : colors.surface;
    final foreground = isMine ? colors.onPrimary : colors.onSurface;
    final timestamp = data['createdAt'];
    final time = timestamp is Timestamp
        ? _formatTime(timestamp.toDate())
        : 'Invio…';
    final name = data['userName'] is String
        ? data['userName'] as String
        : 'Tifoso';
    final text = data['text'] is String ? data['text'] as String : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 5),
                bottomRight: Radius.circular(isMine ? 5 : 18),
              ),
              border: isMine
                  ? null
                  : Border.all(
                      color: colors.outlineVariant.withValues(
                        alpha: dark ? 0.35 : 1,
                      ),
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          isMine ? 'Tu' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: foreground.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: foreground, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({
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
  Widget build(BuildContext context) => Center(
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
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
