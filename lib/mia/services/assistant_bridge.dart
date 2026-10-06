import 'package:flutter/services.dart';

class AssistantBridge {
  static const _channel = MethodChannel('mia/intents');

  static Future<void> listen(void Function(String text) onTaskText) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'addTask') {
        final text = call.arguments?.toString() ?? '';
        if (text.trim().isNotEmpty) onTaskText(text.trim());
      }
    });

    try {
      final pending = await _channel.invokeMethod<String>('getPending');
      if (pending != null && pending.trim().isNotEmpty) {
        onTaskText(pending.trim());
      }
    } on MissingPluginException {
      // Native channel is not available on this platform.
    } catch (_) {}
  }
}
