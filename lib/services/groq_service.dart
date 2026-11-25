import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/groq_config.dart';
import '../constants/board_constants.dart';
import '../models/board_post_model.dart';

/// Calls the Groq LLM to extract structured data from raw post text.
/// Returns a valid [GroqResult] always — never throws to caller.
/// On any failure (timeout, parse error, empty key), returns a fallback
/// with [GroqResult.fallbackReason] populated.
class GroqService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const _systemPrompt = '''
You are a smart information extractor for a college campus notice board app.
Analyse the post text and return ONLY a valid JSON object. No markdown, no explanation.
Return null for any field not found in the text.

REQUIRED JSON SCHEMA:
{
  "title": "string — required, max 10 words, capture the main subject",
  "category": "one of: general|announcements|academics|events|placements|administration|research|sports|culturals|exams|lost_found — required",
  "urgencyLevel": "low|medium|high|critical",
  "eventDate": "ISO8601 date string (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS) or null",
  "deadline": "ISO8601 date string (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS) or null",
  "venue": "plain location string or null",
  "summary": "2-3 sentence summary or null",
  "details": "additional paragraph with extra info or null",
  "contactName": "person name or null",
  "contactPhone": "phone number string or null",
  "contactEmail": "email address or null",
  "links": [{"url": "string", "label": "string or null"}]
}''';

  Future<http.Response> _sendRequest({
    required String rawText,
    required bool useJsonMode,
  }) async {
    final payload = <String, dynamic>{
      'model': kGroqModel,
      'temperature': 0.2,
      'max_tokens': 2048,
      'reasoning_effort': 'low',
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content': 'POST TEXT:\n"""\n$rawText\n"""',
        },
      ],
    };
    if (useJsonMode) {
      payload['reasoning_format'] = 'parsed';
      payload['response_format'] = {'type': 'json_object'};
    }

    final client = http.Client();
    try {
      return await client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer ${GroqConfig.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: kGroqTimeout));
    } finally {
      client.close();
    }
  }

  Future<GroqResult> analysePost({
    required String rawText,
    String? userCategory,
  }) async {
    if (!GroqConfig.isConfigured) {
      if (kDebugMode) debugPrint('⚠️ Groq key not set — using fallback');
      return GroqResult.fallback(
        rawText,
        userCategory,
        reason: 'Groq API key is empty in Remote Config',
      );
    }

    try {
      var response = await _sendRequest(rawText: rawText, useJsonMode: true);

      // Retry without JSON/reasoning params if the model rejects them
      if (response.statusCode == 400 &&
          (response.body.toLowerCase().contains('response_format') ||
              response.body.toLowerCase().contains('reasoning_format'))) {
        response = await _sendRequest(rawText: rawText, useJsonMode: false);
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('⚠️ Groq HTTP ${response.statusCode}: ${response.body}');
        }
        String errDetail = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          final msg = errJson['error']?['message'] as String?;
          if (msg != null && msg.isNotEmpty) errDetail = msg;
        } catch (_) {}
        return GroqResult.fallback(
          rawText,
          userCategory,
          reason: errDetail,
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          body['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        return GroqResult.fallback(
          rawText,
          userCategory,
          reason: 'Empty response from model',
        );
      }

      // Strip markdown fences and isolate the outermost JSON object
      var cleaned = content
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        return GroqResult.fallback(
          rawText,
          userCategory,
          reason: 'Model output was not a JSON object',
        );
      }

      return GroqResult.fromJson(decoded, rawText, userCategory);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Groq error: $e');
      return GroqResult.fallback(
        rawText,
        userCategory,
        reason: e.toString(),
      );
    }
  }
}

// ── Result ─────────────────────────────────────────────────────────────────────

class GroqResult {
  final String title;
  final String summary;
  final String details;
  final String category;
  final String urgencyLevel;
  final bool isImportant;
  final DateTime? eventDate;
  final DateTime? deadlineAt;
  final String? venue;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final List<BoardLink> links;
  final List<String> tags;
  final bool usedFallback;
  final String? fallbackReason;

