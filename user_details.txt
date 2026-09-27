import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() =>
      _UserDetailsScreenState();
}

class _UserDetailsScreenState
    extends State<UserDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  String _role = 'Owner';
  String _gender = 'Male';
  bool _saving = false;

  final List<String> _roles = [
    'Owner',
    'Veterinarian',
    'Care Taker',
    'Barn Manager',
  ];

  final List<String> _genders = [
    'Male',
    'Female',
    'Prefer not to say',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final fs = context.read<FirestoreService>();
      final user = FirebaseAuth.instance.currentUser!;

      // Update display name in Firebase Auth
      await user.updateDisplayName(
          _nameCtrl.text.trim());

      // Save profile to Firestore
      await fs.saveUserProfile({
        'fullName': _nameCtrl.text.trim(),
        'role': _role,
        'mobile': _mobileCtrl.text.trim(),
        'gender': _gender,
        'email': user.email ?? '',
        'uid': user.uid,
        'createdAt':
            DateTime.now().millisecondsSinceEpoch,
      });

      // Mark profile as completed locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_completed', true);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Header
                const Icon(
                  Icons.pets,
                  size: 56,
                  color: Color(0xFF2F5233),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tell us about yourself',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This helps us personalize your experience. You can update this anytime from your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),

                // Full name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role dropdown
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Your role *',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.work_outline),
                  ),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _role = v!),
                ),
                const SizedBox(height: 16),

                // Mobile number
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    hintText: 'e.g. 9876543210',
                  ),
                ),
                const SizedBox(height: 16),

                // Gender dropdown
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.person_outline),
                  ),
                  items: _genders
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _gender = v!),
                ),
                const SizedBox(height: 32),

                // Save button
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue to App',
                          style:
                              TextStyle(fontSize: 16),
                        ),
                ),

                const SizedBox(height: 12),

                // Skip option
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final prefs =
                              await SharedPreferences
                                  .getInstance();
                          await prefs.setBool(
                              'profile_completed',
                              true);
                          if (mounted) {
                            Navigator.of(context)
                                .pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const HomeScreen()),
                              (_) => false,
                            );
                          }
                        },
                  child: const Text(
                      'Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
