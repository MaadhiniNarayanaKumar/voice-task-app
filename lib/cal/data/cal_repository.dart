import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cal_event.dart';
import '../models/cal_event_source.dart';
import 'cal_paths.dart';

/// Reads/writes calendar events in Firestore (manual + extension sources).
class CalRepository {
  CalRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      CalPaths.events(_db, uid);

  /// Live stream of events overlapping [from]…[to] (inclusive-ish by start).
  Stream<List<CalEvent>> watchEvents(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    final fromUtc = from.toUtc();
    final toUtc = to.toUtc();
    return _col(uid)
        .where('start', isGreaterThanOrEqualTo: fromUtc.toIso8601String())
        .where('start', isLessThanOrEqualTo: toUtc.toIso8601String())
        .orderBy('start')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => CalEvent.fromMap(d.id, d.data()))
          .toList(growable: false);
    });
  }

  /// Agenda from start of local today forward (for day-wise lists).
  Stream<List<CalEvent>> watchAgenda(String uid, {int limit = 80}) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc();
    return _col(uid)
        .where(
          'start',
          isGreaterThanOrEqualTo: startOfToday.toIso8601String(),
        )
        .orderBy('start')
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => CalEvent.fromMap(d.id, d.data()))
          .toList(growable: false);
    });
  }

  /// Upcoming events from now (agenda).
  Stream<List<CalEvent>> watchUpcoming(String uid, {int limit = 40}) {
    final now = DateTime.now().toUtc().toIso8601String();
    return _col(uid)
        .where('start', isGreaterThanOrEqualTo: now)
        .orderBy('start')
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => CalEvent.fromMap(d.id, d.data()))
          .toList(growable: false);
    });
  }

  Future<String> createEvent({
    required String uid,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    String? description,
    CalEventSource source = CalEventSource.manual,
    String? calendarId,
    String? color,
    String? externalId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('title required');
    }
    if (!end.isAfter(start) && !allDay) {
      throw ArgumentError('end must be after start');
    }

    final doc = _col(uid).doc();
    final event = CalEvent(
      id: doc.id,
      title: trimmed,
      start: start,
      end: end,
      allDay: allDay,
      location: location?.trim().isEmpty == true ? null : location?.trim(),
      calendarId: calendarId ?? source.wireName,
      color: color,
      description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      source: source,
      externalId: externalId,
    );
    await doc.set({
      ...event.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> deleteEvent({required String uid, required String id}) {
    return _col(uid).doc(id).delete();
  }

  Future<void> updateEvent({
    required String uid,
    required CalEvent event,
  }) {
    return _col(uid).doc(event.id).set({
      ...event.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
