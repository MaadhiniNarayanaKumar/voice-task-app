import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/home_screen.dart';
import 'core/auth/auth_service.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_pack.dart';
import 'core/theme/theme_scope.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env', isOptional: true);
  if (dotenv.env.isEmpty) {
    await dotenv.load(fileName: '.env.example', isOptional: true);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final settings = AppSettings();
  await settings.load();

  final themes = ThemeController();
  await themes.load(themeId: settings.themePackId);

  runApp(MiaApp(themes: themes, settings: settings));
}

class MiaApp extends StatelessWidget {
  const MiaApp({
    super.key,
    required this.themes,
    required this.settings,
  });

  final ThemeController themes;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: ThemeScope(
        controller: themes,
        child: ListenableBuilder(
          listenable: Listenable.merge([themes, settings]),
          builder: (context, _) {
            final pack = themes.pack;
            ThemePack.current = pack;
            return MaterialApp(
              title: pack.name,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(pack),
              darkTheme: AppTheme.dark(pack),
              themeMode: settings.themeMode,
              home: HomeScreen(
                auth: AuthService(),
                themes: themes,
              ),
            );
          },
        ),
      ),
    );
  }
}
