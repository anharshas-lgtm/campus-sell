import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Loads the list of admin UIDs from Firestore once at startup and caches them.
/// No repeated reads — just one document fetch per app session.
class AdminService {
  AdminService._();

  static final Set<String> _cache = {};
  static bool _loaded = false;

  /// Call once in main() after Firebase.initializeApp().
  static Future<void> loadAdmins() async {
    if (_loaded) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('board_admins')
          .doc('authorized')
          .get();
      if (snap.exists) {
        final data = snap.data();
        if (data != null && data['uids'] is List) {
          _cache.addAll(List<String>.from(data['uids']));
        }
      }
      _loaded = true;
      if (kDebugMode) debugPrint('✅ Admin UIDs loaded: ${_cache.length}');
    } catch (e) {
      // Non-fatal — if the collection doesn't exist yet, no admins.
      _loaded = true;
      if (kDebugMode) debugPrint('⚠️ AdminService load warning: $e');
    }
  }

  /// Returns true if [uid] is in the admin list.
  static bool isAdmin(String uid) => _cache.contains(uid);

  /// For debug only — force reload.
  static Future<void> reload() async {
    _loaded = false;
    _cache.clear();
    await loadAdmins();
  }
}
