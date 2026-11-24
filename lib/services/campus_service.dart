import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campus_model.dart';
import '../config/algolia_config.dart';

class CampusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Fetch all campuses from Firestore ─────────────────────────────────────
  Future<List<CampusModel>> fetchCampuses() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('campuses')
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) => CampusModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch campuses: $e');
    }
  }

  // ── Search via Algolia REST API ───────────────────────────────────────────
  Future<List<CampusModel>> searchCampusesAlgolia(String query) async {
    if (query.trim().isEmpty) return [];

    if (kDebugMode) {
      print('🔍 Algolia query: $query');
      print('🔍 Algolia URL: ${AlgoliaConfig.searchUrl}');
    }

    try {
      final response = await http.post(
        Uri.parse(AlgoliaConfig.searchUrl),
        headers: {
          'X-Algolia-Application-Id': AlgoliaConfig.appId,
          'X-Algolia-API-Key': AlgoliaConfig.searchKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'query': query.trim(),
          'hitsPerPage': 20,
        }),
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('🔍 Algolia status: ${response.statusCode}');
        print('🔍 Algolia response: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List hits = data['hits'] ?? [];

        if (kDebugMode) print('✅ Algolia hits: ${hits.length}');

        return hits.map((hit) {
          return CampusModel.fromMap(
            hit['objectID'] ?? '',
            Map<String, dynamic>.from(hit),
          );
        }).toList();
      } else {
        if (kDebugMode) {
          print('❌ Algolia error: ${response.statusCode}');
          print('❌ Body: ${response.body}');
        }
        throw Exception('Algolia ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Algolia exception: $e');
      throw Exception('Search failed: $e');
    }
  }

  // ── Local filter — also searches inside colleges list ────────────────────
  List<CampusModel> filterLocally(
      List<CampusModel> campuses, String query) {
    if (query.trim().isEmpty) return campuses;
    final lower = query.toLowerCase();
    return campuses.where((c) {
      // Match university name, district, state
      if (c.name.toLowerCase().contains(lower)) return true;
      if (c.district.toLowerCase().contains(lower)) return true;
      if (c.state.toLowerCase().contains(lower)) return true;
      // ── Also match any college inside the list ────────────────────
      if (c.colleges.any(
              (college) => college.toLowerCase().contains(lower))) {
        return true;
      }
      return false;
    }).toList();
  }

  Future<void> submitCampusRequest({
    required String name,
    required String district,
    required String state,
    required String userId,
  }) async {
    try {
      final existing = await _firestore
          .collection('campus_requests')
          .where('name', isEqualTo: name.trim())
          .where('district', isEqualTo: district.trim())
          .where('state', isEqualTo: state.trim())
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception(
            'A request for this campus already exists. Please wait for verification.');
      }

      await _firestore.collection('campus_requests').add({
        'name': name.trim(),
        'district': district.trim(),
        'state': state.trim(),
        'requestedBy': userId,
        'requestedAt': FieldValue.serverTimestamp(),
        'verified': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserCampus({
    required String userId,
    required CampusModel campus,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'campus': campus.name,
        'campusId': campus.id,
        'district': campus.district,
        'state': campus.state,
      });
    } catch (e) {
      throw Exception('Failed to update campus: $e');
    }
  }
}