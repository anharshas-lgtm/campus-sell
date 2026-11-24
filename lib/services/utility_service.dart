import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UtilityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Fetch URL from Firestore by document ID ───────────────────────────────
  static Future<String?> fetchUrl(String documentId) async {
    try {
      final doc = await _firestore
          .collection('utility_pages')
          .doc(documentId)
          .get();

      if (!doc.exists) return null;
      final url = doc.data()?['url'] as String?;
      return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    } catch (e) {
      return null;
    }
  }

  // ── Open URL inside the app ───────────────────────────────────────────────
  static Future<void> openPage({
    required BuildContext context,
    required String documentId,
    required String pageName,
  }) async {
    // Show loading snackbar while fetching
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text('Opening $pageName...'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }

    final url = await fetchUrl(documentId);

    // Dismiss loading snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    // URL not set yet in Firestore
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$pageName is not available yet. Please check back later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        // ← Opens inside the app instead of external browser
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: WebViewConfiguration(
          // Show URL bar at top so user knows where they are
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $pageName.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
