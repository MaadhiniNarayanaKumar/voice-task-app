import 'cal_event.dart';

/// Collapses calendar rows that are the same meeting saved more than once.
class CalEventDedupe {
  CalEventDedupe._();

  static List<CalEvent> unique(List<CalEvent> events) {
    final kept = <CalEvent>[];
    for (final event in events) {
      final index = kept.indexWhere((existing) => same(existing, event));
      if (index < 0) {
        kept.add(event);
        continue;
      }
      if (_prefer(event, kept[index])) kept[index] = event;
    }
    return kept;
  }

  /// True when [a] and [b] are the same meeting, even with different ids.
  static bool same(CalEvent a, CalEvent b) {
    if (a.id == b.id) return true;

    final externalA = a.externalId?.trim();
    final externalB = b.externalId?.trim();
    if (externalA != null &&
        externalA.isNotEmpty &&
        externalA == externalB) {
      return true;
    }

    if (!_startsTogether(a, b)) return false;

    if (_normTitle(a.title) == _normTitle(b.title)) return true;

    final locA = meetingLink(a.location);
    final locB = meetingLink(b.location);
    if (locA != null && locA == locB) return true;

    // Scrape sometimes saves the meeting link as the title of a second row.
    final titleLinkA = _urlOnlyTitle(a.title);
    final titleLinkB = _urlOnlyTitle(b.title);
    if (titleLinkA != null && (titleLinkA == locB || titleLinkA == titleLinkB)) {
      return true;
    }
    if (titleLinkB != null && titleLinkB == locA) return true;
    return false;
  }

  static bool _startsTogether(CalEvent a, CalEvent b) {
    if (a.allDay && b.allDay) return _day(a.start) == _day(b.start);
    if (a.allDay || b.allDay) return false;
    return a.start.difference(b.start).inMinutes.abs() <= 1;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _normTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Meeting URL inside [value], lowercased, or null when there isn't one.
  static String? meetingLink(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'https?:\/\/[^\s]+',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    var url = match.group(0)!.toLowerCase();
    while (url.endsWith('.') || url.endsWith(',') || url.endsWith(')')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  /// Keep the row that has a real title, a place, and notes.
  static bool _prefer(CalEvent candidate, CalEvent current) {
    return _score(candidate) > _score(current);
  }

  static int _score(CalEvent event) {
    var score = 0;
    final title = event.title.trim();
    if (title.isNotEmpty && _urlOnlyTitle(title) == null) score += 8;
    if ((event.location ?? '').trim().isNotEmpty) score += 4;
    if ((event.description ?? '').trim().isNotEmpty) score += 2;
    if ((event.externalId ?? '').trim().isNotEmpty) score += 1;
    return score;
  }

  static String? _urlOnlyTitle(String title) {
    final link = meetingLink(title);
    if (link == null) return null;
    final trimmed = title.trim().toLowerCase();
    if (trimmed == link || trimmed == '$link/') return link;
    return null;
  }
}
