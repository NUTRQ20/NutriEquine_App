import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/premium_service.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/feed_auto_update_service.dart';

Future<void> main() async {
  // Ensure Flutter engine is ready before anything else
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init — wrapped so any error shows a message instead of crashing
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firestore offline persistence
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
  } catch (e) {
    debugPrint('Firebase init error: $e');
    // Run app anyway — splash screen will show error state
  }

  // Notifications — optional, don't crash if it fails
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

class NutriEquineApp extends StatelessWidget {
  const NutriEquineApp({super.key});

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
        // Global error widget — shows friendly message instead of red crash screen
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
                      const Text(
                        'NutriEquine',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F5233),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Something went wrong.\nPlease restart the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          // Restart by navigating to splash
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
