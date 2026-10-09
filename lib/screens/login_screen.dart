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
  State<LoginScreen> createState() => _LoginScreenState();
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

  /// Routes user after successful authentication.
  ///
  /// Checks profile completion in two layers:
  ///   1. SharedPreferences (fast — works normally)
  ///   2. Firestore users/ document (fallback — handles reinstall)
  ///
  /// This fixes Bug 2: after reinstalling the app, SharedPreferences
  /// is cleared so profile_completed=false even for existing users.
  /// We check Firestore as a fallback so existing users go straight
  /// to HomeScreen without being asked to fill profile again.
  Future<void> _routeAfterAuth() async {
    if (!mounted) return;

    final fs = context.read<FirestoreService>();

    // Register email in Firestore (safe no-op if already exists)
    fs.registerUserEmail();

    // Step 1: Check SharedPreferences (fast path)
    final prefs = await SharedPreferences.getInstance();
    bool profileCompleted = prefs.getBool('profile_completed') ?? false;

    // Step 2: If SharedPreferences says not completed (e.g. after reinstall),
    // check Firestore — existing users will have a profile document
    if (!profileCompleted) {
      try {
        final firestoreProfile = await fs.getUserProfile();
        if (firestoreProfile != null &&
            firestoreProfile['fullName'] != null &&
            (firestoreProfile['fullName'] as String).isNotEmpty) {
          // User has a Firestore profile — they are an existing user
          // Sync the flag back to SharedPreferences
          profileCompleted = true;
          await prefs.setBool('profile_completed', true);
        }
      } catch (_) {
        // Network error — fall back to UserDetailsScreen
      }
    }

    if (!mounted) return;

    if (!profileCompleted) {
      // Genuinely new user — collect profile details
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserDetailsScreen()),
        (_) => false,
      );
    } else {
      // Existing user (local or verified via Firestore) — go home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  /// Handles email/password sign in and sign up.
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
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Handles Google Sign In.
  ///
  /// Three outcomes:
  ///   1. null returned    → user cancelled picker → do nothing
  ///   2. GoogleUserNotFoundException thrown → user has no account
  ///      → show first-time message, stay on login screen
  ///   3. UserCredential returned → existing user → route to app
  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();

    try {
      final credential = await auth.signInWithGoogle();

      if (credential == null) {
        // User cancelled the Google account picker — not an error
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Existing user — route normally
      await _routeAfterAuth();
    } on GoogleUserNotFoundException catch (e) {
      // ── New user or deleted account ───────────────────────────
      // Google email not found in our database.
      // Do NOT log them in. Show first-time message.
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null; // clear field error — we show dialog instead
        });
        await _showFirstTimeGoogleDialog(e.email);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _friendlyError(e.code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Google sign-in failed. Please try again.';
        });
      }
    }
  }

  /// Shows a clear dialog explaining that the Google account is not
  /// registered yet and the user must sign up first.
  Future<void> _showFirstTimeGoogleDialog(String email) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon:
            const Icon(Icons.info_outline, color: Color(0xFF2F5233), size: 40),
        title: const Text(
          'Account Not Found',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show which email was used
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                email,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'This is your first time logging in with Google.\n\n'
              'Please create an account first using your email '
              'and password. After that, you can use '
              'Google Sign In for future logins.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Switch to Sign Up mode so user can register
                setState(() {
                  _isSignUp = true;
                  // Pre-fill the email field with their Google email
                  _emailCtrl.text = email;
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F5233),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create Account'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F5233),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:
                        const Icon(Icons.pets, size: 44, color: Colors.white),
                  ),

                  Text(
                    'EquineEdge',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUp ? 'Create your account' : 'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
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
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
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

                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit button
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isSignUp ? 'Create account' : 'Sign in',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign In
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _submitGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 50,
                      width: 50,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Toggle sign in / sign up
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
