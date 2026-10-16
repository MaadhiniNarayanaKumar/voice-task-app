import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/config.dart';
import '../models/cal_dates.dart';

/// Draft event extracted from voice (or paste).
class VoiceEventDraft {
  const VoiceEventDraft({
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.description,
    this.allDay = false,
    this.transcript = '',
    this.confidence = 0.6,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? description;
  final bool allDay;
  final String transcript;
  final double confidence;
}

class VoiceEventParser {
  /// Parse spoken text into an event draft (heuristic + optional Gemini).
  static Future<VoiceEventDraft> parse(String transcript) async {
    final cleaned = _stripLeadIns(transcript.trim());
    if (cleaned.isEmpty) {
      final now = CalDates.now();
      final today = CalDates.today(now);
      final start = DateTime(today.year, today.month, today.day, now.hour + 1);
      return VoiceEventDraft(
        title: 'New event',
        start: start,
        end: start.add(const Duration(hours: 1)),
        transcript: transcript,
        confidence: 0.2,
      );
    }

    final heuristic = _heuristic(cleaned, transcript);
    final key = AppConfig.geminiApiKey.isNotEmpty
        ? AppConfig.geminiApiKey
        : AppConfig.gcpApiKey;
    if (key.isEmpty) return heuristic;

    try {
      final ai = await _viaGemini(cleaned, transcript, key);
      if (ai.confidence >= 0.45) return ai;
    } catch (_) {}
    return heuristic;
  }

  /// Parse Google Calendar–style invite paste (shared with extension format).
  static VoiceEventDraft? parseInvitePaste(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    String? title;
    DateTime? start;
    DateTime? end;
    String? location;
    final notes = <String>[];

    final urlRe = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final meetRe = RegExp(
      r'https?://[^\s]*(zoom\.us|meet\.google\.com|teams\.microsoft\.com)',
      caseSensitive: false,
    );
    final roomRe = RegExp(
      r'^(room|rm\.?|bldg\.?|building|suite|floor)\b[\s.:].+',
      caseSensitive: false,
    );
    final whenRe = RegExp(
      r'(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s+'
      r'(January|February|March|April|May|June|July|August|September|October|November|December)\s+'
      r'(\d{1,2})'
      r'(?:[,.\s⋅·•]*)?'
      r'(?:(\d{1,2}):(\d{2})\s*(am|pm)?\s*[–—\-]\s*(\d{1,2}):(\d{2})\s*(am|pm)?)?',
      caseSensitive: false,
    );

    bool junk(String line) {
      if (RegExp(r'^\d+\s+guests?', caseSensitive: false).hasMatch(line)) {
        return true;
      }
      if (RegExp(r'^\d+\s+(yes|awaiting|no|maybe)\b', caseSensitive: false)
          .hasMatch(line)) {
        return true;
      }
      if (RegExp(r'minutes?\s+before', caseSensitive: false).hasMatch(line)) {
        return true;
      }
      return false;
    }

    for (final line in lines) {
      if (junk(line)) continue;

      final when = whenRe.firstMatch(line);
      if (when != null && start == null) {
        start = _parseInviteStart(when);
        end = _parseInviteEnd(when, start);
        continue;
      }

      final meet = meetRe.firstMatch(line);
      if (meet != null) {
        location ??= meet.group(0);
        continue;
      }
      if (roomRe.hasMatch(line)) {
        location ??= line;
        continue;
      }

      final urls = urlRe.allMatches(line).map((m) => m.group(0)!).toList();
      if (urls.isNotEmpty) {
        location ??= urls.first;
        continue;
      }
      if (RegExp(r'^(created by|organizer):', caseSensitive: false)
          .hasMatch(line)) {
        notes.add(line);
        continue;
      }
      title ??= line;
      if (title != line) notes.add(line);
    }

    title ??= 'New event';
    final now = CalDates.now();
    final today = CalDates.today(now);
    start ??= DateTime(today.year, today.month, today.day, now.hour + 1);
    end ??= start.add(const Duration(hours: 1));
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }

    return VoiceEventDraft(
      title: title,
      start: start,
      end: end,
      location: location,
      description: notes.isEmpty ? text : notes.join('\n'),
      transcript: text,
      confidence: 0.85,
    );
  }

  static String _stripLeadIns(String text) {
    return text
        .replaceFirst(
          RegExp(
            r'^(hey\s+mia[,!]?\s*)?(please\s+)?(add|create|schedule|make|book)\s+(an?\s+)?(event|meeting|appointment|call)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  static VoiceEventDraft _heuristic(String text, String transcript) {
    final lower = text.toLowerCase();
    var day = CalDates.today();
    if (lower.contains('tomorrow')) {
      day = day.add(const Duration(days: 1));
    } else if (lower.contains('today')) {
      // keep today
    }

    final time = _parseClock(lower) ?? const (14, 0);
    final start = DateTime(day.year, day.month, day.day, time.$1, time.$2);
    final end = start.add(const Duration(hours: 1));

    var title = text
        .replaceAll(
          RegExp(
            r'\b(today|tomorrow|at\s+\d{1,2}(:\d{2})?\s*(am|pm)?|from\s+\d.+)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) title = text;

    final zoom = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(text);

    return VoiceEventDraft(
      title: _titleCase(title),
      start: start,
      end: end,
      location: zoom?.group(0),
      transcript: transcript,
      confidence: 0.65,
    );
  }

  static (int, int)? _parseClock(String lower) {
    final m = RegExp(
      r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ap = m.group(3)?.toLowerCase();
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (ap == null && h <= 7) h += 12; // "at 2" → 2pm heuristic
    return (h, min);
  }

  static Future<VoiceEventDraft> _viaGemini(
    String text,
    String transcript,
    String apiKey,
  ) async {
    final now = CalDates.now().toIso8601String();
    final prompt = '''
Extract a calendar event from this voice command.
Today's datetime (ISO local context): $now

Return ONLY JSON:
{
  "title": "string",
  "start": "ISO-8601 datetime",
  "end": "ISO-8601 datetime",
  "location": "string or null",
  "allDay": false,
  "confidence": 0.0 to 1.0
}

Rules:
- Default duration 1 hour if end missing.
- "tomorrow at 3" means 15:00 local tomorrow.
- Prefer a short clean title.

Voice: "$text"
''';

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Event parse failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw =
        data['candidates'][0]['content']['parts'][0]['text'] as String;
    final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
    final map = jsonDecode(cleaned) as Map<String, dynamic>;

    final start = DateTime.tryParse(map['start']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(map['end']?.toString() ?? '')?.toLocal();
    final title = (map['title'] as String?)?.trim();
    if (start == null || title == null || title.isEmpty) {
      throw StateError('incomplete AI event');
    }
    final resolvedEnd =
        end != null && end.isAfter(start) ? end : start.add(const Duration(hours: 1));
    final loc = map['location']?.toString();

    return VoiceEventDraft(
      title: title,
      start: start,
      end: resolvedEnd,
      location: (loc == null || loc == 'null' || loc.isEmpty) ? null : loc,
      allDay: map['allDay'] as bool? ?? false,
      transcript: transcript,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.75,
    );
  }

  static DateTime _parseInviteStart(RegExpMatch m) {
    final monthName = m.group(2)!;
    final day = int.parse(m.group(3)!);
    final month = _monthIndex(monthName);
    final today = CalDates.today();
    var year = today.year;
    var hour = 9;
    var minute = 0;
    if (m.group(4) != null) {
      hour = int.parse(m.group(4)!);
      minute = int.parse(m.group(5)!);
      final ap = (m.group(6) ?? m.group(9))?.toLowerCase();
      // Prefer start am/pm; if only end has am/pm, apply to both.
      final startAp = m.group(6)?.toLowerCase();
      final endAp = m.group(9)?.toLowerCase();
      final useAp = startAp ?? endAp ?? ap;
      if (useAp == 'pm' && hour < 12) hour += 12;
      if (useAp == 'am' && hour == 12) hour = 0;
    }
    var dt = DateTime(year, month, day, hour, minute);
    if (dt.isBefore(today)) {
      dt = DateTime(year + 1, month, day, hour, minute);
    }
    return dt;
  }

  static DateTime _parseInviteEnd(RegExpMatch m, DateTime start) {
    if (m.group(7) == null) return start.add(const Duration(hours: 1));
    var hour = int.parse(m.group(7)!);
    final minute = int.parse(m.group(8)!);
    final endAp = m.group(9)?.toLowerCase();
    final startAp = m.group(6)?.toLowerCase();
    final useAp = endAp ?? startAp;
    if (useAp == 'pm' && hour < 12) hour += 12;
    if (useAp == 'am' && hour == 12) hour = 0;
    var end = DateTime(start.year, start.month, start.day, hour, minute);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  static int _monthIndex(String name) {
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    final i = months.indexOf(name.toLowerCase());
    return i >= 0 ? i + 1 : 1;
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
