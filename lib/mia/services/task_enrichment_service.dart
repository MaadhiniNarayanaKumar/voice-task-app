import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/config.dart';

class TaskEnrichmentResult {
  final String title;
  final String? categoryName;

  const TaskEnrichmentResult({
    required this.title,
    this.categoryName,
  });
}

class TaskEnrichmentService {
  /// Uses AI to clean the title and pick one of [categoryNames].
  static Future<TaskEnrichmentResult> enrich(
    String rawText, {
    List<String> categoryNames = const [],
  }) async {
    final key = AppConfig.geminiApiKey.isNotEmpty
        ? AppConfig.geminiApiKey
        : AppConfig.gcpApiKey;
    if (key.isNotEmpty) {
      try {
        return await _enrichViaGemini(rawText, key, categoryNames);
      } catch (_) {}
    }
    return _heuristic(rawText, categoryNames);
  }

  static Future<TaskEnrichmentResult> _enrichViaGemini(
    String rawText,
    String apiKey,
    List<String> categoryNames,
  ) async {
    final categoriesJson = jsonEncode(categoryNames);
    final prompt = '''
You extract a short task title and classify the task into one category.

Return ONLY valid JSON, no markdown fences, no explanation, in this exact shape:
{"title": "short imperative title under 8 words", "category": "exact category name from the list or null"}

Rules:
- title should be a short clean task title.
- category MUST be exactly one of these names when possible: $categoriesJson
- If none fit well, use null.
- Prefer the closest match. Examples: milk/eggs → Groceries, homework → Class, meeting/email → Job.

Voice input: "$rawText"
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
      throw Exception('Enrichment failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        data['candidates'][0]['content']['parts'][0]['text'] as String;
    final cleaned = text.replaceAll(RegExp(r'```json|```'), '').trim();
    return _fromJson(
      jsonDecode(cleaned) as Map<String, dynamic>,
      rawText,
      categoryNames,
    );
  }

  static TaskEnrichmentResult heuristic(
    String rawText, [
    List<String> categoryNames = const [],
  ]) =>
      _heuristic(rawText, categoryNames);

  static TaskEnrichmentResult _fromJson(
    Map<String, dynamic> parsed,
    String rawText,
    List<String> categoryNames,
  ) {
    final category = _matchCategory(
      parsed['category']?.toString(),
      categoryNames,
    );
    return TaskEnrichmentResult(
      title: (parsed['title'] as String?)?.trim().isNotEmpty == true
          ? parsed['title'] as String
          : rawText,
      categoryName: category,
    );
  }

  static TaskEnrichmentResult _heuristic(
    String rawText,
    List<String> categoryNames,
  ) {
    final lower = rawText.toLowerCase();
    String? matched;

    for (final name in categoryNames) {
      if (lower.contains(name.toLowerCase())) {
        matched = name;
        break;
      }
    }

    matched ??= _keywordCategory(lower, categoryNames);

    return TaskEnrichmentResult(
      title: rawText.trim(),
      categoryName: matched,
    );
  }

  static String? _keywordCategory(String lower, List<String> categoryNames) {
    final rules = <String, List<String>>{
      'groceries': [
        'milk',
        'eggs',
        'bread',
        'grocery',
        'groceries',
        'store',
        'supermarket',
        'buy food',
      ],
      'class': [
        'homework',
        'assignment',
        'class',
        'lecture',
        'exam',
        'study',
        'school',
        'college',
      ],
      'job': [
        'work',
        'job',
        'meeting',
        'email',
        'boss',
        'office',
        'client',
        'deadline',
      ],
      'personal': ['personal', 'family', 'friend', 'home', 'doctor', 'gym'],
    };

    for (final entry in rules.entries) {
      if (!entry.value.any(lower.contains)) continue;
      final match = _matchCategory(entry.key, categoryNames);
      if (match != null) return match;
    }
    return null;
  }

  static String? _matchCategory(String? value, List<String> categoryNames) {
    if (value == null || value.trim().isEmpty || value == 'null') return null;
    final needle = value.trim().toLowerCase();
    for (final name in categoryNames) {
      if (name.toLowerCase() == needle) return name;
    }
    for (final name in categoryNames) {
      if (name.toLowerCase().contains(needle) ||
          needle.contains(name.toLowerCase())) {
        return name;
      }
    }
    return null;
  }
}
