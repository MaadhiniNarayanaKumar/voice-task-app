import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/cal/models/cal_event.dart';
import 'package:voice_task_app/cal/models/cal_event_dedupe.dart';
import 'package:voice_task_app/cal/models/cal_event_source.dart';

CalEvent _event({
  required String id,
  required String title,
  required DateTime start,
  DateTime? end,
  String? location,
  String? externalId,
  bool allDay = false,
}) {
  return CalEvent(
    id: id,
    title: title,
    start: start,
    end: end ?? start.add(const Duration(hours: 1)),
    allDay: allDay,
    location: location,
    calendarId: 'extension',
    source: CalEventSource.extension,
    externalId: externalId,
  );
}

void main() {
  final start = DateTime(2026, 10, 8, 14);

  test('hides a second copy of the same title and time', () {
    final events = [
      _event(id: 'a', title: 'LSEG Presentation', start: start),
      _event(id: 'b', title: '  lseg   presentation ', start: start),
    ];

    final unique = CalEventDedupe.unique(events);

    expect(unique, hasLength(1));
    expect(unique.single.id, 'a');
  });

  test('keeps the copy that has a location', () {
    final events = [
      _event(id: 'plain', title: 'LSEG Presentation', start: start),
      _event(
        id: 'rich',
        title: 'LSEG Presentation',
        start: start,
        location: 'https://rutgers.zoom.us/j/959',
      ),
    ];

    expect(CalEventDedupe.unique(events).single.id, 'rich');
  });

  test('keeps the same title on a different day', () {
    final events = [
      _event(id: 'today', title: 'Standup', start: start),
      _event(
        id: 'tomorrow',
        title: 'Standup',
        start: start.add(const Duration(days: 1)),
      ),
    ];

    expect(CalEventDedupe.unique(events).map((e) => e.id), ['today', 'tomorrow']);
  });

  test('keeps two different meetings at the same time', () {
    final events = [
      _event(id: 'a', title: 'Design review', start: start),
      _event(id: 'b', title: 'Office hours', start: start),
    ];

    expect(CalEventDedupe.unique(events), hasLength(2));
  });

  test('collapses rows that share an external id', () {
    final events = [
      _event(
        id: 'a',
        title: 'LSEG Presentation',
        start: start,
        externalId: 'gcal-1',
      ),
      _event(
        id: 'b',
        title: 'LSEG Presentation (updated)',
        start: start.add(const Duration(hours: 2)),
        externalId: 'gcal-1',
      ),
    ];

    expect(CalEventDedupe.unique(events), hasLength(1));
  });

  test('drops a second row whose title is the meeting link', () {
    const link = 'https://rutgers.zoom.us/j/95923667084';
    final events = [
      _event(
        id: 'real',
        title: 'LSEG Presentation',
        start: start,
        location: link,
      ),
      _event(id: 'url', title: link, start: start),
    ];

    final unique = CalEventDedupe.unique(events);

    expect(unique, hasLength(1));
    expect(unique.single.id, 'real');
  });
}
