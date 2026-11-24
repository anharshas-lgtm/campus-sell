import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ad_model.dart';
import '../config/cloudinary_config.dart';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Image compression settings (light compression) ──────────────────────
  // The compress package treats these as target/minimum dimensions, so the
  // shorter side ends up around this value. Raise it for sharper images.
  static const int _targetSize = 1280;
  static const int _quality = 85;
  // Images already smaller than this are uploaded as they are.
  static const int _skipBelowBytes = 300 * 1024;
  static const int _maxImages = 3;

  Stream<List<AdModel>> fetchCampusAds(String campusId) {
    return _firestore
        .collection('ads')
        .where('campusId', isEqualTo: campusId)
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => AdModel.fromFirestore(doc)).toList());
  }

  Stream<List<AdModel>> fetchUserAds(String userId) {
    return _firestore
        .collection('ads')
        .where('postedBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final ads = snapshot.docs
          .map((doc) => AdModel.fromFirestore(doc))
          .toList();
      ads.sort((a, b) =>
          (b.postedAt ?? DateTime(0)).compareTo(a.postedAt ?? DateTime(0)));
      return ads;
    });
  }

  /// Returns compressed JPEG bytes, or null when compression is skipped or
  /// fails (the caller then uploads the original file, so posting never breaks).
  Future<Uint8List?> _compressImage(File file) async {
    try {
      final originalSize = await file.length();
      if (originalSize < _skipBelowBytes) return null;

      final bytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: _targetSize,
        minHeight: _targetSize,
        quality: _quality,
        format: CompressFormat.jpeg,
      );

      // Keep the original if compression somehow made it bigger.
      if (bytes == null || bytes.length >= originalSize) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<String> _uploadSingleImage(File imageFile) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);
    final compressed = await _compressImage(imageFile);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset;

    if (compressed != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        compressed,
        filename: 'ad_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ));
    } else {
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));
    }

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final jsonData = json.decode(utf8.decode(responseData));
      return jsonData['secure_url'] as String;
    } else {
      throw Exception('Image upload failed: ${response.statusCode}');
    }
  }

  /// Uploads all images in parallel; the returned URLs keep the input order.
  Future<List<String>> uploadAdImages(List<File> images) {
    return Future.wait(images.map(_uploadSingleImage));
  }

  Future<void> postAd({
    required String title,
    required String description,
    required double price,
    required String contactNumber,
    required List<File> imageFiles,
    required String campusId,
    required String campusName,
    required String userId,
    required String userName,
    required String program,
    required String department,
    required String year,
  }) async {
    try {
      List<String> imageUrls = [];
      if (imageFiles.isNotEmpty) {
        imageUrls = await uploadAdImages(imageFiles);
      }
      await _firestore.collection('ads').add({
        'title': title.trim(),
        'description': description.trim(),
        'price': price,
        'contactNumber': contactNumber.trim(),
        'images': imageUrls,
        'campusId': campusId,
        'campusName': campusName,
        'postedBy': userId,
        'postedByName': userName,
        'postedByProgram': program,
        'postedByDepartment': department,
        'postedByYear': year,
        'postedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Failed to post ad: $e');
    }
  }

  Future<void> editAd({
    required String adId,
    required String title,
    required String description,
    required double price,
    required String contactNumber,
    required List<File> newImageFiles,
    required List<String> existingImageUrls,
    required String userId,
  }) async {
    try {
      final finalImageUrls = List<String>.from(existingImageUrls);

      // Only upload as many new images as will actually fit (max 3 total),
      // instead of uploading extras and then discarding them.
      final slotsLeft = _maxImages - finalImageUrls.length;
      if (newImageFiles.isNotEmpty && slotsLeft > 0) {
        final newUrls =
        await uploadAdImages(newImageFiles.take(slotsLeft).toList());
        finalImageUrls.addAll(newUrls);
      }

      await _firestore.collection('ads').doc(adId).update({
        'title': title.trim(),
        'description': description.trim(),
        'price': price,
        'contactNumber': contactNumber.trim(),
        'images': finalImageUrls,
      });
    } catch (e) {
      throw Exception('Failed to edit ad: $e');
    }
  }

  Future<void> deleteAd(AdModel ad) async {
    try {
      await _firestore.collection('ads').doc(ad.id).delete();
    } catch (e) {
      throw Exception('Failed to delete ad: $e');
    }
  }
}