import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// Signs in with a Google account and links it to Firebase Auth.
  /// Returns null if the user cancels the Google account picker.
  Future<UserCredential?> signInWithGoogle() async {
    // Force account picker to show every time
    // by signing out of Google first
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();

    // Now show the account picker
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Signs in with a Facebook account and links it to Firebase Auth.
  /// Returns null if the user cancels the Facebook login dialog.
  Future<UserCredential?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success || result.accessToken == null) {
      return null; // user cancelled or denied permissions
    }

    final credential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Checks whether the currently logged-in user still actually exists in
  /// Firebase. If the account was deleted or disabled from the Firebase
  /// Console, this signs the user out locally and returns true (meaning
  /// "the app should now show the login screen"). Returns false if the
  /// session is still valid, or if no one is logged in.
  Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      // Forces a real round-trip to Firebase instead of trusting the
      // locally cached session — this is what actually detects deletion.
      await user.getIdToken(true);
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token') {
        await signOut();
        return true;
      }
      // Some other error (e.g. no internet) — don't sign the user out
      // just because the network request failed.
      return false;
    } catch (_) {
      return false;
    }
  }
}
