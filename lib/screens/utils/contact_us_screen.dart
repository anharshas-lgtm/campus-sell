import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/918157993096');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    // ── Use mailto with proper Uri constructor ─────────────────────────────
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'anharshas@gmail.com',
      queryParameters: {
        'subject': 'CampusSell Support',
        'body': 'Hi CampusSell Team,\n\n',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No email app found. Please email us at anharshas@gmail.com'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We're here to help!",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Reach out to us through any of the channels below.',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // WhatsApp
            _contactTile(
              context: context,
              icon: Icons.chat,
              iconColor: const Color(0xFF25D366),
              bgColor: const Color(0xFFE8FBF0),
              title: 'WhatsApp Support',
              subtitle: '+91 8157993096',
              onTap: () => _openWhatsApp(context),
            ),
            const SizedBox(height: 12),

            // Email
            _contactTile(
              context: context,
              icon: Icons.email_outlined,
              iconColor: Colors.deepPurple,
              bgColor: const Color(0xFFF0EDFF),
              title: 'Email Us',
              subtitle: 'anharshas@gmailcom',
              onTap: () => _openEmail(context),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.access_time_outlined,
                    color: Colors.grey, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Support hours: Mon–Sat, 9AM – 6PM',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}