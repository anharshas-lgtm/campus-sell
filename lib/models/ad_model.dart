import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String contactNumber;
  final List<String> images;
  final String campusId;
  final String campusName;
  final String postedBy;
  final String postedByName;
  final String postedByProgram;      // UG, PG, PhD etc.
  final String postedByDepartment;   // CS, Agriculture etc.
  final String postedByYear;
  final DateTime? postedAt;
  final bool isActive;

  AdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.contactNumber,
    required this.images,
    required this.campusId,
    required this.campusName,
    required this.postedBy,
    required this.postedByName,
    required this.postedByProgram,
    required this.postedByDepartment,
    required this.postedByYear,
    this.postedAt,
    required this.isActive,
  });

  factory AdModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      contactNumber: data['contactNumber'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      campusId: data['campusId'] ?? '',
      campusName: data['campusName'] ?? '',
      postedBy: data['postedBy'] ?? '',
      postedByName: data['postedByName'] ?? '',
      postedByProgram: data['postedByProgram'] ?? '',
      postedByDepartment: data['postedByDepartment'] ?? '',
      postedByYear: data['postedByYear'] ?? '',
      postedAt: (data['postedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'contactNumber': contactNumber,
      'images': images,
      'campusId': campusId,
      'campusName': campusName,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'postedByProgram': postedByProgram,
      'postedByDepartment': postedByDepartment,
      'postedByYear': postedByYear,
      'postedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}