import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/premium_service.dart';
import 'services/feed_auto_update_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  try {
    await NotificationService().init();
    await NotificationService().requestPermissions();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FeedAutoUpdateService().runDailyCheck();
    }
  } catch (e) {
    debugPrint('Feed auto update error: $e');
  }

  runApp(const NutriEquineApp());
}

class NutriEquineApp extends StatefulWidget {
  const NutriEquineApp({super.key});

  @override
  State<NutriEquineApp> createState() => _NutriEquineAppState();
}

class _NutriEquineAppState extends State<NutriEquineApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  // Guards against showing the deleted-account dialog multiple times
  // or running concurrent session checks.
  bool _handlingDeletion = false;

  // Subscription to Firebase ID token changes.
  dynamic _tokenSubscription;

  // Subscription to auth state changes.
  // This fires immediately when Firebase revokes a session —
  // faster than idTokenChanges in some cases.
  dynamic _authStateSubscription;

  // Periodic timer that actively polls Firebase every 60 seconds
  // while the app is in the foreground.
  // This catches account deletion immediately without requiring
  // the user to background and resume the app.
  Timer? _sessionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to ID token changes.
    _tokenSubscription =
        FirebaseAuth.instance.idTokenChanges().listen((user) async {
      debugPrint(
          '[SessionCheck] idTokenChanges fired, user=${user?.uid ?? "null"}');
      if (user == null) return;
      await _verifyUserStillExists(user);
    });

    // Listen to auth state changes — this is a second independent
    // stream that fires when Firebase revokes authentication.
    // On some SDK versions this fires faster than idTokenChanges.
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      debugPrint(
          '[SessionCheck] authStateChanges fired, user=${user?.uid ?? "null"}');
      if (user == null) return;
      await _verifyUserStillExists(user);
    });

    // Periodic check every 30 seconds (reduced from 60s).
    _startPeriodicSessionCheck();
  }

  void _startPeriodicSessionCheck() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_handlingDeletion) return;
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return; // not logged in
        debugPrint('[SessionCheck] Running periodic account check...');
        await _verifyUserStillExists(user);
      },
    );
    debugPrint('[SessionCheck] Periodic session check started (every 30s)');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenSubscription?.cancel();
    _authStateSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  /// Also check when the app resumes from background,
  /// because the token stream may not fire while suspended.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check immediately on resume
      _checkSessionOnResume();
      // Restart the periodic timer — it may have been paused
      // or drifted while the app was in the background
      _startPeriodicSessionCheck();
    } else if (state == AppLifecycleState.paused) {
      // Cancel the timer when the app goes to background
      // to save battery. It will restart on resume.
      _sessionCheckTimer?.cancel();
    }
  }

  Future<void> _checkSessionOnResume() async {
    if (_handlingDeletion) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    debugPrint('[SessionCheck] Checking session on resume...');
    await _verifyUserStillExists(user);
  }

  /// Checks whether the user account still exists in Firebase.
  ///
  /// Uses user.reload() which is the correct method for checking
  /// account existence. Unlike getIdToken(true), reload() always
  /// contacts Firebase servers and throws user-not-found reliably
  /// across all Android versions when the account has been deleted.
  ///
  /// Also checks FirebaseAuth.instance.currentUser after reload —
  /// on some SDK versions the user object becomes null silently
  /// after reload when the account is deleted.
  Future<void> _verifyUserStillExists(User user) async {
    if (_handlingDeletion) return;

    try {
      // reload() contacts Firebase and throws immediately if the
      // account was deleted. This is more reliable than getIdToken(true)
      // which may return a cached token even for deleted accounts.
      await user.reload();

      // After reload, currentUser becomes null if account was deleted
      // on some SDK versions — check for this explicitly.
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed == null) {
        await _handleDeletedAccount();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Session check error code: ${e.code}');
      // user-not-found is thrown by reload() when account is deleted
      // user-disabled is thrown when account is disabled
      // invalid-user-token and user-token-expired are token issues
      // For ALL FirebaseAuthExceptions except network errors,
      // treat as account gone — this catches any new error codes
      // Firebase may introduce in future SDK versions.
      if (e.code != 'network-request-failed') {
        await _handleDeletedAccount();
      }
    } catch (e) {
      debugPrint('Session check unknown error: $e');
      // Unknown error — don't sign out (could be network issue).
    }
  }

  Future<void> _handleDeletedAccount() async {
    // Guard — only handle once even if the stream fires multiple times
    if (_handlingDeletion) return;
    _handlingDeletion = true;
    debugPrint('[SessionCheck] Account deleted — starting cleanup');

    // Cancel all timers and subscriptions — no more checks needed
    _sessionCheckTimer?.cancel();
    _tokenSubscription?.cancel();
    _authStateSubscription?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null && uid.isNotEmpty) {
      final fs = FirestoreService();

      // ── Step 1: Delete users/{uid} document FIRST ───────────────────
      // This immediately activates the Firestore security rules gate.
      // After this, userIsActive() returns false for this uid, so
      // CREATE and UPDATE operations are blocked at the server level
      // even while the Firebase Auth token is still technically valid.
      // DELETE operations are still allowed so cleanup can proceed.
      try {
        debugPrint('[SessionCheck] Step 1: revoking write access');
        await fs.deleteUserProfile(uid);
        debugPrint('[SessionCheck] Step 1 complete — writes now blocked');
      } catch (e) {
        debugPrint('[SessionCheck] Step 1 error: $e');
      }

      // ── Step 2: Delete all horse data ────────────────────────────────
      // Now clean up every horse and all related documents.
      // This includes anything created during the detection delay.
      // The Firestore rules allow DELETE by authenticated owner,
      // so this proceeds even though users/{uid} is now gone.
      try {
        debugPrint('[SessionCheck] Step 2: deleting all horse data');
        await fs.deleteAllHorsesForUser(uid);
        debugPrint('[SessionCheck] Step 2 complete — all data deleted');
      } catch (e) {
        debugPrint('[SessionCheck] Step 2 error: $e');
      }
    }

    // ── Step 3: Sign out locally ─────────────────────────────────────
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('[SessionCheck] Step 3 complete — signed out');
    } catch (_) {}

    // Get the navigator context
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      _handlingDeletion = false;
      return;
    }

    // Show the dialog — user cannot dismiss it by tapping outside
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Account Deleted'),
        content: const Text(
          'Your account has been deleted by the administrator.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              // Clear entire navigation stack and go to login
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _handlingDeletion = false;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PremiumService>(create: (_) => PremiumService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'NutriEquine',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2F5233),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF7F2),
          cardTheme: const CardThemeData(
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
        home: const SplashScreen(),
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets,
                          size: 64, color: Color(0xFF2F5233)),
                      const SizedBox(height: 16),
                      const Text('NutriEquine',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F5233))),
                      const SizedBox(height: 8),
                      const Text(
                        'Something went wrong.\nPlease restart the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const SplashScreen()),
                            (_) => false,
                          );
                        },
                        child: const Text('Restart app'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          };
          return child ?? const SizedBox();
        },
      ),
    );
  }
}
