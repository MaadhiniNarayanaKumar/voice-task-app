import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/config.dart';
import 'voice_command_parser.dart';

enum VoiceIntentKind {
  addTask,
  addCategory,
  openCategories,
  openTasks,
  openHome,
  help,
  unknown,
}

class VoiceIntent {
  const VoiceIntent({
    required this.kind,
    required this.transcript,
    required this.summary,
    this.taskTitle,
    this.categoryName,
    this.priority = 'medium',
    this.dueDate,
    this.confidence = 0.6,
  });

  final VoiceIntentKind kind;
  final String transcript;
  final String summary;
  final String? taskTitle;
  final String? categoryName;
  final String priority;
  final DateTime? dueDate;
  final double confidence;

  String get actionLabel => switch (kind) {
        VoiceIntentKind.addTask => 'Add task',
        VoiceIntentKind.addCategory => 'Add category',
        VoiceIntentKind.openCategories => 'Open categories',
        VoiceIntentKind.openTasks => 'Show tasks',
        VoiceIntentKind.openHome => 'Go home',
        VoiceIntentKind.help => 'Help',
        VoiceIntentKind.unknown => 'Confirm',
      };
}

class VoiceIntentService {
  /// Classifies spoken text into an actionable app intent.
  static Future<VoiceIntent> classify(
    String transcript, {
    List<String> categoryNames = const [],
  }) async {
    final cleaned = VoiceCommandParser.taskTextFrom(
      transcript,
      requireWakeWord: false,
    );
    if (cleaned.isEmpty) {
      return VoiceIntent(
        kind: VoiceIntentKind.unknown,
        transcript: transcript,
        summary: "I didn't catch a command",
        confidence: 0,
      );
    }

    final heuristic = _heuristic(cleaned, categoryNames);
    final key = AppConfig.geminiApiKey.isNotEmpty
        ? AppConfig.geminiApiKey
        : AppConfig.gcpApiKey;
    if (key.isEmpty) return heuristic;

    try {
      final ai = await _classifyViaGemini(cleaned, key, categoryNames);
      // Prefer AI when it is confident; otherwise keep heuristic.
      if (ai.confidence >= 0.45) return ai;
    } catch (_) {}
    return heuristic;
  }

  static VoiceIntent _heuristic(String text, List<String> categoryNames) {
    final lower = text.toLowerCase().trim();

    if (_matchesAny(lower, [
      'help',
      'what can you do',
      'what can i say',
      'commands',
    ])) {
      return VoiceIntent(
        kind: VoiceIntentKind.help,
        transcript: text,
        summary: 'Show voice help',
        confidence: 0.9,
      );
    }

    if (_matchesAny(lower, [
      'go home',
      'open home',
      'back home',
      'home screen',
    ])) {
      return VoiceIntent(
        kind: VoiceIntentKind.openHome,
        transcript: text,
        summary: 'Go to home',
        confidence: 0.9,
      );
    }

    if (_matchesAny(lower, [
      'open categories',
      'show categories',
      'go to categories',
      'category screen',
      'categories screen',
    ])) {
      return VoiceIntent(
        kind: VoiceIntentKind.openCategories,
        transcript: text,
        summary: 'Open categories',
        confidence: 0.92,
      );
    }

    if (_matchesAny(lower, [
      'show tasks',
      'open tasks',
      'my tasks',
      'list tasks',
      'show my tasks',
    ])) {
      return VoiceIntent(
        kind: VoiceIntentKind.openTasks,
        transcript: text,
        summary: 'Show tasks',
        confidence: 0.9,
      );
    }

    final categoryMatch = RegExp(
      r'^(?:add|create|new|make)\s+(?:a\s+|an\s+|the\s+)?categor(?:y|ies)\s+(?:called\s+|named\s+|for\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (categoryMatch != null) {
      final name = categoryMatch.group(1)!.trim();
      return VoiceIntent(
        kind: VoiceIntentKind.addCategory,
        transcript: text,
        summary: 'Add category “$name”',
        categoryName: _titleCase(name),
        confidence: 0.95,
      );
    }

    if (RegExp(
      r'^(?:add|create|new|make)\s+(?:a\s+|an\s+|the\s+)?categor(?:y|ies)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return VoiceIntent(
        kind: VoiceIntentKind.addCategory,
        transcript: text,
        summary: 'Add a category',
        categoryName: '',
        confidence: 0.8,
      );
    }

    // Default: treat as add task (strip leading "add task" noise).
    final title = VoiceCommandParser.taskTextFrom(text, requireWakeWord: false);
    final priority = _inferPriority(lower);
    final due = _inferDueDate(lower);
    String? category;
    for (final name in categoryNames) {
      if (lower.contains(name.toLowerCase())) {
        category = name;
        break;
      }
    }

    return VoiceIntent(
      kind: VoiceIntentKind.addTask,
      transcript: text,
      summary: 'Add task “$title”',
      taskTitle: title,
      categoryName: category,
      priority: priority,
      dueDate: due,
      confidence: 0.7,
    );
  }

