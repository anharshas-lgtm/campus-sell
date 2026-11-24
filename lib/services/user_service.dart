import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../config/cloudinary_config.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> streamUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc =
      await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String program,
    required String department,
    required String year,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'name': name.trim(),
        'program': program.trim(),
        'department': department.trim(),
        'year': year.trim(),
      });
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // ── Check if profile is complete ─────────────────────────────────────────
  bool isProfileComplete(UserModel profile) {
    return profile.name.isNotEmpty &&
        profile.program.isNotEmpty &&
        profile.department.isNotEmpty &&
        profile.year.isNotEmpty;
  }

  // ── Upload profile picture to Cloudinary ──────────────────────────────────
  Future<String> uploadProfilePhoto(File imageFile, String userId) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['public_id'] = 'profile_$userId'
      ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final jsonData = json.decode(utf8.decode(responseData));
      return jsonData['secure_url'] as String;
    } else {
      throw Exception('Photo upload failed: ${response.statusCode}');
    }
  }

  // ── Save photo URL to Firestore ───────────────────────────────────────────
  Future<void> updateProfilePhoto({
    required String userId,
    required String photoUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': photoUrl,
      });
    } catch (e) {
      throw Exception('Failed to update photo: $e');
    }
  }
}