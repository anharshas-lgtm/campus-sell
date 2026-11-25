import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Fetches the Groq API key from Firebase Remote Config.
/// The key is set in Firebase Console → Remote Config → groq_api_key.
/// Never hardcode the key in source code.
class GroqConfig {
  GroqConfig._();

  static String _key = '';

  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(seconds: 0)   // immediate refresh in debug
            : const Duration(hours: 12),
      ));
      await rc.fetchAndActivate();
      _key = rc.getString('groq_api_key');
      if (kDebugMode) {
        debugPrint(_key.isNotEmpty
            ? '✅ Groq key loaded from Remote Config'
            : '⚠️ Groq key empty — did you publish it in Remote Config?');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ GroqConfig init error: $e');
      // App still runs — posts will use fallback if key is empty.
    }
  }

  static String get apiKey => _key;
  static bool get isConfigured => _key.isNotEmpty;
}
