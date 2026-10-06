import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Set to false later to bring the login screen back.
  static const skipSignIn = true;

  /// Used while skipSignIn is true (no email login required).
  static const guestUid = 'local-guest';

  /// Prefer `.env`, then `--dart-define=NAME=...`.
  static String _env(String key, {String fromDefine = ''}) {
    final fromFile = dotenv.isInitialized ? (dotenv.env[key] ?? '') : '';
    if (fromFile.trim().isNotEmpty) return fromFile.trim();
    return fromDefine.trim();
  }

  /// Deployed HTTP functions for this Firebase project.
  static String get functionsUrl {
    final override = _env(
      'FUNCTIONS_URL',
      fromDefine: const String.fromEnvironment('FUNCTIONS_URL'),
    );
    if (override.isNotEmpty) return override;
    return 'https://us-central1-voice-task-app-bym.cloudfunctions.net';
  }

  /// Optional Google Cloud API key for Speech / Gemini fallback.
  static String get gcpApiKey => _env(
        'GCP_API_KEY',
        fromDefine: const String.fromEnvironment('GCP_API_KEY'),
      );

  /// Gemini enrichment + intent AI.
  static String get geminiApiKey => _env(
        'GEMINI_API_KEY',
        fromDefine: const String.fromEnvironment('GEMINI_API_KEY'),
      );

  /// AssemblyAI speech-to-text.
  static String get assemblyAiApiKey => _env(
        'ASSEMBLYAI_API_KEY',
        fromDefine: const String.fromEnvironment('ASSEMBLYAI_API_KEY'),
      );

  static bool get canTranscribe =>
      assemblyAiApiKey.isNotEmpty || gcpApiKey.isNotEmpty;

  static bool get canEnrich =>
      geminiApiKey.isNotEmpty || gcpApiKey.isNotEmpty;
}