  const GroqResult({
    required this.title,
    this.summary = '',
    this.details = '',
    required this.category,
    this.urgencyLevel = 'low',
    this.isImportant = false,
    this.eventDate,
    this.deadlineAt,
    this.venue,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.links = const [],
    this.tags = const [],
    this.usedFallback = false,
    this.fallbackReason,
  });

  factory GroqResult.fromJson(
      Map<String, dynamic> j, String rawText, String? userCategory) {
    String? str(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        final t = v.trim();
        return (t.isEmpty || t.toLowerCase() == 'null') ? null : t;
      }
      if (v is num || v is bool) return v.toString();
      if (v is Map) {
        final joined = v.values
            .where((x) => x != null && x.toString().trim().isNotEmpty)
            .map((x) => x.toString().trim())
            .join(', ');
        return joined.isEmpty ? null : joined;
      }
      if (v is List) {
        final joined = v
            .where((x) => x != null && x.toString().trim().isNotEmpty)
            .map((x) => x.toString().trim())
            .join(', ');
        return joined.isEmpty ? null : joined;
      }
      return v.toString();
    }

    DateTime? parseDate(dynamic v) {
      final s = str(v);
      if (s == null) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    List<BoardLink> parseLinks(dynamic raw) {
      if (raw is! List) return const [];
      final out = <BoardLink>[];
      for (final item in raw) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final url = str(m['url']);
          if (url != null) {
            out.add(BoardLink(url: url, label: str(m['label'])));
          }
        } else if (item is String && item.trim().isNotEmpty) {
          out.add(BoardLink(url: item.trim()));
        }
      }
      return out;
    }

    String resolveCategory(dynamic rawCat) {
      if (userCategory != null && userCategory.isNotEmpty) {
        return userCategory;
      }
      final norm = (str(rawCat) ?? 'general')
          .toLowerCase()
          .replaceAll('&', '_')
          .replaceAll(' ', '_');
      if (kBoardCategories.containsKey(norm)) return norm;
      if (norm.contains('lost') || norm.contains('found')) return 'lost_found';
      return 'general';
    }

    String resolveUrgency(dynamic rawUrg) {
      final u = (str(rawUrg) ?? 'low').toLowerCase();
      return kUrgencyLevels.containsKey(u) ? u : 'low';
    }

    final resolvedCategory = resolveCategory(j['category']);
    final urgency = resolveUrgency(j['urgencyLevel']);
    final isImportant = urgency == 'high' || urgency == 'critical';

    return GroqResult(
      title: str(j['title']) ?? _fallbackTitle(rawText),
      summary: str(j['summary']) ?? '',
      details: str(j['details']) ?? '',
      category: resolvedCategory,
      urgencyLevel: urgency,
      isImportant: isImportant,
      eventDate: parseDate(j['eventDate']),
      deadlineAt: parseDate(j['deadline']) ?? parseDate(j['deadlineAt']),
      venue: str(j['venue']),
      contactName: str(j['contactName']),
      contactPhone: str(j['contactPhone']),
      contactEmail: str(j['contactEmail']),
      links: parseLinks(j['links']),
      usedFallback: false,
    );
  }

  factory GroqResult.fallback(
    String rawText,
    String? userCategory, {
    String? reason,
  }) =>
      GroqResult(
        title: _fallbackTitle(rawText),
        summary: _fallbackSummary(rawText),
        category: userCategory ?? 'general',
        usedFallback: true,
        fallbackReason: reason,
      );

  static String _fallbackTitle(String text) {
    final t = text.trim();
    if (t.length <= 60) return t;
    final firstLine = t.split('\n').first.trim();
    return firstLine.length <= 60
        ? firstLine
        : '${firstLine.substring(0, 57)}...';
  }

  static String _fallbackSummary(String text) {
    final t = text.trim();
    return t.length <= 150 ? t : '${t.substring(0, 147)}...';
  }
}
