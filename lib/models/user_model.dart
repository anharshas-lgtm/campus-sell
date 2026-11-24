import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String campus;
  final String campusId;
  final String district;
  final String state;
  final String program;
  final String department;
  final String year;
  final String photoUrl;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.campus,
    required this.campusId,
    required this.district,
    required this.state,
    required this.program,
    required this.department,
    required this.year,
    required this.photoUrl,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      campus: data['campus'] ?? '',
      campusId: data['campusId'] ?? '',
      district: data['district'] ?? '',
      state: data['state'] ?? '',
      program: data['program'] ?? '',
      department: data['department'] ?? '',
      year: data['year'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'campus': campus,
      'campusId': campusId,
      'district': district,
      'state': state,
      'program': program,
      'department': department,
      'year': year,
      'photoUrl': photoUrl,
    };
  }

  // ── Check if profile is complete ─────────────────────────────────────────
  bool get isComplete =>
      name.isNotEmpty &&
          program.isNotEmpty &&
          department.isNotEmpty &&
          year.isNotEmpty;
}