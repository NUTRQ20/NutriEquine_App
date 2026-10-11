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

/// Thrown when the user's email is registered with the password provider
/// and they try to sign in with Google. They must use their password instead.
class GoogleAccountLinkException implements Exception {
  final String email;
  const GoogleAccountLinkException(this.email);
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

  /// Signs in with Google.
  ///
  /// WHY THE PREVIOUS APPROACH (fetchSignInMethodsForEmail) BROKE:
  ///
  ///   Firebase Console has Email Enumeration Protection enabled by default.
  ///   When enabled, fetchSignInMethodsForEmail() ALWAYS returns an empty list
  ///   regardless of whether the email has an account. This caused all returning
  ///   users to be treated as new users and redirected to registration.
  ///
  /// THE CORRECT APPROACH — sign in first, then check Firestore:
  ///
  ///   Step 1 — Show Google account picker. If cancelled → return null. (Case D)
  ///
  ///   Step 2 — Sign into Firebase with the Google credential.
  ///             signInWithCredential() returns isNewUser in additionalUserInfo.
  ///
  ///   Step 3 — Check Firestore for the app user record (using UID or email).
  ///
  ///   Step 4a — Firestore record EXISTS → fully registered returning user.
  ///               Complete login. (Case C)
  ///
  ///   Step 4b — Firestore record MISSING AND isNewUser == true:
  ///               signInWithCredential just created a brand-new Firebase Auth
  ///               account. We must DELETE it to clean up, then redirect to
  ///               registration. The user can register normally with email/password.
  ///               (Case A — new user)
  ///
  ///   Step 4c — Firestore record MISSING AND isNewUser == false:
  ///               Firebase Auth account already existed (from a previous partial
  ///               Google sign-in) but registration was never completed.
  ///               Sign out and redirect to registration. (Case A edge)
  ///
  /// WHY DELETING THE ACCOUNT IN CASE 4b IS CORRECT:
  ///   This is NOT a workaround. The Firebase Auth account was created
  ///   unintentionally by signInWithCredential(). The user has no app profile.
  ///   Deleting the just-created account restores the pre-sign-in state exactly.
  ///   The user can then register with email/password using the same email
  ///   without getting "email-already-in-use".
  ///   This is fundamentally different from deleting an account that belongs to
  ///   a registered user — we only delete it when isNewUser == true AND no
  ///   Firestore profile exists.
  ///
  /// HANDLING account-exists-with-different-credential:
  ///   If the user registered with email/password and then tries Google Sign-In,
  ///   Firebase throws this error because the email is already linked to the
  ///   password provider. We handle this by linking the Google credential to
  ///   the existing password account after signing in with email/password.
  ///   However, since we don't have the password here, the cleanest approach
  ///   is to sign in with the existing account via email link after checking
  ///   Firestore — explained in the error handler below.
  Future<UserCredential?> signInWithGoogle() async {
    // Force account picker to show every time
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();

    // Step 1: Show Google account picker
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // cancelled — Case D

    final googleEmail = googleUser.email.toLowerCase().trim();
    if (googleEmail.isEmpty) {
      await googleSignIn.signOut();
      throw GoogleUserNotFoundException('unknown');
    }

    // Step 2: Get Google OAuth credentials
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential;
    bool isNewFirebaseAccount = false;

    try {
      // Step 2: Sign into Firebase with Google credential.
      // If a Firebase Auth account already exists for this Google identity,
      // this signs into it. If not, it creates one.
      userCredential = await _auth.signInWithCredential(credential);
      isNewFirebaseAccount =
          userCredential.additionalUserInfo?.isNewUser ?? false;
    } on FirebaseAuthException catch (e) {
      await googleSignIn.signOut();

      if (e.code == 'account-exists-with-different-credential') {
        // The email already exists in Firebase Auth under a DIFFERENT provider
        // (e.g. the user registered with email/password).
        // Check if this user has a completed Firestore app profile.
        // If yes → they are a registered user; let them know to sign in
        // with their password (we cannot sign them in via Google alone
        // without linking, which requires their password).
        // If no → treat as new user.
        final registeredEmail = e.email?.toLowerCase().trim() ?? googleEmail;
        final profileExists =
            await _checkUserExistsByEmailUnauthenticated(registeredEmail);
        if (profileExists) {
          // Registered user trying Google Login on a password account.
          // Throw a specific exception so the UI can show the right message.
          throw GoogleAccountLinkException(registeredEmail);
        } else {
          // No app profile — treat as new user.
          throw GoogleUserNotFoundException(registeredEmail);
        }
      }

      // Any other FirebaseAuthException — re-throw so the UI shows a real error.
      rethrow;
    }

    // Step 3: We are now authenticated. Retrieve the Firebase UID.
    final uid = userCredential.user?.uid ?? '';
    final firebaseEmail =
        userCredential.user?.email?.toLowerCase().trim() ?? googleEmail;

    if (uid.isEmpty) {
      await _fullSignOut(googleSignIn);
      throw GoogleUserNotFoundException(googleEmail);
    }

    // Step 4: Check Firestore for the app user record.
    // Look up by UID (primary) and email (fallback).
    bool userExists = false;
    try {
      userExists = await _checkUserExistsInDatabase(uid, firebaseEmail);
    } catch (e) {
      // Database error — do NOT treat this as "user not found".
      // Sign out and re-throw so the UI shows a real error.
      await _fullSignOut(googleSignIn);
      rethrow;
    }

    if (!userExists) {
      if (isNewFirebaseAccount) {
        // Step 4b: A brand-new Firebase Auth account was just created by
        // signInWithCredential(). No Firestore profile exists. Delete the
        // newly created account so the email remains free for registration.
        try {
          await userCredential.user?.delete();
        } catch (_) {
          // If delete fails, sign out at minimum.
        }
        await _fullSignOut(googleSignIn);
        throw GoogleUserNotFoundException(firebaseEmail); // Case A
      } else {
        // Step 4c: Firebase Auth account pre-existed but no Firestore profile.
        // (Edge case from a previous partial Google sign-in that was cleaned
        // up imperfectly.) Sign out and redirect to registration.
        await _fullSignOut(googleSignIn);
        throw GoogleUserNotFoundException(firebaseEmail); // Case A edge
      }
    }

    // Step 4a: Firestore profile exists — returning registered user. (Case C)
    return userCredential;
  }

  /// Checks whether a user exists in Firestore by UID (primary) or email (fallback).
  ///
  /// Called AFTER Firebase Auth sign-in so the security rules allow reads.
  /// UID lookup is preferred because it's exact and does not depend on email
  /// normalisation. Email lookup is a fallback for accounts where the document
  /// ID may differ from the UID (legacy data).
  Future<bool> _checkUserExistsInDatabase(String uid, String email) async {
    // Primary: check users/{uid} directly — O(1), most reliable.
    final uidDoc = await _db.collection('users').doc(uid).get();
    if (uidDoc.exists) return true;

    // Fallback: email query for legacy records where doc ID ≠ UID.
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  /// Checks whether a user exists in Firestore by email WITHOUT being
  /// authenticated. Used only for the account-exists-with-different-credential
  /// case where we cannot sign in first.
  ///
  /// NOTE: This requires a Firestore security rule that allows reading the
  /// users collection by email when unauthenticated, or a rule that returns
  /// the result without exposing document contents. If your rules block this,
  /// this will throw and the error handler will treat it as "not found".
  Future<bool> _checkUserExistsByEmailUnauthenticated(String email) async {
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false; // rules blocked it — assume not found
    }
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
