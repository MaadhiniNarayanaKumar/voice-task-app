import 'package:cloud_firestore/cloud_firestore.dart';

import '../mia_paths.dart';
import '../models/category.dart';

class CategoryRepository {
  CategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const defaultEmojis = ['🛒', '📚', '💼', '🏠', '🎯', '💡', '✈️', '💪'];

  CollectionReference<Map<String, dynamic>> _categories(String uid) {
    return MiaPaths.categories(_firestore, uid);
  }

  Stream<List<TaskCategory>> watchCategories(String uid) {
    return _categories(uid)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TaskCategory.fromDoc).toList());
  }

  Future<void> ensureDefaults(String uid) async {
    final existing = await _categories(uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    const defaults = [
      ('Groceries', '🛒', 0),
      ('Class', '📚', 1),
      ('Job', '💼', 2),
      ('Personal', '🏠', 3),
    ];
    final batch = _firestore.batch();
    for (final item in defaults) {
      batch.set(_categories(uid).doc(), {
        'name': item.$1,
        'emoji': item.$2,
        'colorIndex': item.$3,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<String> createCategory({
    required String uid,
    required String name,
    String emoji = '📁',
    int colorIndex = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Category name is required.');
    }
    final doc = await _categories(uid).add({
      'name': trimmed,
      'emoji': emoji,
      'colorIndex': colorIndex,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateCategory({
    required String uid,
    required String categoryId,
    required String name,
    required String emoji,
    required int colorIndex,
  }) {
    return _categories(uid).doc(categoryId).update({
      'name': name.trim(),
      'emoji': emoji,
      'colorIndex': colorIndex,
    });
  }

  Future<void> deleteCategory({
    required String uid,
    required String categoryId,
  }) {
    return _categories(uid).doc(categoryId).delete();
  }
}