  static Future<VoiceIntent> _classifyViaGemini(
    String text,
    String apiKey,
    List<String> categoryNames,
  ) async {
    final prompt = '''
You classify a voice command for a task app named Mia.

Return ONLY JSON:
{
  "intent": "add_task" | "add_category" | "open_categories" | "open_tasks" | "open_home" | "help" | "unknown",
  "taskTitle": "string or null",
  "categoryName": "string or null",
  "priority": "low" | "medium" | "high",
  "dueHint": "today" | "tomorrow" | "next_week" | null,
  "confidence": 0.0 to 1.0,
  "summary": "short human summary of the action"
}

Rules:
- "add category groceries" → add_category, categoryName=Groceries
- "buy milk tomorrow high priority" → add_task
- "open categories" → open_categories
- "show my tasks" → open_tasks
- "go home" → open_home
- Existing categories: ${jsonEncode(categoryNames)}
- Prefer add_task when the user describes something to do.

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
      throw Exception('Intent classify failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw =
        data['candidates'][0]['content']['parts'][0]['text'] as String;
    final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    return _fromAiJson(map, text);
  }

  static VoiceIntent _fromAiJson(Map<String, dynamic> map, String text) {
    final intentRaw = (map['intent'] as String? ?? 'unknown').toLowerCase();
    final kind = switch (intentRaw) {
      'add_task' => VoiceIntentKind.addTask,
      'add_category' => VoiceIntentKind.addCategory,
      'open_categories' => VoiceIntentKind.openCategories,
      'open_tasks' => VoiceIntentKind.openTasks,
      'open_home' => VoiceIntentKind.openHome,
      'help' => VoiceIntentKind.help,
      _ => VoiceIntentKind.unknown,
    };

    final dueHint = map['dueHint']?.toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    DateTime? due;
    switch (dueHint) {
      case 'today':
        due = today;
      case 'tomorrow':
        due = today.add(const Duration(days: 1));
      case 'next_week':
        due = today.add(const Duration(days: 7));
    }

    final priority = (map['priority'] as String? ?? 'medium').toLowerCase();
    final taskTitle = map['taskTitle']?.toString();
    final categoryName = map['categoryName']?.toString();
    final summary = map['summary']?.toString() ??
        switch (kind) {
          VoiceIntentKind.addTask => 'Add task',
          VoiceIntentKind.addCategory => 'Add category',
          VoiceIntentKind.openCategories => 'Open categories',
          VoiceIntentKind.openTasks => 'Show tasks',
          VoiceIntentKind.openHome => 'Go home',
          VoiceIntentKind.help => 'Help',
          VoiceIntentKind.unknown => 'Confirm',
        };

    return VoiceIntent(
      kind: kind == VoiceIntentKind.unknown ? VoiceIntentKind.addTask : kind,
      transcript: text,
      summary: summary,
      taskTitle: (taskTitle == null || taskTitle == 'null' || taskTitle.isEmpty)
          ? (kind == VoiceIntentKind.addTask ? text : null)
          : taskTitle,
      categoryName:
          (categoryName == null || categoryName == 'null' || categoryName.isEmpty)
              ? null
              : categoryName,
      priority: ['low', 'medium', 'high'].contains(priority) ? priority : 'medium',
      dueDate: due,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.7,
    );
  }

  static bool _matchesAny(String lower, List<String> phrases) {
    return phrases.any(lower.contains);
  }

  static String _inferPriority(String lower) {
    if (RegExp(r'\b(urgent|asap|high priority|important)\b').hasMatch(lower)) {
      return 'high';
    }
    if (RegExp(r'\b(low priority|whenever)\b').hasMatch(lower)) return 'low';
    return 'medium';
  }

  static DateTime? _inferDueDate(String lower) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    if (lower.contains('tomorrow')) return today.add(const Duration(days: 1));
    if (RegExp(r'\btoday\b').hasMatch(lower)) return today;
    if (lower.contains('next week')) return today.add(const Duration(days: 7));
    return null;
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
