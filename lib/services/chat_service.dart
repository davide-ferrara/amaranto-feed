import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();

  static final instance = ChatService._();
  static const maxMessageLength = 1000;
  static const maxUserNameLength = 60;
  static const _reservedUserNames = {
    'admin',
    'administrator',
    'moderator',
    'mod',
    'staff',
    'official',
    'support',
    'system',
    'owner',
    'reggina admin',
    'amaranto feed admin',
  };
  static final _reservedRolePattern = RegExp(
    r'(^|[^a-z0-9])(admin|administrator|moderator|mod|staff|official|support|system|owner)([^a-z0-9]|$)',
  );
  static const _messagesCollection = 'chat_messages';
  static const _profilesCollection = 'chat_profiles';

  Future<String?> getCustomUserName(User user) async {
    final profile = await FirebaseFirestore.instance
        .collection(_profilesCollection)
        .doc(user.uid)
        .get();
    final name = profile.data()?['displayName'];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  Future<void> setCustomUserName(User user, String value) async {
    final name = value.trim();
    if (!isAllowedUserName(name)) {
      throw ArgumentError.value(name, 'displayName', 'Nome non valido.');
    }
    await FirebaseFirestore.instance
        .collection(_profilesCollection)
        .doc(user.uid)
        .set({'displayName': name});
  }

  static bool isAllowedUserName(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized.length <= maxUserNameLength &&
        !_reservedUserNames.contains(normalized) &&
        !_reservedRolePattern.hasMatch(normalized);
  }

  Future<void> clearCustomUserName(User user) async {
    await FirebaseFirestore.instance
        .collection(_profilesCollection)
        .doc(user.uid)
        .delete();
  }

  Future<void> deleteProfile(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_profilesCollection)
          .doc(userId)
          .delete();
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition' && error.code != 'not-found') {
        rethrow;
      }
    }
  }

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
    final customName = await getCustomUserName(user);
    final nameClaim = claims['name'];
    final userName =
        customName ??
        (nameClaim is String && nameClaim.trim().isNotEmpty
            ? nameClaim.trim()
            : 'Tifoso');

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
