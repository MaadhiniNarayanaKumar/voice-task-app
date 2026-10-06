import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { pendingEnrichment, enriched, completed }

class Task {
  final String id;
  final String rawText;
  final String title;
  final DateTime? dueDate;
  final String priority;
  final TaskStatus status;
  final DateTime? createdAt;
  final String? categoryId;
  final String? categoryName;

  const Task({
    required this.id,
    required this.rawText,
    required this.title,
    this.dueDate,
    required this.priority,
    required this.status,
    this.createdAt,
    this.categoryId,
    this.categoryName,
  });

  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Task.fromMap(doc.id, map);
  }

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      rawText: map['rawText'] as String? ?? '',
      title: map['title'] as String? ?? '',
      dueDate: _asDate(map['dueDate']),
      priority: map['priority'] as String? ?? 'medium',
      status: TaskStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => TaskStatus.pendingEnrichment,
      ),
      createdAt: _asDate(map['createdAt']),
      categoryId: map['categoryId'] as String?,
      categoryName: map['categoryName'] as String?,
    );
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
