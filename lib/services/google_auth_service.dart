import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'chat_service.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();
  static Future<void>? _googleInitialization;

  Future<void> _initializeGoogleSignIn() =>
      _googleInitialization ??= GoogleSignIn.instance.initialize();

  Future<UserCredential> signIn() async {
    final credential = await _googleCredential();
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _initializeGoogleSignIn();
    await GoogleSignIn.instance.signOut();
  }

  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final credential = await _googleCredential();
    await user.reauthenticateWithCredential(credential);
    try {
      await ChatService.instance.deleteMessagesForUser(user.uid);
    } on FirebaseException catch (error) {
      // No chat database exists until the project owner enables Firestore.
      if (error.code != 'failed-precondition' && error.code != 'not-found') {
        rethrow;
      }
    }
    await ChatService.instance.deleteProfile(user.uid);
    await user.delete();

    await _initializeGoogleSignIn();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // The Firebase account is already deleted; provider cleanup is best effort.
    }
  }

  Future<AuthCredential> _googleCredential() async {
    await _initializeGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google did not return an ID token. Check the Web OAuth client in '
        'google-services.json.',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }
}
