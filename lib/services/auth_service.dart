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

/// Thrown by signUpWithGoogle() when the Google account already has a
/// fully registered app profile. The user should log in, not sign up.
class GoogleUserAlreadyRegisteredException implements Exception {
  final String email;
  const GoogleUserAlreadyRegisteredException(this.email);
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

  // ─────────────────────────────────────────────────────────────────────────
  // Google Sign-In (LOGIN — for existing registered users)
  // ─────────────────────────────────────────────────────────────────────────

  /// Signs in with Google for EXISTING registered users (login flow).
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
  ///               account. We must DELETE it to clean up, then throw
  ///               GoogleUserNotFoundException. (Case A — no account)
  ///
  ///   Step 4c — Firestore record MISSING AND isNewUser == false:
  ///               Firebase Auth account already existed (from a previous partial
  ///               Google sign-in) but registration was never completed.
  ///               Sign out and throw GoogleUserNotFoundException. (Case A edge)
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
      // Sign into Firebase with Google credential.
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
        final registeredEmail = e.email?.toLowerCase().trim() ?? googleEmail;
        final profileExists =
            await _checkUserExistsByEmailUnauthenticated(registeredEmail);
        if (profileExists) {
          throw GoogleAccountLinkException(registeredEmail);
        } else {
          throw GoogleUserNotFoundException(registeredEmail);
        }
      }

      rethrow;
    }

    // Step 3: Retrieve UID.
    final uid = userCredential.user?.uid ?? '';
    final firebaseEmail =
        userCredential.user?.email?.toLowerCase().trim() ?? googleEmail;

    if (uid.isEmpty) {
      await _fullSignOut(googleSignIn);
      throw GoogleUserNotFoundException(googleEmail);
    }

    // Step 4: Check Firestore for the app user record.
    bool userExists = false;
    try {
      userExists = await _checkUserExistsInDatabase(uid, firebaseEmail);
    } catch (e) {
      await _fullSignOut(googleSignIn);
      rethrow;
    }

    if (!userExists) {
      if (isNewFirebaseAccount) {
        // Step 4b: Delete the just-created Firebase Auth account (legitimate
        // cleanup — not a workaround) and throw so the UI can redirect to
        // sign-up.
        try {
          await userCredential.user?.delete();
        } catch (_) {}
        await _fullSignOut(googleSignIn);
        throw GoogleUserNotFoundException(firebaseEmail);
      } else {
        // Step 4c: Pre-existing Firebase Auth account but no Firestore profile.
        await _fullSignOut(googleSignIn);
        throw GoogleUserNotFoundException(firebaseEmail);
      }
    }

    // Step 4a: Firestore profile exists — returning registered user.
    return userCredential;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Google Sign-Up (SIGN-UP — for new users only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Signs up with Google for NEW users (sign-up flow).
  ///
  /// This is intentionally separate from signInWithGoogle() so that:
  ///   - New users can authenticate via Google and proceed directly to the
  ///     profile completion page WITHOUT entering email/password.
  ///   - Existing registered users are correctly identified and redirected
  ///     to the login flow.
  ///
  /// Outcomes:
  ///   D. null                                → user cancelled → return null
  ///   A. NEW Google user (no Firestore)      → return UserCredential (caller
  ///                                            navigates to UserDetailsScreen)
  ///   B. EXISTING Google user (has profile)  → throw GoogleUserAlreadyRegisteredException
  ///   C. Email/password account exists       → throw GoogleAccountLinkException
  ///   E. Error                               → re-throw
  ///
  /// NOTE: This method does NOT delete any Firebase Auth accounts.
  ///   For a new user, signInWithCredential creates an account that we KEEP
  ///   (unlike the login flow where we clean it up). The profile is then saved
  ///   to Firestore by UserDetailsScreen after the user completes their profile.
  Future<UserCredential?> signUpWithGoogle() async {
    // Force account picker to show every time
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();

    // Step 1: Show Google account picker
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // cancelled — Case D

    final googleEmail = googleUser.email.toLowerCase().trim();
    if (googleEmail.isEmpty) {
      await googleSignIn.signOut();
      throw Exception('Could not retrieve Google email.');
    }

    // Step 2: Get Google OAuth credentials
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential;

    try {
      // Sign into Firebase with Google credential.
      // For a genuinely new Google identity this creates a Firebase Auth
      // account — which is exactly what we want for sign-up.
      userCredential = await _auth.signInWithCredential(credential);

    } on FirebaseAuthException catch (e) {
      await googleSignIn.signOut();

      if (e.code == 'account-exists-with-different-credential') {
        // This Google email is already linked to an email/password account.
        final registeredEmail = e.email?.toLowerCase().trim() ?? googleEmail;
        final profileExists =
            await _checkUserExistsByEmailUnauthenticated(registeredEmail);
        if (profileExists) {
          throw GoogleAccountLinkException(registeredEmail); // Case C
        } else {
          // No complete profile — treat as new user but can't proceed via
          // Google here; throw a generic error.
          throw Exception(
              'This email is already linked to a different sign-in method.');
        }
      }

      rethrow;
    }

    // Step 3: Check Firestore for an existing app user record.
    final uid = userCredential.user?.uid ?? '';
    final firebaseEmail =
        userCredential.user?.email?.toLowerCase().trim() ?? googleEmail;

    if (uid.isEmpty) {
      await _fullSignOut(googleSignIn);
      throw Exception('Authentication failed. Please try again.');
    }

    bool userExists = false;
    try {
      userExists = await _checkUserExistsInDatabase(uid, firebaseEmail);
    } catch (e) {
      await _fullSignOut(googleSignIn);
      rethrow;
    }

    if (userExists) {
      // Case B: This Google account is already fully registered.
      // Sign out (they should use the login flow) and throw.
      await _fullSignOut(googleSignIn);
      throw GoogleUserAlreadyRegisteredException(firebaseEmail);
    }

    // Case A: No Firestore profile found — this is a genuinely new user.
    // Return the UserCredential. The Firebase Auth account stays active.
    // UserDetailsScreen will call FirestoreService.saveUserProfile() to
    // complete the registration.
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
    try { await googleSignIn.signOut(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
  }


  /// Signs in with Facebook.
  Future<UserCredential?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success ||
        result.accessToken == null) {
      return null;
    }
    final credential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);
    return _auth.signInWithCredential(credential);
  }

  /// Signs out from Firebase, Google, and Facebook.
  /// Also clears locally stored session flags.
  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await FacebookAuth.instance.logOut(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
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