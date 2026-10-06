import 'package:cloud_firestore/cloud_firestore.dart';

class TaskCategory {
  final String id;
  final String name;
  final String emoji;
  final int colorIndex;
  final DateTime? createdAt;

  const TaskCategory({
    required this.id,
    required this.name,
    this.emoji = '📁',
    this.colorIndex = 0,
    this.createdAt,
  });

  factory TaskCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return TaskCategory(
      id: doc.id,
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? _defaultEmoji(map['name'] as String? ?? ''),
      colorIndex: (map['colorIndex'] as num?)?.toInt() ??
          (map['name'] as String? ?? '').hashCode.abs() % 6,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  static String _defaultEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('grocer')) return '🛒';
    if (lower.contains('class') || lower.contains('school')) return '📚';
    if (lower.contains('job') || lower.contains('work')) return '💼';
    if (lower.contains('personal')) return '🏠';
    return '📁';
  }
}
