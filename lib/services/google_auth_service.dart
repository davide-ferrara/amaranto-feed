import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'chat_service.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();
  static Future<void>? _googleInitialization;

  Future<void> _initializeGoogleSignIn() =>
      _googleInitialization ??= GoogleSignIn.instance.initialize();

  Future<UserCredential> signIn() async {
    try {
      final credential = await _googleCredential();
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (error, stack) {
      // Record diagnostic codes only; never log accounts, tokens or credentials.
      final code = switch (error) {
        GoogleSignInException e => 'google/${e.code.name}',
        FirebaseAuthException e => 'firebase/${e.code}',
        PlatformException e => 'platform/${e.code}',
        _ => error.runtimeType.toString(),
      };
      debugPrint('Google sign-in failed: $code');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
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
