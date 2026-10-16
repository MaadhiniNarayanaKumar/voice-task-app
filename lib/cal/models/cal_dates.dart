import 'cal_event.dart';

/// One clock for calendar features. Every "today" check goes through here.
class CalDates {
  static DateTime now() => DateTime.now();

  /// Local calendar date, with the time cleared.
  static DateTime today([DateTime? clock]) {
    final n = clock ?? now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Sunday through Saturday that contains [day].
  static List<DateTime> weekOf(DateTime day) {
    final date = dateOnly(day);
    final start = date.subtract(Duration(days: date.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// True once the event has finished relative to [clock] (defaults to now).
  static bool isOver(CalEvent event, [DateTime? clock]) {
    final current = clock ?? now();
    final todayDate = today(current);
    if (event.allDay) {
      final startDay = dateOnly(event.start);
      final endDay = dateOnly(event.end);
      final endsAtMidnight = event.end.hour == 0 &&
          event.end.minute == 0 &&
          event.end.second == 0 &&
          endDay.isAfter(startDay);
      final lastDay = endsAtMidnight
          ? endDay.subtract(const Duration(days: 1))
          : (endDay.isBefore(startDay) ? startDay : endDay);
      return lastDay.isBefore(todayDate);
    }
    return !event.end.isAfter(current);
  }

  /// Finished events from the week that contains today, not yet answered.
  static bool shouldAskAttendance(CalEvent event, [DateTime? clock]) {
    if (event.attended != null) return false;
    if (!isOver(event, clock)) return false;
    final week = weekOf(today(clock));
    final endDay = dateOnly(event.end);
    return !endDay.isBefore(week.first) &&
        !endDay.isAfter(week.last.add(const Duration(days: 1)));
  }
}
