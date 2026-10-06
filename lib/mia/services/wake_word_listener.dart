import '../../core/voice/cloud_speech_service.dart';
import 'voice_command_parser.dart';

enum WakeWordPhase { idle, listening, heardWake, processing }

/// Chunked Cloud Speech loop that watches for "hey mia" while the app is open.
class WakeWordListener {
  WakeWordListener(this._speech);

  final CloudSpeechService _speech;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start({
    required void Function(WakeWordPhase phase, String transcript) onState,
    required Future<void> Function(String command) onCommand,
  }) async {
    if (_running) return;
    _running = true;
    onState(WakeWordPhase.listening, '');

    var failures = 0;
    while (_running) {
      try {
        await _speech.startRecording();
        await Future.delayed(const Duration(milliseconds: 2800));
        if (!_running) {
          await _speech.cancel();
          break;
        }
        final chunk = await _speech.stopAndTranscribe();
        failures = 0;
        if (!_running) break;
        final text = chunk?.trim() ?? '';
        if (text.isEmpty) continue;

        onState(WakeWordPhase.listening, text);

        if (!VoiceCommandParser.containsWakeWord(text)) continue;

        var command = VoiceCommandParser.taskTextFrom(
          text,
          requireWakeWord: true,
        );
        onState(WakeWordPhase.heardWake, text);

        if (command.split(RegExp(r'\s+')).length < 2) {
          await _speech.startRecording();
          await Future.delayed(const Duration(seconds: 5));
          if (!_running) {
            await _speech.cancel();
            break;
          }
          final followUp = await _speech.stopAndTranscribe();
          command = VoiceCommandParser.taskTextFrom(
            '$command ${followUp ?? ''}',
            requireWakeWord: false,
          );
        }

        if (command.isEmpty) {
          onState(WakeWordPhase.listening, '');
          continue;
        }

        onState(WakeWordPhase.processing, command);
        await onCommand(command);
        onState(WakeWordPhase.listening, '');
      } catch (_) {
        failures += 1;
        if (failures >= 3) {
          onState(WakeWordPhase.idle, 'Voice service unavailable');
          _running = false;
          break;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    onState(WakeWordPhase.idle, '');
  }

  Future<void> stop() async {
    _running = false;
    await _speech.cancel();
  }
}
