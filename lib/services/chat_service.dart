import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();

  static final instance = ChatService._();
  static const maxMessageLength = 1000;
  static const _messagesCollection = 'chat_messages';

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentMessages() =>
      FirebaseFirestore.instance
          .collection(_messagesCollection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots();

  Future<void> sendMessage({required User user, required String text}) async {
    final message = text.trim();
    if (message.isEmpty) return;
    if (message.length > maxMessageLength) {
      throw ArgumentError.value(
        message.length,
        'text.length',
        'Il messaggio supera il limite consentito.',
      );
    }

    final claims = (await user.getIdTokenResult()).claims ?? const {};
    final nameClaim = claims['name'];
    final userName = nameClaim is String && nameClaim.trim().isNotEmpty
        ? nameClaim.trim()
        : 'Tifoso';

    await FirebaseFirestore.instance.collection(_messagesCollection).add({
      'userId': user.uid,
      'userName': userName,
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessagesForUser(String userId) async {
    final collection = FirebaseFirestore.instance.collection(
      _messagesCollection,
    );
    while (true) {
      final messages = await collection
          .where('userId', isEqualTo: userId)
          .limit(400)
          .get();
      if (messages.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final message in messages.docs) {
        batch.delete(message.reference);
      }
      await batch.commit();
    }
  }
}
