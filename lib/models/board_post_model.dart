import 'package:cloud_firestore/cloud_firestore.dart';

// ── Simple link ────────────────────────────────────────────────────────────────

class BoardLink {
  final String url;
  final String? label;

  const BoardLink({required this.url, this.label});

  factory BoardLink.fromMap(Map<String, dynamic> m) => BoardLink(
        url: m['url'] as String? ?? '',
        label: m['label'] as String?,
      );

  Map<String, dynamic> toMap() => {'url': url, 'label': label};
}

// ── Attachment ─────────────────────────────────────────────────────────────────

class BoardAttachment {
  final String name;
  final String url;
  final String type; // 'image' | 'pdf' | 'word' | 'other'
  final int sizeKb;

  const BoardAttachment({
    required this.name,
    required this.url,
    required this.type,
    required this.sizeKb,
  });

  factory BoardAttachment.fromMap(Map<String, dynamic> m) => BoardAttachment(
        name: m['name'] as String? ?? '',
        url: m['url'] as String? ?? '',
        type: m['type'] as String? ?? 'other',
        sizeKb: (m['sizeKb'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'url': url, 'type': type, 'sizeKb': sizeKb};
}

// ── Main post model (flat) ─────────────────────────────────────────────────────

class BoardPostModel {
  final String id;
  final String campusId;

  // Core fields
  final String category;
  final String urgencyLevel; // low | medium | high | critical
  final bool isImportant;
  final String title;

  // AI-extracted content
  final String summary;
  final String details;
  final String rawContent;

  // Dates
  final DateTime? eventDate;
  final DateTime? deadlineAt;

  // Location
  final String? venue;

  // Contact
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;

  // Links & attachments
  final List<BoardLink> links;
  final List<BoardAttachment> attachments;
  final String? imageUrl;

  // Tags
  final List<String> tags;

  // Poster info
  final String postedBy;
  final String postedByName;
  final String? postedByProgram;
  final String? postedByDepartment;
  final String? postedByYear;
  final DateTime? postedAt;
  final DateTime? editedAt;

  final bool isActive;

  const BoardPostModel({
    this.id = '',
    required this.campusId,
    this.category = 'general',
    this.urgencyLevel = 'low',
    this.isImportant = false,
    required this.title,
    this.summary = '',
    this.details = '',
    required this.rawContent,
    this.eventDate,
    this.deadlineAt,
    this.venue,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.links = const [],
    this.attachments = const [],
    this.imageUrl,
    this.tags = const [],
    required this.postedBy,
    required this.postedByName,
    this.postedByProgram,
    this.postedByDepartment,
    this.postedByYear,
    this.postedAt,
    this.editedAt,
    this.isActive = true,
  });

  /// The soonest upcoming deadline/date.
  DateTime? get nearestDeadline => deadlineAt ?? eventDate;

  factory BoardPostModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    DateTime? _ts(String key) =>
        d[key] != null ? (d[key] as Timestamp).toDate() : null;

    List<T> _list<T>(String key, T Function(Map<String, dynamic>) fn) {
      final raw = d[key];
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw).map(fn).toList();
    }

    String? parseVenue(dynamic raw) {
      if (raw is String) return raw;
      if (raw is Map) {
        final parts = [
          raw['name'],
          raw['block'],
          raw['floor'],
          raw['room'],
          raw['campusArea'],
        ].whereType<String>().where((p) => p.isNotEmpty).join(', ');
        return parts.isEmpty ? null : parts;
      }
      return null;
    }

    // Fallback for old v3 nested contacts list if flat fields are absent
    final rawContacts = d['contacts'];
    final firstContact = (rawContacts is List && rawContacts.isNotEmpty && rawContacts.first is Map)
        ? Map<String, dynamic>.from(rawContacts.first as Map)
        : null;

    return BoardPostModel(
      id: doc.id,
      campusId: d['campusId'] ?? '',
      category: d['category'] ?? 'general',
      urgencyLevel: d['urgencyLevel'] ?? 'low',
      isImportant: d['isImportant'] ?? false,
      title: d['title'] ?? '',
      summary: d['summary'] ?? '',
      details: d['details'] ?? '',
      rawContent: d['rawContent'] ?? '',
      eventDate: _ts('eventDate'),
      deadlineAt: _ts('deadlineAt'),
      venue: parseVenue(d['venue']),
      contactName: (d['contactName'] as String?) ?? (firstContact?['name'] as String?),
      contactPhone: (d['contactPhone'] as String?) ??
          (firstContact?['phone'] as String?) ??
          (firstContact?['whatsapp'] as String?),
      contactEmail: (d['contactEmail'] as String?) ?? (firstContact?['email'] as String?),
      links: _list('links', BoardLink.fromMap),
      attachments: _list('attachments', BoardAttachment.fromMap),
      imageUrl: d['imageUrl'] as String?,
      tags: List<String>.from(d['tags'] ?? []),
      postedBy: d['postedBy'] ?? '',
      postedByName: d['postedByName'] ?? '',
      postedByProgram: d['postedByProgram'] as String?,
      postedByDepartment: d['postedByDepartment'] as String?,
      postedByYear: d['postedByYear'] as String?,
      postedAt: _ts('postedAt'),
      editedAt: _ts('editedAt'),
      isActive: d['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'campusId': campusId,
        'category': category,
        'urgencyLevel': urgencyLevel,
        'isImportant': isImportant,
        'title': title,
        'summary': summary,
        'details': details,
        'rawContent': rawContent,
        'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
        'deadlineAt':
            deadlineAt != null ? Timestamp.fromDate(deadlineAt!) : null,
        'venue': venue,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'links': links.map((l) => l.toMap()).toList(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'imageUrl': imageUrl,
        'tags': tags,
        'postedBy': postedBy,
        'postedByName': postedByName,
        'postedByProgram': postedByProgram,
        'postedByDepartment': postedByDepartment,
        'postedByYear': postedByYear,
        'postedAt': FieldValue.serverTimestamp(),
        'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
        'isActive': isActive,
      };

  BoardPostModel copyWith({
    String? id,
    String? campusId,
    String? category,
    String? urgencyLevel,
    bool? isImportant,
    String? title,
    String? summary,
    String? details,
    String? rawContent,
    DateTime? eventDate,
    DateTime? deadlineAt,
    String? venue,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    List<BoardLink>? links,
    List<BoardAttachment>? attachments,
    String? imageUrl,
    List<String>? tags,
    String? postedBy,
    String? postedByName,
    String? postedByProgram,
    String? postedByDepartment,
    String? postedByYear,
    DateTime? postedAt,
    DateTime? editedAt,
    bool? isActive,
  }) {
    return BoardPostModel(
      id: id ?? this.id,
      campusId: campusId ?? this.campusId,
      category: category ?? this.category,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      isImportant: isImportant ?? this.isImportant,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      rawContent: rawContent ?? this.rawContent,
      eventDate: eventDate ?? this.eventDate,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      venue: venue ?? this.venue,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      links: links ?? this.links,
      attachments: attachments ?? this.attachments,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      postedBy: postedBy ?? this.postedBy,
      postedByName: postedByName ?? this.postedByName,
      postedByProgram: postedByProgram ?? this.postedByProgram,
      postedByDepartment: postedByDepartment ?? this.postedByDepartment,
      postedByYear: postedByYear ?? this.postedByYear,
      postedAt: postedAt ?? this.postedAt,
      editedAt: editedAt ?? this.editedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
