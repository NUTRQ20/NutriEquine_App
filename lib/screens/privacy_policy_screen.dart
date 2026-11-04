import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          const Center(
            child: Icon(Icons.privacy_tip_outlined,
                size: 56, color: Color(0xFF2F5233)),
          ),
          const SizedBox(height: 16),
          const Text(
            'EquineEdge Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last updated: September 2026',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),

          _Section(
            title: '1. Information We Collect',
            content:
                'EquineEdge collects the following information to provide our services:\n\n'
                '• Email address and display name (via Firebase Authentication)\n'
                '• Horse profile data, health records, and care logs you enter\n'
                '• Profile information (name, role, mobile number)\n'
                '• Photos you upload for horse profiles (via Firebase Storage)\n'
                '• App usage data collected automatically by Firebase Analytics',
          ),

          _Section(
            title: '2. Third-Party Services & Trackers',
            content:
                'EquineEdge uses the following third-party services that may '
                'collect data about your device and usage:\n\n'
                '• Firebase (Google) — Authentication, Database, Storage, '
                'Analytics, and Cloud Messaging. '
                'Privacy policy: policies.google.com/privacy\n\n'
                '• Facebook SDK — Used for Facebook Sign-In. '
                'Privacy policy: facebook.com/policy',
          ),

          _Section(
            title: '3. How We Use Your Data',
            content:
                'Your data is used solely to:\n\n'
                '• Provide and improve the EquineEdge app\n'
                '• Sync your horse care data across devices\n'
                '• Send notifications for care reminders and low stock alerts\n'
                '• Allow team members to collaborate on horse care\n\n'
                'We do not sell your personal data to third parties.',
          ),

          _Section(
            title: '4. Data Storage & Security',
            content:
                'All data is stored in Google Firebase (Firestore), which is '
                'encrypted at rest and in transit. We implement server-side '
                'security rules to ensure you can only access your own data.\n\n'
                'Your data is stored on Firebase servers in the region specified '
                'by your Firebase project configuration.',
          ),

          _Section(
            title: '5. Data Deletion',
            content:
                'You can delete your account and all associated data at any '
                'time from Settings → My Profile → Delete Account.\n\n'
                'This will permanently delete:\n'
                '• Your user profile\n'
                '• All horses and their records\n'
                '• All feed plans, wellness logs, and reminders\n'
                '• All training logs and barn tasks',
          ),

          _Section(
            title: '6. Contact Us',
            content:
                'For privacy-related questions or data deletion requests, '
                'contact us at:\n\ncontact@nutriequine.com\nnutriequine.com',
          ),

          const SizedBox(height: 16),

          // Links
          OutlinedButton.icon(
            onPressed: () =>
                _openUrl(context, 'https://nutriequine.com/'),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Visit nutriequine.com'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F5233))),
          const SizedBox(height: 6),
          Text(content,
              style: const TextStyle(
                  fontSize: 13, height: 1.6, color: Colors.black87)),
          const Divider(height: 28),
        ],
      ),
    );
  }
}