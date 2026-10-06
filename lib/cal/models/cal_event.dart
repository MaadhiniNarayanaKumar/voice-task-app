import 'cal_event_source.dart';

/// Unified calendar event — Google, manual, extension, and ICS all map here.
class CalEvent {
  const CalEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarId,
    required this.source,
    this.location,
    this.color,
    this.recurring = false,
    this.description,
    this.externalId,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? location;

  /// Logical calendar bucket (e.g. `manual`, `extension`, Google calendar id).
  final String calendarId;
  final String? color;
  final bool recurring;
  final String? description;
  final CalEventSource source;

  /// Provider id when [source] is google / ics / extension remote id.
  final String? externalId;

  CalEvent copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    String? location,
    String? calendarId,
    String? color,
    bool? recurring,
    String? description,
    CalEventSource? source,
    String? externalId,
  }) {
    return CalEvent(
      id: id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      calendarId: calendarId ?? this.calendarId,
      color: color ?? this.color,
      recurring: recurring ?? this.recurring,
      description: description ?? this.description,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'allDay': allDay,
      'location': location,
      'calendarId': calendarId,
      'color': color,
      'recurring': recurring,
      'description': description,
      'source': source.wireName,
      'externalId': externalId,
    };
  }

  factory CalEvent.fromMap(String id, Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
      // Firestore Timestamp
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    return CalEvent(
      id: id,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : 'Untitled',
      start: parse(map['start']),
      end: parse(map['end']),
      allDay: map['allDay'] as bool? ?? false,
      location: map['location'] as String?,
      calendarId: map['calendarId'] as String? ?? 'manual',
      color: map['color'] as String?,
      recurring: map['recurring'] as bool? ?? false,
      description: map['description'] as String?,
      source: CalEventSourceX.fromWire(map['source'] as String?),
      externalId: map['externalId'] as String?,
    );
  }
}
