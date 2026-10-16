import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/cal/models/cal_dates.dart';
import 'package:voice_task_app/cal/models/cal_event.dart';
import 'package:voice_task_app/cal/models/cal_event_source.dart';

CalEvent _event({
  required DateTime start,
  required DateTime end,
  bool allDay = false,
  bool? attended,
}) {
  return CalEvent(
    id: 'e',
    title: 'Standup',
    start: start,
    end: end,
    allDay: allDay,
    calendarId: 'manual',
    source: CalEventSource.manual,
    attended: attended,
  );
}

void main() {
  final clock = DateTime(2026, 10, 8, 18, 30);

  test('today is the current calendar date', () {
    expect(CalDates.today(clock), DateTime(2026, 10, 8));
  });

  test('week of today starts on Sunday', () {
    final week = CalDates.weekOf(CalDates.today(clock));
    expect(week.first, DateTime(2026, 10, 4));
    expect(week.last, DateTime(2026, 10, 10));
    expect(week, hasLength(7));
  });

  test('a timed event is over only after it ends', () {
    final upcoming = _event(
      start: DateTime(2026, 10, 8, 19),
      end: DateTime(2026, 10, 8, 20),
    );
    final finished = _event(
      start: DateTime(2026, 10, 8, 15),
      end: DateTime(2026, 10, 8, 16),
    );
    expect(CalDates.isOver(upcoming, clock), isFalse);
    expect(CalDates.isOver(finished, clock), isTrue);
  });

  test('asks about this week’s finished events once', () {
    final finished = _event(
      start: DateTime(2026, 10, 8, 15),
      end: DateTime(2026, 10, 8, 16),
    );
    final answered = _event(
      start: DateTime(2026, 10, 7, 15),
      end: DateTime(2026, 10, 7, 16),
      attended: true,
    );
    final lastWeek = _event(
      start: DateTime(2026, 10, 1, 15),
      end: DateTime(2026, 10, 1, 16),
    );
    expect(CalDates.shouldAskAttendance(finished, clock), isTrue);
    expect(CalDates.shouldAskAttendance(answered, clock), isFalse);
    expect(CalDates.shouldAskAttendance(lastWeek, clock), isFalse);
  });
}
