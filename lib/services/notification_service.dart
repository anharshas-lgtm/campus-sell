import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      debugPrint('FCM initialization skipped on Web');
      return;
    }

    // Keep the remaining existing initialization code unchanged.

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

    // ── Create Android notification channel ───────────────────────────────
    // ← Key fix: entire expression on ONE line — no line breaks in generics
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);

    // ── Init local notifications ──────────────────────────────────────────
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

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

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
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

  // ── Subscribe to campus topic ─────────────────────────────────────────────
  Future<void> subscribeToCampus(String campusId) async {
    if (campusId.isEmpty) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        if (kDebugMode) print('❌ No FCM token yet — retrying in 3s...');
        await Future.delayed(const Duration(seconds: 3));
        await subscribeToCampus(campusId);
        return;
      }

      final topic = 'campus_${campusId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _messaging.subscribeToTopic(topic);

      if (kDebugMode) {
        print('✅ Subscribed to topic: $topic');
        print('✅ campusId: $campusId');
        print('✅ FCM Token: $token');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Subscribe error: $e');
    }
  }

  // ── Unsubscribe ───────────────────────────────────────────────────────────
  Future<void> unsubscribeFromCampus(String campusId) async {
    if (campusId.isEmpty) return;
    try {
      final topic = 'campus_${campusId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) print('🔕 Unsubscribed from: $topic');
    } catch (e) {
      if (kDebugMode) print('❌ Unsubscribe error: $e');
    }
  }
}