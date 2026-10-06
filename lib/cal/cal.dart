import 'package:flutter/material.dart';

import '../core/config/config.dart';
import '../core/theme/theme_controller.dart';
import 'ui/cal_home_screen.dart';

/// Public entry points for the Calendar module.
///
/// Events live in Firestore (`users/{uid}/events`) with source
/// `manual` (app) or `extension` (Chrome). Google sync is deferred.
class Cal {
  Cal._();

  /// Opens Calendar after optionally applying the cal theme pack.
  static Future<void> open(
    BuildContext context, {
    ThemeController? themes,
    String? uid,
  }) async {
    await themes?.setThemeForFeature('calendar');
    if (!context.mounted) return;

    final resolvedUid = uid ?? AppConfig.guestUid;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalHomeScreen(uid: resolvedUid),
      ),
    );
  }

  /// Root widget for embedding Calendar.
  static Widget root({required String uid}) {
    return CalHomeScreen(uid: uid);
  }
}
