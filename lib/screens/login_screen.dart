import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';     // kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Feature flag ────────────────────────────────────────────────────
  // Phone OTP login is hidden for now (Google sign-in only).
  // Set to true to bring the phone OTP option back.
  static const bool _enablePhoneAuth = false;

  final AuthService _authService = AuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  String? _errorMessage;
  int _selectedMethod = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null && mounted) {
        setState(() => _errorMessage = 'Sign-in cancelled.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
        'Sign-in failed. Please check your internet connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // newly added otp verification for web also included

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() =>
      _errorMessage = 'Enter a valid 10-digit phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (kIsWeb) {
      // ── Web OTP flow ────────────────────────────────────────────────
      await _sendOtpWeb(phone);
    } else {
      // ── Android OTP flow ────────────────────────────────────────────
      await _authService.sendOtp(
        phoneNumber: phone,
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _otpSent = true;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('OTP sent successfully!'),
                  backgroundColor: Colors.green),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = error;
              _isLoading = false;
            });
          }
        },
        onAutoVerified: (credential) async {
          if (mounted) {
            setState(() => _isLoading = true);
            try {
              await _authService.signInWithCredential(credential);
            } catch (e) {
              setState(() => _errorMessage = e.toString());
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }
        },
      );
    }
  }

// ── Web-specific OTP using ConfirmationResult ─────────────────────────────
  ConfirmationResult? _confirmationResult;

  Future<void> _sendOtpWeb(String phone) async {
    try {
      final fullPhone = phone.startsWith('+') ? phone : '+91$phone';

      // Firebase handles reCAPTCHA automatically on web
      _confirmationResult =
      await FirebaseAuth.instance.signInWithPhoneNumber(fullPhone);

      if (mounted) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('OTP sent!'),
              backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'OTP failed: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb && _confirmationResult != null) {
        // ── Web OTP verify ──────────────────────────────────────────────
        final userCredential =
        await _confirmationResult!.confirm(otp);
        final user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .then((doc) async {
            if (!doc.exists) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({
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
          });
        }
      } else {
        // ── Android OTP verify ──────────────────────────────────────────
        if (_verificationId == null) {
          setState(() => _errorMessage = 'Please request OTP first.');
          return;
        }
        await _authService.verifyOtp(
            verificationId: _verificationId!, otp: otp);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() =>
        _errorMessage = 'Invalid OTP: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
// end of new web included otp

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              Image.asset(
                'assets/icon/icon.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 20),
              const Text('CampusSell',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple)),
              const SizedBox(height: 8),
              Text('Buy & sell within your campus',
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade500)),
              const SizedBox(height: 48),

              if (_selectedMethod == 0)
                _buildMethodSelector()
              else
                _buildPhoneFlow(),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      children: [
        // ── Google button — always fixed size, no image dependency ────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurple))
              : OutlinedButton(
            onPressed: _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Static G icon — no network image ────────────
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4285F4),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),

        // ── Phone OTP option — hidden unless _enablePhoneAuth is true ──
        if (_enablePhoneAuth) ...[
          const SizedBox(height: 16),

          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14)),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _selectedMethod = 1),
              icon: const Icon(Icons.phone_outlined,
                  color: Colors.deepPurple, size: 20),
              label: const Text(
                'Continue with Phone Number',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() {
            _selectedMethod = 0;
            _otpSent = false;
            _errorMessage = null;
            _phoneController.clear();
            _otpController.clear();
          }),
          icon: const Icon(Icons.arrow_back,
              size: 16, color: Colors.deepPurple),
          label: const Text('Back',
              style: TextStyle(color: Colors.deepPurple)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        const SizedBox(height: 12),

        Text(
          _otpSent ? 'Enter OTP' : 'Enter Phone Number',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Text(
          _otpSent
              ? 'OTP sent to +91 ${_phoneController.text.trim()}'
              : 'We will send a 6-digit OTP to verify your number.',
          style:
          TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 24),

        if (!_otpSent) ...[
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black87),
            decoration: InputDecoration(
              hintText: '10-digit number',
              hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 14),
              counterText: '',
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                child: const Text('+91',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: Colors.deepPurple)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Text('Send OTP',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ] else ...[
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 24,
                  letterSpacing: 8),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: Colors.deepPurple)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Text('Verify OTP',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                _otpSent = false;
                _otpController.clear();
                _errorMessage = null;
              }),
              child: const Text('Resend OTP',
                  style: TextStyle(color: Colors.deepPurple)),
            ),
          ),
        ],
      ],
    );
  }
}