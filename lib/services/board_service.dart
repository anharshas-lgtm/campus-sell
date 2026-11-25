import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../config/cloudinary_config.dart';
import '../constants/board_constants.dart';
import '../models/board_post_model.dart';
import 'groq_service.dart';

class BoardService {
  final _db = FirebaseFirestore.instance;

  // ── Cloudinary raw-upload endpoint (for non-image files) ──────────────────
  static String get _rawUploadUrl =>
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/raw/upload';

  // ── Image compression ─────────────────────────────────────────────────────
  static const int _targetSize  = 1280;
  static const int _quality     = 82;
  static const int _skipBelowKb = 200;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All active posts for a campus, newest first.
  Stream<List<BoardPostModel>> fetchBoardPosts(String campusId) {
    return _db
        .collection('board_posts')
        .where('campusId', isEqualTo: campusId)
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BoardPostModel.fromFirestore).toList());
  }

  /// Posts by the current user.
  Stream<List<BoardPostModel>> fetchUserPosts(String userId) {
    return _db
        .collection('board_posts')
        .where('postedBy', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BoardPostModel.fromFirestore).toList());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<String> createPost(BoardPostModel post) async {
    final ref = await _db.collection('board_posts').add(post.toMap());
    return ref.id;
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    data['editedAt'] = FieldValue.serverTimestamp();
    await _db.collection('board_posts').doc(postId).update(data);
  }

  /// Soft delete — sets isActive = false (owner action).
  Future<void> deactivatePost(String postId) async {
    await _db
        .collection('board_posts')
        .doc(postId)
        .update({'isActive': false});
  }

  /// Hard delete (admin only).
  Future<void> deletePost(String postId) async {
    await _db.collection('board_posts').doc(postId).delete();
  }

  Future<void> reportPost({
    required String postId,
    required String reportedBy,
    required String reason,
  }) async {
    await _db.collection('board_reports').add({
      'postId': postId,
      'reportedBy': reportedBy,
      'reason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── File validation ───────────────────────────────────────────────────────

  static String? validateFiles(List<PlatformFile> files) {
    if (files.length > kMaxFileCount) {
      return 'Maximum $kMaxFileCount files allowed.';
    }
    for (final f in files) {
      if (f.size > kMaxFileSizeBytes) {
        return '${f.name} exceeds the 5 MB limit.';
      }
    }
    return null;
  }

  // ── Cloudinary upload helpers ─────────────────────────────────────────────

  Future<String> _uploadImage(File file) async {
    final sizeKb = await file.length() ~/ 1024;
    Uint8List bytes;

    if (sizeKb > _skipBelowKb) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: _targetSize,
        minHeight: _targetSize,
        quality: _quality,
        keepExif: false,
      );
      bytes = compressed ?? await file.readAsBytes();
    } else {
      bytes = await file.readAsBytes();
    }

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: file.path.split('/').last));
    final res = await req.send();
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(await res.stream.toBytes()));
      return data['secure_url'] as String;
    }
    throw Exception('Image upload failed: ${res.statusCode}');
  }

  Future<String> _uploadRawFile(File file, String filename) async {
    final uri = Uri.parse(_rawUploadUrl);
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path,
          filename: filename));
    final res = await req.send();
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(await res.stream.toBytes()));
      return data['secure_url'] as String;
    }
    throw Exception('File upload failed: ${res.statusCode}');
  }

  Future<({List<BoardAttachment> attachments, String? imageUrl})> uploadFiles(
      List<PlatformFile> files) async {
    final attachments = <BoardAttachment>[];
    String? imageUrl;

    for (final f in files) {
      if (f.path == null) continue;
      final file = File(f.path!);
      final ext = f.extension?.toLowerCase() ?? '';
      final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
      final isPdf   = ext == 'pdf';
      final isWord  = ['doc', 'docx'].contains(ext);

      String type;
      String url;
      if (isImage) {
        type = 'image';
        url = await _uploadImage(file);
        imageUrl ??= url;
      } else if (isPdf) {
        type = 'pdf';
        url = await _uploadRawFile(file, f.name);
      } else if (isWord) {
        type = 'word';
        url = await _uploadRawFile(file, f.name);
      } else {
        type = 'other';
        url = await _uploadRawFile(file, f.name);
      }

      attachments.add(BoardAttachment(
        name: f.name,
        url: url,
        type: type,
        sizeKb: (f.size / 1024).round(),
      ));
    }
    return (attachments: attachments, imageUrl: imageUrl);
  }

  // ── Full post submission ──────────────────────────────────────────────────

  Future<String> submitPost({
    required String rawContent,
    required String campusId,
    required String postedBy,
    required String postedByName,
    String? postedByProgram,
    String? postedByDepartment,
    String? postedByYear,
    required String? userSelectedCategory,
    required List<PlatformFile> files,
    BoardPostModel? existingPost, // non-null = edit mode
    // Manual mode fields (skip AI if provided)
    GroqResult? manualData,
  }) async {
    // 1. Upload files
    final uploaded = files.isNotEmpty
        ? await uploadFiles(files)
        : (attachments: <BoardAttachment>[], imageUrl: null as String?);

    final finalImageUrl = uploaded.imageUrl ?? existingPost?.imageUrl;
    final allAttachments = [
      ...?existingPost?.attachments,
      ...uploaded.attachments,
    ];

    // 2. AI analysis (or use pre-built manual data)
    final groq = manualData ??
        await GroqService().analysePost(
          rawText: rawContent,
          userCategory: userSelectedCategory,
        );

    if (kDebugMode) {
      debugPrint(groq.usedFallback
          ? '⚠️ Using fallback post data'
          : '✅ AI analysis succeeded');
    }

    // 3. Build flat model
    final post = BoardPostModel(
      id: existingPost?.id ?? '',
      campusId: campusId,
      category: groq.category,
      urgencyLevel: groq.urgencyLevel,
      isImportant: groq.isImportant,
      title: groq.title,
      summary: groq.summary,
      details: groq.details,
      rawContent: rawContent,
      eventDate: groq.eventDate,
      deadlineAt: groq.deadlineAt,
      venue: groq.venue,
      contactName: groq.contactName,
      contactPhone: groq.contactPhone,
      contactEmail: groq.contactEmail,
      links: groq.links,
      attachments: allAttachments,
      imageUrl: finalImageUrl,
      tags: groq.tags,
      postedBy: postedBy,
      postedByName: postedByName,
      postedByProgram: postedByProgram,
      postedByDepartment: postedByDepartment,
      postedByYear: postedByYear,
    );

    // 4. Write to Firestore
    if (existingPost != null) {
      final map = post.toMap()..remove('postedAt');
      await updatePost(existingPost.id, map);
      return existingPost.id;
    } else {
      return createPost(post);
    }
  }
}
