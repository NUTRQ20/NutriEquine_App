import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(emoji: '🐴', title: 'Welcome to NutriEquine',
      subtitle: 'The all-in-one horse care app for owners, trainers, and barn staff.',
      color: const Color(0xFF2F5233)),
    _OnboardingPage(emoji: '🌿', title: 'Track Feeding & Supplements',
      subtitle: 'Build AM/PM feed plans, track supplement dosages, and get low-stock alerts before you run out.',
      color: const Color(0xFF3D6B42)),
    _OnboardingPage(emoji: '❤️', title: 'Monitor Daily Wellness',
      subtitle: 'Log appetite, manure, body condition, and behavior. Get guidance when something looks off.',
      color: const Color(0xFF4A7C59)),
    _OnboardingPage(emoji: '📅', title: 'Never Miss a Care Event',
      subtitle: 'Schedule vet, farrier, dental, vaccines, and deworming with reminders sent straight to your phone.',
      color: const Color(0xFF558B6E)),
    _OnboardingPage(emoji: '👥', title: 'Coordinate Your Care Team',
      subtitle: 'Share horse profiles with your vet, trainer, or barn staff. Assign tasks and track completion.',
      color: const Color(0xFF2F5233)),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => _pages[i],
          ),
          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2F5233),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        _finish();
                      }
                    },
                    child: Text(_currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _OnboardingPage({required this.emoji, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 32),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}