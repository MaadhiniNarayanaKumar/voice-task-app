import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/cal_event.dart';
import '../models/cal_event_source.dart';

/// Shared calendar visual helpers.
class CalStyle {
  CalStyle._();

  static Color barColor(CalEvent event) {
    final hex = event.color;
    if (hex != null && hex.startsWith('#') && hex.length >= 7) {
      try {
        return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
      } catch (_) {}
    }
    switch (event.calendarId) {
      case 'work':
        return const Color(0xFF2563EB);
      case 'manual':
        return const Color(0xFF16A34A);
      case 'extension':
        return const Color(0xFF7C3AED);
      default:
        break;
    }
    switch (event.source) {
      case CalEventSource.manual:
        return const Color(0xFF16A34A);
      case CalEventSource.extension:
        return const Color(0xFF7C3AED);
      case CalEventSource.google:
        return const Color(0xFFEA4335);
      case CalEventSource.ics:
        return const Color(0xFF0F766E);
    }
  }

  static IconData sourceIcon(CalEventSource source) {
    switch (source) {
      case CalEventSource.manual:
        return Icons.edit_calendar_rounded;
      case CalEventSource.extension:
        return Icons.extension_rounded;
      case CalEventSource.google:
        return Icons.cloud_rounded;
      case CalEventSource.ics:
        return Icons.mail_outline_rounded;
    }
  }

  static bool isVideoLink(String? location) {
    if (location == null) return false;
    final l = location.toLowerCase();
    return l.contains('zoom.us') ||
        l.contains('meet.google.com') ||
        l.contains('teams.microsoft.com');
  }

  static bool isJunkTitle(String title) {
    final t = title.toLowerCase().trim();
    if (t.contains('calendar - week of')) return true;
    if (t.contains('calendar – week of')) return true;
    if (RegExp(r'university\s*[-–—]\s*calendar').hasMatch(t)) return true;
    if (t == 'google calendar') return true;
    if (RegExp(
      r'week of\s+(january|february|march|april|may|june|july|august|september|october|november|december)',
    ).hasMatch(t)) {
      return true;
    }
    return false;
  }

  static String fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  static String fmtDayDate(DateTime d) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  static String fmtDuration(DateTime start, DateTime end, {bool allDay = false}) {
    if (allDay) return 'All day';
    final mins = end.difference(start).inMinutes;
    if (mins <= 0) return '${fmtTime(start)} – ${fmtTime(end)}';
    if (mins < 60) {
      return '${fmtTime(start)} – ${fmtTime(end)} · ${mins}m';
    }
    final h = mins ~/ 60;
    final m = mins % 60;
    final dur = m == 0 ? '${h}h' : '${h}h ${m}m';
    return '${fmtTime(start)} – ${fmtTime(end)} · $dur';
  }

  static BoxDecoration flatCard({Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
    );
  }
}
