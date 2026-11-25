import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/utility_service.dart';
import 'utils/my_campus_screen.dart';
import 'utils/report_problem_screen.dart';
import 'utils/my_ads_screen.dart';
import 'utils/my_board_posts_screen.dart';
import 'utils/contact_us_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kPrograms = [
  'UG', 'PG', 'BSc', 'MSc', 'BA', 'MA', 'BCom', 'MCom',
  'BTech', 'MTech', 'BCA', 'MCA', 'MBA', 'PhD', 'Diploma', 'Other',
];

const List<String> kYears = [
  '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year',
];

// ── Shared input decoration ───────────────────────────────────────────────────
InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFFAAAAAA),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: Icon(icon, color: Colors.deepPurple, size: 20),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.deepPurple)),
    // No labelText — hint only, no floating label
    floatingLabelBehavior: FloatingLabelBehavior.never,
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  String? _selectedProgram;
  String? _selectedYear;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _startEditing(UserModel profile) {
    _nameController.text = profile.name;
    _departmentController.text = profile.department;
    _selectedProgram =
    kPrograms.contains(profile.program) ? profile.program : null;
    _selectedYear = kYears.contains(profile.year) ? profile.year : null;
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _userService.updateUserProfile(
        userId: user!.uid,
        name: _nameController.text,
        program: _selectedProgram ?? '',
        department: _departmentController.text,
        year: _selectedYear ?? '',
      );
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Profile updated!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── No permission request needed ─────────────────────────────────
  Future<void> _updateProfilePhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final url = await _userService.uploadProfilePhoto(
          File(picked.path), user!.uid);
      await _userService.updateProfilePhoto(
          userId: user!.uid, photoUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Profile photo updated!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account, '
              'all your ads, and all your data. '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: Colors.deepPurple),
        ),
      );
    }

    try {
      final userId = user!.uid;
      final firestore = FirebaseFirestore.instance;

      // ── IMPORTANT: Delete ALL Firestore data BEFORE deleting Auth ──
      // Once Auth is deleted, all Firestore operations will be denied

      // Step 1 — Delete all ads by this user
      final adsSnapshot = await firestore
          .collection('ads')
          .where('postedBy', isEqualTo: userId)
          .get();
      for (final doc in adsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Step 2 — Delete campus requests by this user
      final requestsSnapshot = await firestore
          .collection('campus_requests')
          .where('requestedBy', isEqualTo: userId)
          .get();
      for (final doc in requestsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Step 3 — Delete reports by this user
      try {
        final reportsSnapshot = await firestore
            .collection('reports')
            .where('userId', isEqualTo: userId)
            .get();
        for (final doc in reportsSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (_) {
        // reports may not exist — continue
      }

      // Step 4 — Delete ad_reports by this user
      try {
        final adReportsSnapshot = await firestore
            .collection('ad_reports')
            .where('reportedBy', isEqualTo: userId)
            .get();
        for (final doc in adReportsSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (_) {
        // ad_reports may not exist — continue
      }

      // Step 5 — Delete user Firestore document
      await firestore.collection('users').doc(userId).delete();

      // ── Only AFTER all Firestore data is deleted — delete Auth ──────
      // Step 6 — Delete Firebase Auth account
      await FirebaseAuth.instance.currentUser?.delete();

      // Step 7 — Sign out
      await _authService.signOut();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

    } on FirebaseAuthException catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (e.code == 'requires-recent-login') {
        // User needs to re-authenticate before deleting Auth account
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'For security, please sign out and sign back in, '
                    'then try deleting your account again.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // delete end

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () async => await _authService.signOut(),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.red, fontSize: 14)),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.streamUserProfile(user!.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileCard(profile),
                const SizedBox(height: 12),
                _buildSettingsSection(profile),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(UserModel profile) {
    final photoUrl = profile.photoUrl.isNotEmpty
        ? profile.photoUrl
        : (user?.photoURL ?? '');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.deepPurple.shade100,
                backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple))
                    : null,
              ),
              if (_isUploadingPhoto)
                Positioned.fill(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.black45,
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _updateProfilePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isEditing) ...[
            // ── Edit Mode ─────────────────────────────────────────────
            _textField(
                controller: _nameController,
                hint: 'Your Name',
                icon: Icons.person_outline),
            const SizedBox(height: 12),
            _dropdownField(
              hint: 'Select Program',
              icon: Icons.school_outlined,
              value: _selectedProgram,
              items: kPrograms,
              onChanged: (v) => setState(() => _selectedProgram = v),
            ),
            const SizedBox(height: 12),
            _textField(
                controller: _departmentController,
                hint: 'Department (e.g. Computer Science)',
                icon: Icons.category_outlined),
            const SizedBox(height: 12),
            _dropdownField(
              hint: 'Select Year',
              icon: Icons.calendar_today_outlined,
              value: _selectedYear,
              items: kYears,
              onChanged: (v) => setState(() => _selectedYear = v),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: _isSaving
                      ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Save',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ] else ...[
            // ── View Mode ─────────────────────────────────────────────
            Text(profile.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            if (profile.email.isNotEmpty)
              Text(profile.email,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500)),
            if (profile.phone.isNotEmpty)
              Text(profile.phone,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 12),

            if (!profile.isComplete)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Complete your profile to post ads.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (profile.campus.isNotEmpty)
                  _badge(Icons.location_city_outlined, profile.campus),
                if (profile.program.isNotEmpty)
                  _badge(Icons.school_outlined, profile.program),
                if (profile.department.isNotEmpty)
                  _badge(Icons.category_outlined, profile.department),
                if (profile.year.isNotEmpty)
                  _badge(Icons.calendar_today_outlined, profile.year),
              ],
            ),
            if (profile.district.isNotEmpty ||
                profile.state.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [profile.district, profile.state]
                    .where((s) => s.isNotEmpty)
                    .join(', '),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _startEditing(profile),
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: Colors.deepPurple),
              label: const Text('Edit Profile',
                  style: TextStyle(color: Colors.deepPurple)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSection(UserModel profile) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── My Activity ───────────────────────────────────────────────
          _sectionLabel('My Activity'),
          _tile(Icons.campaign_outlined, 'My Board Posts', Colors.deepPurple,
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyBoardPostsScreen()))),
          _tile(Icons.sell_outlined, 'My Ads', Colors.deepPurple,
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyAdsScreen()))),
          _tile(
              Icons.location_city_outlined, 'My Campus', Colors.indigo,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MyCampusScreen(profile: profile)))),

          // ── Support ───────────────────────────────────────────────────
          _sectionLabel('Support'),
          _tile(Icons.flag_outlined, 'Report a Problem', Colors.red,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReportProblemScreen()))),
          _tile(Icons.mail_outline, 'Contact Us', Colors.teal,
                  () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ContactUsScreen()))),

          // ── Info ──────────────────────────────────────────────────────
          _sectionLabel('Info'),
          _tile(Icons.help_outline, 'Help & FAQ', Colors.orange,
                  () => UtilityService.openPage(
                context: context,
                documentId: 'help_faq',
                pageName: 'Help & FAQ',
              )),
          _tile(
              Icons.info_outline, 'About CampusSell', Colors.deepPurple,
                  () => UtilityService.openPage(
                context: context,
                documentId: 'about_us',
                pageName: 'About CampusSell',
              )),
          _tile(Icons.description_outlined, 'Terms & Conditions',
              Colors.blueGrey,
                  () => UtilityService.openPage(
                context: context,
                documentId: 'terms_conditions',
                pageName: 'Terms & Conditions',
              )),
          _tile(Icons.privacy_tip_outlined, 'Privacy Policy',
              Colors.blueGrey,
                  () => UtilityService.openPage(
                context: context,
                documentId: 'privacy_policy',
                pageName: 'Privacy Policy',
              )),

          // ── Account ───────────────────────────────────────────────────
          _sectionLabel('Account'),
          _tile(Icons.delete_forever_outlined, 'Delete Account',
              Colors.red, _deleteAccount),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.5)),
    );
  }

  Widget _tile(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500)),
      trailing:
      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.deepPurple),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.deepPurple)),
      ]),
    );
  }

  // ── Shared text field — consistent style ──────────────────────────────────
  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black87,
      ),
      decoration: _inputDecoration(hint: hint, icon: icon),
    );
  }

  // ── Shared dropdown — consistent style ───────────────────────────────────
  Widget _dropdownField({
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black87,
      ),
      decoration: _inputDecoration(hint: hint, icon: icon),
      hint: Text(hint,
          style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 14,
              fontWeight: FontWeight.w400)),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    );
  }
}