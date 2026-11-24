import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ad_model.dart';
import '../config/cloudinary_config.dart';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<String> _uploadSingleImage(File imageFile) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final jsonData = json.decode(utf8.decode(responseData));
      return jsonData['secure_url'] as String;
    } else {
      throw Exception('Image upload failed: ${response.statusCode}');
    }
  }

  Future<List<String>> uploadAdImages(List<File> images) async {
    final List<String> urls = [];
    for (final image in images) {
      urls.add(await _uploadSingleImage(image));
    }
    return urls;
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
      List<String> finalImageUrls = List.from(existingImageUrls);
      if (newImageFiles.isNotEmpty) {
        final newUrls = await uploadAdImages(newImageFiles);
        finalImageUrls.addAll(newUrls);
        if (finalImageUrls.length > 3) {
          finalImageUrls = finalImageUrls.sublist(0, 3);
        }
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