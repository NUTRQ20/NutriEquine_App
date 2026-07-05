import 'package:shared_preferences/shared_preferences.dart';

/// Manages the free vs premium state.
/// In production, verify premium status server-side (e.g. RevenueCat or Stripe).
class PremiumService {
  static const _key = 'is_premium';

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Call this after a successful payment confirmation.
  Future<void> activatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> revokePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }

  /// Premium-gated features list.
  static const List<String> premiumFeatures = [
    'Unlimited horses',
    'Shared access (team members)',
    'Barn task assignment',
    'Advanced analytics & charts',
    'Smart supplement protocol quiz',
    'QR code product scanning',
    'Push notification reminders',
    'Export health records as PDF',
  ];

  static const List<String> freeFeatures = [
    '1 horse profile',
    'Feed & supplement planner',
    'Daily wellness check-ins',
    'Care reminders',
    'Training log',
    'Education hub',
  ];
}
