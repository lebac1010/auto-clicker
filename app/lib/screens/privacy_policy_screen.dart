import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String policyVersion = '2026-02-23';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'TapMacro Privacy Policy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('Last updated: $policyVersion'),
          SizedBox(height: 16),
          _PolicySection(
            title: '1. Accessibility Service Usage',
            body:
                'TapMacro uses Android Accessibility Service only to perform touch gestures '
                'that you explicitly configure and to capture click events while recording scripts. '
                'The app is not designed to read passwords, payment card data, or private messages.',
          ),
          _PolicySection(
            title: '2. Data Storage',
            body:
                'Scripts, schedules, and settings are stored locally on your device. '
                'By default, they are not uploaded to a remote server.',
          ),
          _PolicySection(
            title: '3. Logs and Diagnostics',
            body:
                'Support logs are stored locally and only exported when you trigger export manually. '
                'Do not share exported logs publicly because they may include technical diagnostics.',
          ),
          _PolicySection(
            title: '4. Permissions',
            body:
                'The app may request Accessibility, Overlay, Notifications, and Exact Alarm permissions '
                'to provide core automation and scheduling features. You can revoke these permissions '
                'at any time from Android settings.',
          ),
          _PolicySection(
            title: '5. Third-party Services',
            body:
                'Current implementation does not send analytics to third-party servers by default. '
                'If this changes in future releases, this policy will be updated.',
          ),
          _PolicySection(
            title: '6. Contact',
            body:
                'For privacy or policy questions, provide your support contact in the app listing and Play Console.',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
