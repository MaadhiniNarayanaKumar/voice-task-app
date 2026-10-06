import 'package:flutter/material.dart';

import '../core/auth/auth_service.dart';
import '../core/config/config.dart';
import '../core/theme/theme_controller.dart';
import 'models/task.dart';
import 'screens/dashboard_screen.dart';
import 'services/priority_escalation.dart';
import 'services/task_repository.dart';

/// Counts for parent home preview cards.
class MiaTodaySummary {
  const MiaTodaySummary({
    required this.openCount,
    required this.dueTodayCount,
    required this.doneCount,
  });

  final int openCount;
  final int dueTodayCount;
  final int doneCount;
}

/// Public entry points for the Mia module.
///
/// Parent app code should open Mia only through this API.
class Mia {
  Mia._();

  /// Opens Mia (dashboard) after optionally applying the Mia theme pack.
  static Future<void> open(
    BuildContext context, {
    required AuthService auth,
    String? uid,
    ThemeController? themes,
    String? filterCategoryId,
  }) async {
    await themes?.setThemeForFeature('tasks');
    if (!context.mounted) return;

    final resolvedUid = uid ?? auth.currentUser?.uid ?? AppConfig.guestUid;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(
          auth: auth,
          uid: resolvedUid,
          initialFilterCategoryId: filterCategoryId,
        ),
      ),
    );
  }

  /// Root widget once auth/uid are resolved (used by [AuthGate]).
  static Widget root({
    required AuthService auth,
    required String uid,
    String? filterCategoryId,
  }) {
    return DashboardScreen(
      auth: auth,
      uid: uid,
      initialFilterCategoryId: filterCategoryId,
    );
  }

  /// Creates a task quickly without opening the full Mia UI.
  static Future<String?> quickAddTask({
    required String uid,
    required String text,
    String priority = 'medium',
    DateTime? dueDate,
    String? categoryId,
    String? categoryName,
    TaskRepository? repository,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final due = dueDate ?? DateTime.now().add(const Duration(days: 1));
    final effectivePriority = PriorityEscalation.effective(
      current: priority,
      dueDate: due,
      completed: false,
    );
    final repo = repository ?? TaskRepository();
    return repo.createTask(
      uid: uid,
      rawText: trimmed,
      priority: effectivePriority,
      dueDate: due,
      categoryId: categoryId,
      categoryName: categoryName,
    );
  }

  /// Summary counts for parent preview surfaces.
  static Future<MiaTodaySummary> todaySummary(String uid) async {
    final tasks = await TaskRepository().watchTasks(uid).first;
    final open = tasks.where((t) => t.status != TaskStatus.completed).toList();
    final done =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final now = DateTime.now();
    final dueToday = open.where((t) {
      final due = t.dueDate;
      if (due == null) return false;
      return due.year == now.year &&
          due.month == now.month &&
          due.day == now.day;
    }).length;

    return MiaTodaySummary(
      openCount: open.length,
      dueTodayCount: dueToday,
      doneCount: done,
    );
  }
}
