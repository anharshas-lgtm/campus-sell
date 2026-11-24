import 'package:cloud_firestore/cloud_firestore.dart';

class CampusModel {
  final String id;
  final String name;
  final String district;
  final String state;
  final List<String> colleges; // ← new field

  CampusModel({
    required this.id,
    required this.name,
    required this.district,
    required this.state,
    this.colleges = const [],
  });

  factory CampusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampusModel(
      id: doc.id,
      name: data['name'] ?? '',
      district: data['district'] ?? '',
      state: data['state'] ?? '',
      // ── colleges is a list of strings in Firestore ──────────────
      colleges: List<String>.from(data['colleges'] ?? []),
    );
  }

  // ── Also support fromMap for Algolia hits ─────────────────────────────────
  factory CampusModel.fromMap(String id, Map<String, dynamic> data) {
    return CampusModel(
      id: id,
      name: data['name'] ?? '',
      district: data['district'] ?? '',
      state: data['state'] ?? '',
      colleges: List<String>.from(data['colleges'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'district': district,
      'state': state,
      'colleges': colleges,
    };
  }
}