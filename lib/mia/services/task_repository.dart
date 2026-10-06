import 'package:cloud_firestore/cloud_firestore.dart';

import '../mia_paths.dart';
import '../models/task.dart';

class TaskRepository {
  TaskRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tasks(String uid) {
    return MiaPaths.tasks(_firestore, uid);
  }

  Stream<List<Task>> watchTasks(String uid) {
    return _tasks(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Task.fromDoc).toList());
  }

  Future<String> createTask({
    required String uid,
    required String rawText,
    required String priority,
    required DateTime dueDate,
    String? categoryId,
    String? categoryName,
  }) async {
    final doc = await _tasks(uid).add({
      'rawText': rawText,
      'title': rawText,
      'priority': priority,
      'status': TaskStatus.pendingEnrichment.name,
      'createdAt': FieldValue.serverTimestamp(),
      'dueDate': Timestamp.fromDate(dueDate),
      'categoryId': categoryId,
      'categoryName': categoryName,
    });
    return doc.id;
  }

  Future<void> applyTitleEnrichment({
    required String uid,
    required String taskId,
    required String title,
    String? categoryId,
    String? categoryName,
  }) {
    return _tasks(uid).doc(taskId).update({
      'title': title,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'status': TaskStatus.enriched.name,
    });
  }

  Future<void> updateTask({
    required String uid,
    required String taskId,
    required String title,
    required String priority,
    DateTime? dueDate,
    String? categoryId,
    String? categoryName,
  }) {
    return _tasks(uid).doc(taskId).update({
      'title': title,
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'categoryId': categoryId,
      'categoryName': categoryName,
    });
  }

  Future<void> updatePriority({
    required String uid,
    required String taskId,
    required String priority,
  }) {
    return _tasks(uid).doc(taskId).update({'priority': priority});
  }

  Future<void> setCompleted({
    required String uid,
    required String taskId,
    required bool completed,
  }) {
    return _tasks(uid).doc(taskId).update({
      'status': completed
          ? TaskStatus.completed.name
          : TaskStatus.enriched.name,
    });
  }

  Future<void> deleteTask({required String uid, required String taskId}) {
    return _tasks(uid).doc(taskId).delete();
  }

  Future<String> restoreTask({
    required String uid,
    required Task task,
  }) async {
    final doc = await _tasks(uid).add({
      'rawText': task.rawText,
      'title': task.title,
      'priority': task.priority,
      'status': task.status.name,
      'createdAt': task.createdAt != null
          ? Timestamp.fromDate(task.createdAt!)
          : FieldValue.serverTimestamp(),
      'dueDate':
          task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
      'categoryId': task.categoryId,
      'categoryName': task.categoryName,
    });
    return doc.id;
  }

  Future<String> duplicateTask({
    required String uid,
    required Task task,
  }) {
    return createTask(
      uid: uid,
      rawText: task.rawText,
      priority: task.priority,
      dueDate: task.dueDate ?? DateTime.now().add(const Duration(days: 1)),
      categoryId: task.categoryId,
      categoryName: task.categoryName,
    );
  }
}
