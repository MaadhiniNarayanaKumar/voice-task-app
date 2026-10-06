/// Escalates open-task priority toward the due date: low → medium → high.
class PriorityEscalation {
  static const order = ['low', 'medium', 'high'];

  /// Effective priority for an open task based on due date.
  /// Never lowers below the user's chosen [current] priority.
  static String effective({
    required String current,
    required DateTime? dueDate,
    required bool completed,
  }) {
    if (completed || dueDate == null) return _normalize(current);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final daysLeft = dueDay.difference(startOfToday).inDays;

    // overdue / due today → high
    // within 2 days → medium
    // farther → low
    final fromDue = daysLeft <= 0
        ? 'high'
        : daysLeft <= 2
            ? 'medium'
            : 'low';

    return _max(_normalize(current), fromDue);
  }

  static String _normalize(String value) {
    final lower = value.toLowerCase();
    return order.contains(lower) ? lower : 'medium';
  }

  static String _max(String a, String b) {
    return order.indexOf(a) >= order.indexOf(b) ? a : b;
  }
}
