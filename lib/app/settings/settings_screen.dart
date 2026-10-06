import 'package:flutter/material.dart';

import '../../cal/cal.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/theme_scope.dart';
import '../../mia/mia.dart';

/// Parent-app settings: general look + Mia + Calendar preferences.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.auth,
  });

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final themes = ThemeScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([settings, themes]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sectionTitle('General'),
              _card(
                children: [
                  ListTile(
                    title: const Text('Appearance'),
                    subtitle: Text(_themeModeLabel(settings.themeMode)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pickThemeMode(context, settings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Color theme'),
                    subtitle: Text(
                      themes.catalog
                              .where((e) => e.id == settings.themePackId)
                              .map((e) => e.id)
                              .firstOrNull
                              ?.toUpperCase() ??
                          themes.pack.name,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pickThemePack(context, settings, themes),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Haptics'),
                    subtitle: const Text('Vibration feedback across the app'),
                    value: settings.hapticsEnabled,
                    activeThumbColor: AppColors.indigo,
                    onChanged: settings.setHapticsEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('Mia'),
              _card(
                children: [
                  ListTile(
                    title: const Text('Default priority'),
                    subtitle: Text(settings.miaDefaultPriority),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pickPriority(context, settings),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Voice tip'),
                    subtitle:
                        const Text('Show “Tap and say a task” on first use'),
                    value: settings.miaVoiceTips,
                    activeThumbColor: AppColors.indigo,
                    onChanged: settings.setMiaVoiceTips,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Reset voice tip'),
                    subtitle: const Text('Show the mic tip again next time'),
                    onTap: () async {
                      await settings.resetMiaVoiceTip();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice tip will show again'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.mic_rounded, color: AppColors.indigo),
                    title: const Text('Open Mia'),
                    subtitle: const Text('Go to your tasks'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      Mia.open(
                        context,
                        auth: auth,
                        themes: themes,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('Calendar'),
              _card(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.event_note_rounded,
                      color: AppColors.indigo,
                    ),
                    title: const Text('Event sources'),
                    subtitle: const Text(
                      'Manual (app) + Chrome extension → Firestore',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.indigo,
                    ),
                    title: const Text('Open Calendar'),
                    subtitle: const Text('Agenda and add events'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      Cal.open(
                        context,
                        themes: themes,
                        uid: auth.currentUser?.uid ?? AppConfig.guestUid,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('About'),
              _card(
                children: [
                  const ListTile(
                    title: Text('Voice Task App'),
                    subtitle: Text(
                      'General settings live here. Mia and Calendar keep '
                      'their own screens and data.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    AppSettings settings,
  ) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeModeLabel(mode)),
                trailing: settings.themeMode == mode
                    ? Icon(Icons.check_rounded, color: AppColors.indigo)
                    : null,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await settings.setThemeMode(picked);
  }

  Future<void> _pickThemePack(
    BuildContext context,
    AppSettings settings,
    ThemeController themes,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in themes.catalog)
              ListTile(
                title: Text(entry.id),
                subtitle: Text('Feature: ${entry.feature}'),
                trailing: settings.themePackId == entry.id
                    ? Icon(Icons.check_rounded, color: AppColors.indigo)
                    : null,
                onTap: () => Navigator.pop(context, entry.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await settings.setThemePackId(picked);
    await themes.setTheme(picked);
  }

  Future<void> _pickPriority(
    BuildContext context,
    AppSettings settings,
  ) async {
    const options = ['low', 'medium', 'high'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in options)
              ListTile(
                title: Text(value),
                trailing: settings.miaDefaultPriority == value
                    ? Icon(Icons.check_rounded, color: AppColors.indigo)
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await settings.setMiaDefaultPriority(picked);
  }
}
