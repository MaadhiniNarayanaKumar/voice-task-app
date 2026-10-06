import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore paths for Calendar events (manual / extension / later Google cache).
///
/// `users/{uid}/events/...` — same user tree as Mia tasks.
class CalPaths {
  CalPaths._();

  static DocumentReference<Map<String, dynamic>> userDoc(
    FirebaseFirestore db,
    String uid,
  ) {
    return db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> events(
    FirebaseFirestore db,
    String uid,
  ) {
    return userDoc(db, uid).collection('events');
  }
}
