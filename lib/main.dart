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
  // Firebase fires this stream whenever the token is refreshed or
  // when the account is deleted/disabled — even while the app is open.
  dynamic _tokenSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to ID token changes continuously.
    // This fires:
    //   • On sign-in / sign-out
    //   • When the token is refreshed (~every hour)
    //   • When Firebase detects the account no longer exists
    // When the account is deleted from the Firebase Console the
    // next token refresh will fail and the stream will emit null,
    // which we catch here to immediately block the user.
    _tokenSubscription =
        FirebaseAuth.instance.idTokenChanges().listen((user) async {
      if (user == null) return; // normal sign-out, handled elsewhere
      await _verifyUserStillExists(user);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenSubscription?.cancel();
    super.dispose();
  }

  /// Also check when the app resumes from background,
  /// because the token stream may not fire while suspended.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionOnResume();
    }
  }

  Future<void> _checkSessionOnResume() async {
    if (_handlingDeletion) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _verifyUserStillExists(user);
  }

  /// Forces a round-trip to Firebase to confirm the account exists.
  /// If the account has been deleted or disabled:
  ///   1. Sets the guard flag to block further checks.
  ///   2. Signs the user out locally.
  ///   3. Shows the "account deleted" dialog.
  ///   4. Navigates to the login screen.
  Future<void> _verifyUserStillExists(User user) async {
    if (_handlingDeletion) return;

    try {
      // Force-refresh the ID token. If the account was deleted this
      // throws a FirebaseAuthException that we catch below.
      await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      // These codes mean the account no longer exists or is disabled.
      const accountGoneCodes = {
        'user-not-found',
        'user-disabled',
        'invalid-user-token',
        'user-token-expired',
      };
      if (accountGoneCodes.contains(e.code)) {
        await _handleDeletedAccount();
      }
      // network-request-failed and other transient errors are
      // intentionally ignored — we don't sign out on network failure.
    } catch (_) {
      // Unknown error — don't sign out.
    }
  }

  Future<void> _handleDeletedAccount() async {
    // Guard — only handle once even if the stream fires multiple times
    if (_handlingDeletion) return;
    _handlingDeletion = true;

    // Sign out silently — clears local session
    try {
      await FirebaseAuth.instance.signOut();
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
                MaterialPageRoute(
                    builder: (_) => const LoginScreen()),
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
        Provider<NotificationService>(
            create: (_) => NotificationService()),
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
            margin:
                EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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