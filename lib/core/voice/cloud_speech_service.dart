import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../config/config.dart';
import 'functions_client.dart';

class CloudSpeechService {
  CloudSpeechService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  bool _recording = false;
  Completer<void>? _lock;

  bool get isRecording => _recording;

  Future<T> _serialized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      await _lock!.future;
    }
    final lock = Completer<void>();
    _lock = lock;
    try {
      return await action();
    } finally {
      _lock = null;
      lock.complete();
    }
  }

  Future<bool> ensureMicPermission() async {
    if (await _recorder.hasPermission()) return true;
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      throw Exception(
        'Microphone permission is off. Enable it in Settings.',
      );
    }
    return false;
  }

  Future<void> startRecording() {
    return _serialized(() async {
      if (_recording) return;
      final allowed = await ensureMicPermission();
      if (!allowed) {
        throw Exception('Microphone permission denied.');
      }

      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'mia_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _recording = true;
    });
  }

  Future<String?> stopAndTranscribe() {
    return _serialized(() async {
      if (!_recording) return null;
      _recording = false;
      final path = await _recorder.stop();
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      try {
        await file.delete();
      } catch (_) {}
      if (bytes.isEmpty) return null;
      return transcribeWav(bytes);
    });
  }

  Future<void> cancel() {
    return _serialized(() async {
      if (!_recording) return;
      _recording = false;
      await _recorder.stop();
    });
  }

  Future<String> transcribeWav(List<int> bytes) async {
    if (AppConfig.assemblyAiApiKey.isNotEmpty) {
      return _transcribeViaAssemblyAi(bytes, AppConfig.assemblyAiApiKey);
    }

    final pcm = _pcmFromWav(bytes);
    try {
      return await _transcribeViaFunction(pcm);
    } catch (_) {
      if (AppConfig.gcpApiKey.isNotEmpty) {
        return _transcribeViaGoogle(pcm, AppConfig.gcpApiKey);
      }
      rethrow;
    }
  }

  static Future<String> _transcribeViaAssemblyAi(
    List<int> wavBytes,
    String apiKey,
  ) async {
    final upload = await http.post(
      Uri.parse('https://api.assemblyai.com/v2/upload'),
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/octet-stream',
      },
      body: wavBytes,
    );
    if (upload.statusCode < 200 || upload.statusCode >= 300) {
      throw Exception('AssemblyAI upload failed: ${upload.statusCode}');
    }
    final uploadUrl =
        (jsonDecode(upload.body) as Map<String, dynamic>)['upload_url']
            as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception('AssemblyAI upload failed: no URL');
    }

    final create = await http.post(
      Uri.parse('https://api.assemblyai.com/v2/transcript'),
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'audio_url': uploadUrl,
        'speech_model': 'universal',
        'language_code': 'en_us',
      }),
    );
    if (create.statusCode < 200 || create.statusCode >= 300) {
      throw Exception('AssemblyAI transcript failed: ${create.statusCode}');
    }
    final id = (jsonDecode(create.body) as Map<String, dynamic>)['id'] as String?;
    if (id == null) {
      throw Exception('AssemblyAI transcript failed: no id');
    }

    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final poll = await http.get(
        Uri.parse('https://api.assemblyai.com/v2/transcript/$id'),
        headers: {'Authorization': apiKey},
      );
      if (poll.statusCode != 200) {
        throw Exception('AssemblyAI poll failed: ${poll.statusCode}');
      }
      final data = jsonDecode(poll.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status == 'completed') {
        return (data['text'] as String? ?? '').trim();
      }
      if (status == 'error') {
        throw Exception('AssemblyAI error: ${data['error']}');
      }
    }
    throw Exception('AssemblyAI timed out.');
  }

  static Future<String> _transcribeViaFunction(List<int> bytes) async {
    final response = await FunctionsClient.postJson(
      'transcribeSpeech',
      jsonEncode({'audioContent': base64Encode(bytes)}),
    );
    if (response.statusCode != 200) {
      throw Exception('Transcription failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['transcript'] as String? ?? '').trim();
  }

  static Future<String> _transcribeViaGoogle(
    List<int> bytes,
    String apiKey,
  ) async {
    final response = await http.post(
      Uri.parse(
        'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'config': {
          'encoding': 'LINEAR16',
          'sampleRateHertz': 16000,
          'languageCode': 'en-US',
          'enableAutomaticPunctuation': true,
        },
        'audio': {'content': base64Encode(bytes)},
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Transcription failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    final buffer = StringBuffer();
    for (final result in results) {
      final alts = (result as Map<String, dynamic>)['alternatives'] as List?;
      if (alts != null && alts.isNotEmpty) {
        buffer.write(alts.first['transcript'] ?? '');
        buffer.write(' ');
      }
    }
    return buffer.toString().trim();
  }

  /// Cloud Speech LINEAR16 wants raw PCM, not a RIFF/WAV wrapper.
  static List<int> _pcmFromWav(List<int> bytes) {
    if (bytes.length > 44 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      for (var i = 12; i + 8 < bytes.length; i++) {
        if (bytes[i] == 0x64 &&
            bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 &&
            bytes[i + 3] == 0x61) {
          final size = bytes[i + 4] |
              (bytes[i + 5] << 8) |
              (bytes[i + 6] << 16) |
              (bytes[i + 7] << 24);
          final start = i + 8;
          final end = (start + size).clamp(start, bytes.length);
          return bytes.sublist(start, end);
        }
      }
      return bytes.sublist(44);
    }
    return bytes;
  }
}
