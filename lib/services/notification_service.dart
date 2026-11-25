import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'New Listings',
    description: 'Notifications for new ads on your campus',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _boardChannel =
      AndroidNotificationChannel(
    'campus_board_channel',
    'Campus Board',
    description: 'Notifications for new Campus Board posts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _isBoardSupported = false;

  /// Whether the running app version (>= 2.0.0) should receive Campus Board
  /// push notifications.
  bool get isBoardNotificationsSupported => _isBoardSupported;

  /// Returns true if [version] (e.g. "2.0.0" or "2.0.0+16") is >= [major].[minor].[patch].
  static bool isVersionAtLeast(
    String version, {
    int major = 2,
    int minor = 0,
    int patch = 0,
  }) {
    final clean = version.split('+').first.split('-').first.trim();
    final parts = clean.split('.');
    final vMajor = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final vMinor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final vPatch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    if (vMajor != major) return vMajor > major;
    if (vMinor != minor) return vMinor > minor;
    return vPatch >= patch;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final info = await PackageInfo.fromPlatform();
      _isBoardSupported = isVersionAtLeast(info.version, major: 2, minor: 0, patch: 0);
      if (kDebugMode) {
        print('📦 App version: ${info.version} (board notifications: $_isBoardSupported)');
      }
    } catch (e) {
      _isBoardSupported = false;
      if (kDebugMode) print('⚠️ Could not read app version: $e');
    }

    if (kIsWeb) {
      debugPrint('FCM initialization skipped on Web');
      return;
    }

    // ── Request permission ────────────────────────────────────────────────
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('🔔 FCM Permission: ${settings.authorizationStatus}');
    }

    // ── Create Android notification channels ──────────────────────────────
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_boardChannel);

    // ── Init local notifications ──────────────────────────────────────────
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // ── Handle foreground notifications ──────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📩 Foreground message: ${message.notification?.title}');
      }

      final notification = message.notification;
      if (notification == null) return;

      // Pick channel based on data tag
      final isBoardPost = message.data['type'] == 'board_post';
      final chan = isBoardPost ? _boardChannel : _channel;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            chan.id,
            chan.name,
            channelDescription: chan.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    });

    // ── Print FCM token for debugging ─────────────────────────────────────
    if (kDebugMode) {
      final token = await _messaging.getToken();
      print('📱 FCM Token: $token');
    }
  }

  String _campusTopic(String campusId) =>
      'campus_${campusId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  /// Version-gated Campus Board topic (only app versions >= 2.0.0 subscribe).
  String _boardTopic(String campusId) => '${_campusTopic(campusId)}_board_v2';

  // ── Subscribe to campus topic ─────────────────────────────────────────────
  Future<void> subscribeToCampus(String campusId) async {
    if (campusId.isEmpty) return;
    try {
      final topic = _campusTopic(campusId);
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) print('🔔 Subscribed to: $topic');

      final boardTopic = _boardTopic(campusId);
      if (_isBoardSupported) {
        await _messaging.subscribeToTopic(boardTopic);
        if (kDebugMode) print('🔔 Subscribed to board topic: $boardTopic');
      } else {
        await _messaging.unsubscribeFromTopic(boardTopic);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Subscribe error: $e');
    }
  }

  // ── Unsubscribe ───────────────────────────────────────────────────────────
  Future<void> unsubscribeFromCampus(String campusId) async {
    if (campusId.isEmpty) return;
    try {
      final topic = _campusTopic(campusId);
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) print('🔕 Unsubscribed from: $topic');

      final boardTopic = _boardTopic(campusId);
      await _messaging.unsubscribeFromTopic(boardTopic);
      if (kDebugMode) print('🔕 Unsubscribed from board topic: $boardTopic');
    } catch (e) {
      if (kDebugMode) print('❌ Unsubscribe error: $e');
    }
  }
}
