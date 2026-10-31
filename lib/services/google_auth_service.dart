import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();
  static Future<void>? _googleInitialization;

  Future<void> _initializeGoogleSignIn() =>
      _googleInitialization ??= GoogleSignIn.instance.initialize();

  Future<UserCredential> signIn() async {
    await _initializeGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google did not return an ID token. Check the Web OAuth client in '
        'google-services.json.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
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

    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') rethrow;

      await _initializeGoogleSignIn();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google did not return an ID token.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await user.reauthenticateWithCredential(credential);
      await user.delete();
    }

    await _initializeGoogleSignIn();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // The Firebase account is already deleted; provider cleanup is best effort.
    }
  }
}
