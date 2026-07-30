import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() =>
      _UserProfileScreenState();
}

class _UserProfileScreenState
    extends State<UserProfileScreen> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  String _role = 'Owner';
  String _gender = 'Male';

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

  Color _roleColor(String role) {
    switch (role) {
      case 'Veterinarian':
        return Colors.blue;
      case 'Care Taker':
        return Colors.orange;
      case 'Barn Manager':
        return Colors.teal;
      default:
        return const Color(0xFF2F5233);
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'Veterinarian':
        return Icons.local_hospital;
      case 'Care Taker':
        return Icons.favorite;
      case 'Barn Manager':
        return Icons.warehouse;
      default:
        return Icons.person;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final data = await fs.getUserProfile();
      setState(() {
        _profile = data ?? {};
        _nameCtrl.text = _profile['fullName'] ?? '';
        _mobileCtrl.text = _profile['mobile'] ?? '';
        _role = _profile['role'] ?? 'Owner';
        _gender = _profile['gender'] ?? 'Male';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final fs = context.read<FirestoreService>();
      final user = FirebaseAuth.instance.currentUser!;

      await user.updateDisplayName(_nameCtrl.text.trim());

      final updated = {
        ..._profile,
        'fullName': _nameCtrl.text.trim(),
        'role': _role,
        'mobile': _mobileCtrl.text.trim(),
        'gender': _gender,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await fs.saveUserProfile(updated);

      setState(() {
        _profile = updated;
        _editing = false;
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthService>().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Step 1: confirm intent
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Are you sure you want to permanently delete '
          'your account and all your data including all '
          'horses and their records? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, delete my account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                  child: Text('Deleting account and all data...')),
            ],
          ),
        ),
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
      final fs = context.read<FirestoreService>();

      // Step 1: Delete all horses and their related data
      // This calls deleteHorse() for each horse, which handles
      // feed_entries, wellness_logs, care_reminders,
      // training_logs, and barn_tasks for each horse.
      await fs.deleteAllHorsesForUser(uid);

      // Step 2: Delete the user profile document
      await fs.deleteUserProfile(uid);

      // Step 3: Delete Firebase Auth account
      await user.delete();

      // Step 4: Clear local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Step 5: Navigate to login
      if (mounted) {
        // Close loading dialog first
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please sign out and sign back in, '
                'then try deleting again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    String? memberSince;
    if (user.metadata.creationTime != null) {
      memberSince =
          DateFormat.yMMMd().format(user.metadata.creationTime!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_editing)
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
              onPressed: () => setState(() => _editing = true),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Avatar + Basic Info ──────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF2F5233)
                              .withValues(alpha: 0.15),
                          child: Text(
                            (_profile['fullName']?.isNotEmpty == true
                                    ? _profile['fullName']!
                                    : user.email ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F5233),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (!_editing) ...[
                          Text(
                            _profile['fullName'] ?? 'No name set',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(user.email ?? '',
                              style:
                                  const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: _roleColor(
                                      _profile['role'] ?? 'Owner')
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _roleColor(
                                    _profile['role'] ?? 'Owner'),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _roleIcon(
                                      _profile['role'] ?? 'Owner'),
                                  size: 16,
                                  color: _roleColor(
                                      _profile['role'] ?? 'Owner'),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _profile['role'] ?? 'Owner',
                                  style: TextStyle(
                                    color: _roleColor(
                                        _profile['role'] ?? 'Owner'),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (memberSince != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Member since $memberSince',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ] else ...[
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization:
                                TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Profile Details ──────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF2F5233),
                          ),
                        ),
                        const Divider(height: 20),

                        if (!_editing) ...[
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email ?? '--',
                          ),
                          _InfoRow(
                            icon: Icons.work_outline,
                            label: 'Role',
                            value: _profile['role'] ?? '--',
                          ),
                          _InfoRow(
                            icon: Icons.phone,
                            label: 'Mobile',
                            value: _profile['mobile']?.isNotEmpty ==
                                    true
                                ? _profile['mobile']
                                : '--',
                          ),
                          _InfoRow(
                            icon: Icons.person_outline,
                            label: 'Gender',
                            value: _profile['gender'] ?? '--',
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            value: _role,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.work_outline),
                            ),
                            items: _roles
                                .map((r) => DropdownMenuItem(
                                    value: r, child: Text(r)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _role = v!),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _mobileCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                    value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _gender = v!),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  _saving ? null : _saveProfile,
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
                                  : const Text('Save changes'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Account Actions ──────────────────────────
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF2F5233),
                    ),
                  ),
                ),

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.orange,
                    ),
                    title: const Text('Sign out'),
                    subtitle:
                        const Text('Sign out of your account'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _signOut,
                  ),
                ),

                const SizedBox(height: 8),

                Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete account',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Permanently delete your account and all data',
                      style: TextStyle(color: Colors.red),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.red,
                    ),
                    onTap: _deleteAccount,
                  ),
                ),

                const SizedBox(height: 32),

                const Center(
                  child: Text(
                    'EquineEdge v1.0.0',
                    style:
                        TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}