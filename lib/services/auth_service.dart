import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

/// Thrown by signInWithGoogle() when the Google email is not found
/// in the Firestore users/ collection — meaning this person has no
/// account in our app yet.
class GoogleUserNotFoundException implements Exception {
  final String email;
  const GoogleUserNotFoundException(this.email);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// Signs in with Google — only if the Google email already exists
  /// in our Firestore users/ collection.
  ///
  /// THE KEY FIX:
  /// The previous implementation tried to query Firestore BEFORE
  /// signing into Firebase. This caused a permission denied error
  /// because Firestore security rules block unauthenticated reads.
  /// The catch block silently returned false, treating ALL users
  /// as new users — including existing ones.
  ///
  /// The correct order is:
  ///   1. Sign into Firebase Auth with Google credentials.
  ///   2. Now authenticated — query Firestore with valid token.
  ///   3a. User found in Firestore → keep them signed in → return credential.
  ///   3b. User NOT found → sign out immediately → throw exception.
  ///   3c. Picker cancelled → return null.
  Future<UserCredential?> signInWithGoogle() async {
    // Force account picker to show every time
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();

    // Step 1: Show Google account picker
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // cancelled — not an error

    // Step 2: Get Google credentials
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Step 3: Sign into Firebase Auth FIRST.
    // This gives us an authenticated session so Firestore rules
    // allow us to read the users/ collection on the next step.
    // We may need to sign out immediately after if user doesn't exist.
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    // Step 4: Get the verified email from Firebase (not from frontend)
    final firebaseEmail =
        userCredential.user?.email?.toLowerCase().trim() ?? '';

    if (firebaseEmail.isEmpty) {
      // No email — sign out and reject
      await _fullSignOut(googleSignIn);
      throw GoogleUserNotFoundException('unknown');
    }

    // Step 5: Check Firestore users/ collection for this email.
    // Now we are authenticated so Firestore rules allow this read.
    // This is the source of truth — NOT SharedPreferences.
    final userExists = await _checkUserExistsInDatabase(firebaseEmail);

    if (!userExists) {
      // User does not exist in our app database.
      // Sign out of Firebase AND Google immediately.
      // Do NOT keep them signed in.
      await _fullSignOut(googleSignIn);
      throw GoogleUserNotFoundException(firebaseEmail);
    }

    // Step 6: User exists — return the credential and keep them signed in.
    return userCredential;
  }

  /// Checks whether [email] exists in the Firestore users/ collection.
  ///
  /// Called AFTER Firebase Auth sign-in so the security rules allow
  /// this read. Uses default cache+server behaviour (no Source.server)
  /// to avoid permission errors on slower connections.
  ///
  /// Returns true  if a matching document is found.
  /// Returns false if no document is found.
  /// Re-throws on any Firestore error so the caller can handle it.
  Future<bool> _checkUserExistsInDatabase(String email) async {
    // Try exact email match first
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) return true;

    // Some users may have registered with mixed case email.
    // Firebase Auth normalises to lowercase but old records might differ.
    // As a fallback, also check the users/ document by UID directly —
    // the document ID is the Firebase UID which is always consistent.
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      final uidDoc = await _db.collection('users').doc(uid).get();
      if (uidDoc.exists) return true;
    }

    return false;
  }

  /// Signs out from Firebase Auth and Google Sign In.
  Future<void> _fullSignOut(GoogleSignIn googleSignIn) async {
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Signs in with Facebook.
  Future<UserCredential?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success || result.accessToken == null) {
      return null;
    }
    final credential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);
    return _auth.signInWithCredential(credential);
  }

  /// Signs out from Firebase, Google, and Facebook.
  /// Also clears locally stored session flags.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_completed');
    } catch (_) {}
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Validates the current Firebase session.
  /// Returns true if the session is invalid (user was deleted/disabled).
  Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
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
      return false;
    } catch (_) {
      return false;
    }
  }
}
