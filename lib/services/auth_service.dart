import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';           // ← add this
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Web needs explicit client ID ──────────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
        : null,
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ── Web: use popup flow ───────────────────────────────────────
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final UserCredential userCredential =
        await _auth.signInWithPopup(googleProvider);

        final User? user = userCredential.user;
        if (user != null) await _saveUserToFirestore(user);
        return user;
      } else {
        // ── Android: native Google Sign-In ────────────────────────────
        final GoogleSignInAccount? googleUser =
        await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
        await _auth.signInWithCredential(credential);

        final User? user = userCredential.user;
        if (user != null) await _saveUserToFirestore(user);
        return user;
      }
    } on FirebaseAuthException catch (e) {
      throw Exception('FirebaseAuth: ${e.code} — ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // ── Phone: Send OTP ───────────────────────────────────────────────────────
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.startsWith('+')
            ? phoneNumber
            : '+91$phoneNumber',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_handleAuthError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Failed to send OTP: ${e.toString()}');
    }
  }

  // ── Phone: Verify OTP ─────────────────────────────────────────────────────
  Future<User?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) await _saveUserToFirestore(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('OTP verification failed: ${e.toString()}');
    }
  }

  Future<User?> signInWithCredential(
      PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) await _saveUserToFirestore(user);
      return user;
    } catch (e) {
      throw Exception('Sign-in failed: ${e.toString()}');
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    final DocumentReference userDoc =
    _firestore.collection('users').doc(user.uid);
    final DocumentSnapshot snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'campus': '',
        'campusId': '',
        'district': '',
        'state': '',
        'program': '',
        'department': '',
        'year': '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: ${e.toString()}');
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}