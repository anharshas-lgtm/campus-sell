import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ad_service.dart';
import '../models/ad_model.dart';
import '../models/user_model.dart';
import 'main_screen.dart';

const List<String> kPrograms = [
  'UG', 'PG', 'BSc', 'MSc', 'BA', 'MA', 'BCom', 'MCom',
  'BTech', 'MTech', 'BCA', 'MCA', 'MBA', 'PhD', 'Diploma', 'Other',
];

const List<String> kYears = [
  '1st Year', '2nd Year', '3rd Year',
  '4th Year', '5th Year',
];

InputDecoration _fieldDecoration({
  required String hint,
  required IconData icon,
  String? helperText,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 14,
        fontWeight: FontWeight.w400),
    helperText: helperText,
    helperStyle: TextStyle(
        fontSize: 11,
        color: Colors.grey.shade500,
        fontStyle: FontStyle.italic),
    prefixIcon: Icon(icon, color: Colors.deepPurple, size: 20),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: Colors.deepPurple, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    floatingLabelBehavior: FloatingLabelBehavior.never,
  );
}

class PostAdScreen extends StatefulWidget {
  final AdModel? editAd;
  const PostAdScreen({super.key, this.editAd});

  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdService _adService = AdService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _contactController = TextEditingController();

  List<File> _newImageFiles = [];
  List<String> _existingImageUrls = [];
  bool _isPosting = false;

  bool get _isEditMode => widget.editAd != null;
  int get _totalImages =>
      _existingImageUrls.length + _newImageFiles.length;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final ad = widget.editAd!;
      _titleController.text = ad.title;
      _descController.text = ad.description;
      _priceController.text = ad.price.toStringAsFixed(0);
      _contactController.text = ad.contactNumber;
      _existingImageUrls = List.from(ad.images);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // ── No permission request needed — Photo Picker handles it ───────
  Future<void> _pickImage() async {
    if (_totalImages >= 3) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      // ── This tells image_picker to use Photo Picker on Android 13+ ──
    );

    if (picked != null) {
      setState(() => _newImageFiles.add(File(picked.path)));
    }
  }

  Future<void> _submitAd(UserModel profile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isPosting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      if (_isEditMode) {
        await _adService.editAd(
          adId: widget.editAd!.id,
          title: _titleController.text,
          description: _descController.text,
          price: double.tryParse(_priceController.text) ?? 0,
          contactNumber: _contactController.text,
          newImageFiles: _newImageFiles,
          existingImageUrls: _existingImageUrls,
          userId: user.uid,
        );
      } else {
        await _adService.postAd(
          title: _titleController.text,
          description: _descController.text,
          price: double.tryParse(_priceController.text) ?? 0,
          contactNumber: _contactController.text,
          imageFiles: _newImageFiles,
          campusId: profile.campusId,
          campusName: profile.campus,
          userId: user.uid,
          userName: profile.name,
          program: profile.program,
          department: profile.department,
          year: profile.year,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditMode
              ? '✅ Ad updated successfully!'
              : '✅ Ad posted successfully!'),
          backgroundColor: Colors.green,
        ));
        if (!_isEditMode) {
          _formKey.currentState!.reset();
          setState(() {
            _newImageFiles = [];
            _existingImageUrls = [];
            _titleController.clear();
            _descController.clear();
            _priceController.clear();
            _contactController.clear();
          });
          // Switch to Sell tab after posting
          MainScreen.tabNotifier.value = 1;
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditMode ? 'Edit Ad' : 'Post an Ad',
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      // ── Stream builder listens to profile in real-time ──────────────────
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Build UserModel from live Firestore snapshot
          UserModel? profile;
          if (snapshot.hasData && snapshot.data!.exists) {
            profile = UserModel.fromFirestore(snapshot.data!);
          }

          // Profile incomplete check from live data
          final profileIncomplete =
              profile == null || !profile.isComplete;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Profile incomplete banner ──────────────────────
                  if (profileIncomplete) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_outlined,
                                  color: Colors.orange.shade700,
                                  size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Complete your profile to post ads.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Switch to Profile tab instantly
                                MainScreen.tabNotifier.value = 3;
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                Colors.orange.shade700,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.person_outline,
                                  color: Colors.white, size: 18),
                              label: const Text(
                                'Go to Profile',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Ad form (locked if profile incomplete) ─────────
                  Opacity(
                    opacity: profileIncomplete ? 0.35 : 1.0,
                    child: AbsorbPointer(
                      absorbing: profileIncomplete,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImageSection(),
                          const SizedBox(height: 24),
                          _formField(
                            controller: _titleController,
                            hint: 'Title (e.g. Physics Textbook)',
                            icon: Icons.title,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Title is required'
                                : null,
                          ),
                          _formField(
                            controller: _descController,
                            hint: 'Describe the item...',
                            icon: Icons.description_outlined,
                            maxLines: 4,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Description is required'
                                : null,
                          ),
                          _formField(
                            controller: _priceController,
                            hint: 'Price (₹)',
                            icon: Icons.currency_rupee,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Price is required';
                              if (double.tryParse(v) == null)
                                return 'Enter valid price';
                              return null;
                            },
                          ),
                          _formField(
                            controller: _contactController,
                            hint: 'WhatsApp / Contact Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            helperText:
                            'This number will be used by buyers to contact you.',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Contact number is required';
                              if (v.trim().length < 10)
                                return 'Enter valid number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isPosting
                                  ? null
                                  : () => _submitAd(profile!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14)),
                              ),
                              child: _isPosting
                                  ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5))
                                  : Text(
                                  _isEditMode
                                      ? 'Update Ad'
                                      : 'Post Ad',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Photos',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('(Optional · $_totalImages/3)',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingImageUrls.asMap().entries.map((e) =>
                  _imageTile(
                      child:
                      Image.network(e.value, fit: BoxFit.cover),
                      onRemove: () => setState(() =>
                          _existingImageUrls.removeAt(e.key)))),
              ..._newImageFiles.asMap().entries.map((e) => _imageTile(
                  child: Image.file(e.value, fit: BoxFit.cover),
                  onRemove: () =>
                      setState(() => _newImageFiles.removeAt(e.key)))),
              if (_totalImages < 3) _addPhotoButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageTile(
      {required Widget child, required VoidCallback onRemove}) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 100, height: 100, child: child)),
        Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
                onTap: onRemove,
                child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white)))),
      ]),
    );
  }

  Widget _addPhotoButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.deepPurple.withOpacity(0.3)),
        ),
        child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  color: Colors.deepPurple, size: 28),
              SizedBox(height: 6),
              Text('Add Photo',
                  style: TextStyle(
                      fontSize: 11, color: Colors.deepPurple)),
            ]),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87),
        decoration:
        _fieldDecoration(hint: hint, icon: icon, helperText: helperText),
      ),
    );
  }
}