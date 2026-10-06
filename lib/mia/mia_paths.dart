import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore path helpers for Mia data.
///
/// Today these resolve to the existing collections
/// (`users/{uid}/tasks`, `users/{uid}/categories`). Flip [useNamespacedPaths]
/// later to migrate under `users/{uid}/mia/...` in one place.
class MiaPaths {
  MiaPaths._();

  /// When true, paths become `users/{uid}/mia/tasks|categories`.
  /// Keep false until a data migration is ready.
  static const bool useNamespacedPaths = false;

  static DocumentReference<Map<String, dynamic>> userDoc(
    FirebaseFirestore db,
    String uid,
  ) {
    return db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> tasks(
    FirebaseFirestore db,
    String uid,
  ) {
    final user = userDoc(db, uid);
    if (useNamespacedPaths) {
      return user.collection('mia').doc('data').collection('tasks');
    }
    return user.collection('tasks');
  }

  static CollectionReference<Map<String, dynamic>> categories(
    FirebaseFirestore db,
    String uid,
  ) {
    final user = userDoc(db, uid);
    if (useNamespacedPaths) {
      return user.collection('mia').doc('data').collection('categories');
    }
    return user.collection('categories');
  }
}
