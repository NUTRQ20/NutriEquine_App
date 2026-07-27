import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'user_details_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _routeAfterAuth() async {
    if (!mounted) return;

    // Register email in Firestore
    context.read<FirestoreService>().registerUserEmail();

    // Check if profile already completed
    final prefs = await SharedPreferences.getInstance();
    final profileCompleted =
        prefs.getBool('profile_completed') ?? false;

    if (!mounted) return;

    if (!profileCompleted) {
      // First time — go to user details screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const UserDetailsScreen()),
        (_) => false,
      );
    } else {
      // Returning user — go to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();

    try {
      if (_isSignUp) {
        await auth.signUp(
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
        );
      } else {
        await auth.signIn(
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
        );
      }

      await _routeAfterAuth();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (e) {
      setState(() =>
          _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    try {
      final credential = await auth.signInWithGoogle();
      if (credential == null) {
        // User cancelled the Google account picker — not an error.
        if (mounted) setState(() => _loading = false);
        return;
      }
      await _routeAfterAuth();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (e) {
      setState(() =>
          _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(
                        bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F5233),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.pets,
                        size: 44,
                        color: Colors.white),
                  ),
                  Text(
                    'EquineEdge',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                            fontWeight:
                                FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUp
                        ? 'Create your account'
                        : 'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      border: OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null ||
                          v.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!v.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border:
                          const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() =>
                            _obscurePass =
                                !_obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isSignUp && v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit
                  FilledButton(
                    onPressed:
                        _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                              vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp
                                ? 'Create account'
                                : 'Sign in',
                            style: const TextStyle(
                                fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color:
                                  Colors.grey.shade300)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                color:
                                    Colors.grey.shade500,
                                fontSize: 12)),
                      ),
                      Expanded(
                          child: Divider(
                              color:
                                  Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google sign-in
                  OutlinedButton.icon(
                    onPressed:
                        _loading ? null : _submitGoogle,
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                              vertical: 12),
                      side: BorderSide(
                          color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 50,
                      width: 50,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Toggle
                  TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                    }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}