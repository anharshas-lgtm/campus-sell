import 'dart:math';
import 'package:flutter/material.dart';

// ── Category definitions ───────────────────────────────────────────────────────
// key → (emoji, display label)
const Map<String, (String, String)> kBoardCategories = {
  'general':        ('🌐', 'General'),
  'announcements':  ('📢', 'Announcements'),
  'academics':      ('🎓', 'Academics'),
  'events':         ('🎉', 'Events'),
  'placements':     ('💼', 'Placements'),
  'administration': ('🏛️', 'Administration'),
  'research':       ('🔬', 'Research'),
  'sports':         ('⚽', 'Sports'),
  'culturals':      ('🎭', 'Culturals'),
  'exams':          ('📝', 'Exams'),
  'lost_found':     ('🔍', 'Lost & Found'),
};

// ── Category Material icons (rendered in green complementary to pink/purple) ───
const Map<String, IconData> kBoardCategoryIcons = {
  'general':        Icons.public,
  'announcements':  Icons.campaign_outlined,
  'academics':      Icons.school_outlined,
  'events':         Icons.celebration_outlined,
  'placements':     Icons.work_outline,
  'administration': Icons.account_balance_outlined,
  'research':       Icons.science_outlined,
  'sports':         Icons.sports_soccer_outlined,
  'culturals':      Icons.theater_comedy_outlined,
  'exams':          Icons.edit_note_outlined,
  'lost_found':     Icons.search,
};

// ── Category badge colours (distinct per category, no pink) ───────────────────
const Map<String, Color> kBoardCategoryColors = {
  'general':        Color(0xFF3949AB), // Indigo 600
  'announcements':  Color(0xFFD84315), // Deep Orange 800
  'academics':      Color(0xFF1565C0), // Blue 800
  'events':         Color(0xFFEF6C00), // Orange 800
  'placements':     Color(0xFF2E7D32), // Green 800
  'administration': Color(0xFF455A64), // Blue Grey 700
  'research':       Color(0xFF00838F), // Cyan 800
  'sports':         Color(0xFF558B2F), // Light Green 800
  'culturals':      Color(0xFF00695C), // Teal 800
  'exams':          Color(0xFFC62828), // Red 800
  'lost_found':     Color(0xFF6D4C41), // Brown 600
};

// ── Category thumbnail asset paths (3 variants per category, picked randomly) ──
const Map<String, List<String>> kCategoryThumbnails = {
  'general': [
    'assets/board_thumbnails/general_1.webp',
    'assets/board_thumbnails/general_2.webp',
    'assets/board_thumbnails/general_3.webp',
  ],
  'announcements': [
    'assets/board_thumbnails/announcements_1.webp',
    'assets/board_thumbnails/announcements_2.webp',
    'assets/board_thumbnails/announcements_3.webp',
  ],
  'academics': [
    'assets/board_thumbnails/academics_1.webp',
    'assets/board_thumbnails/academics_2.webp',
    'assets/board_thumbnails/academics_3.webp',
  ],
  'events': [
    'assets/board_thumbnails/events_1.webp',
    'assets/board_thumbnails/events_2.webp',
    'assets/board_thumbnails/events_3.webp',
  ],
  'placements': [
    'assets/board_thumbnails/placements_1.webp',
    'assets/board_thumbnails/placements_2.webp',
    'assets/board_thumbnails/placements_3.webp',
  ],
  'administration': [
    'assets/board_thumbnails/administration_1.webp',
    'assets/board_thumbnails/administration_2.webp',
    'assets/board_thumbnails/administration_3.webp',
  ],
  'research': [
    'assets/board_thumbnails/research_1.webp',
    'assets/board_thumbnails/research_2.webp',
    'assets/board_thumbnails/research_3.webp',
  ],
  'sports': [
    'assets/board_thumbnails/sports_1.webp',
    'assets/board_thumbnails/sports_2.webp',
    'assets/board_thumbnails/sports_3.webp',
  ],
  'culturals': [
    'assets/board_thumbnails/culturals_1.webp',
    'assets/board_thumbnails/culturals_2.webp',
    'assets/board_thumbnails/culturals_3.webp',
  ],
  'exams': [
    'assets/board_thumbnails/exams_1.webp',
    'assets/board_thumbnails/exams_2.webp',
    'assets/board_thumbnails/exams_3.webp',
  ],
  'lost_found': [
    'assets/board_thumbnails/lost_found_1.webp',
    'assets/board_thumbnails/lost_found_2.webp',
    'assets/board_thumbnails/lost_found_3.webp',
  ],
};

/// Picks a random thumbnail for [category], stably seeded by [seed] (e.g. post.id)
/// so the tile doesn't flicker across rebuilds.
String? pickCategoryThumbnail(String category, {String seed = ''}) {
  final list = kCategoryThumbnails[category] ?? kCategoryThumbnails['general'];
  if (list == null || list.isEmpty) return null;
  if (seed.isEmpty) {
    return list[Random().nextInt(list.length)];
  }
  final idx = seed.hashCode.abs() % list.length;
  return list[idx];
}

// ── Urgency levels ─────────────────────────────────────────────────────────────
const Map<String, (Color, String)> kUrgencyLevels = {
  'low':      (Color(0xFF388E3C), 'Low'),
  'medium':   (Color(0xFFF57C00), 'Medium'),
  'high':     (Color(0xFFD32F2F), 'High'),
  'critical': (Color(0xFF880E4F), 'Critical'),
};

// ── Metadata chip colours — ALWAYS use these constants for consistency ─────────
const Color kVenueColor        = Color(0xFF00897B); // teal 600
const Color kDeadlineColor     = Color(0xFFFF8F00); // amber 800
const Color kLinkColor         = Color(0xFF1976D2); // blue 700
const Color kFileColor         = Color(0xFF7B1FA2); // purple 700
const Color kPhoneColor        = Color(0xFF388E3C); // green 700
const Color kEmailColor        = Color(0xFFE64A19); // deep orange 700
const Color kEventColor        = Color(0xFF1565C0); // blue 800
const Color kOrgColor          = Color(0xFF4527A0); // deep purple 800
const Color kFeesColor         = Color(0xFF00695C); // teal 800
const Color kPrizeColor        = Color(0xFFF9A825); // amber 800
const Color kCategoryIconColor = Color(0xFF2E7D32); // emerald/green complementary to pink

// ── File size limit ────────────────────────────────────────────────────────────
const int kMaxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
const int kMaxFileCount     = 3;

// ── Groq model ─────────────────────────────────────────────────────────────────
const String kGroqModel   = 'openai/gpt-oss-120b';
const int    kGroqTimeout = 30; // seconds
