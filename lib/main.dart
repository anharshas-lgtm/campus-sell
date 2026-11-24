import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/campus_selection_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

// ── MUST be top-level function — handles background messages ──────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  if (message.notification != null) {
    debugPrint(
        '🔔 Background message: ${message.notification!.title}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Register background message handler ──────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler);

  // ── Initialize notification service ──────────────────────────────────────
  await NotificationService().init();

  runApp(const MyApp());
}

// ── MyApp with lifecycle observer ─────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Re-subscribe when app comes back to foreground ────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _resubscribeIfNeeded();
    }
  }

  Future<void> _resubscribeIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>?;
      final campusId = data?['campusId']?.toString().trim() ?? '';

      if (campusId.isNotEmpty) {
        await NotificationService().subscribeToCampus(campusId);
      }
    } catch (e) {
      debugPrint('❌ Resubscribe error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusSell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
        ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// ── Auth Wrapper ──────────────────────────────────────────────────────────────
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (!userSnapshot.hasData ||
                !userSnapshot.data!.exists) {
              return const _LoadingScreen();
            }

            final data = userSnapshot.data!.data()
            as Map<String, dynamic>?;
            final campus =
                data?['campus']?.toString().trim() ?? '';
            final campusId =
                data?['campusId']?.toString().trim() ?? '';

            if (campus.isEmpty) {
              return const CampusSelectionScreen();
            }

            // ── Subscribe to FCM topic after token is confirmed ────
            if (campusId.isNotEmpty) {
              FirebaseMessaging.instance
                  .getToken()
                  .then((token) {
                if (token != null) {
                  debugPrint('✅ FCM Token confirmed, subscribing...');
                  NotificationService().subscribeToCampus(campusId);
                }
              });
            }

            return const MainScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}