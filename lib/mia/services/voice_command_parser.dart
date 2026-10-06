class VoiceCommandParser {
  static const wakePhrases = [
    'hey mia',
    'hi mia',
    'hey miya',
    'hay mia',
    'hey meer',
    'hey meea',
  ];

  static final _leadingFiller = RegExp(
    r'^(can you |could you |please |will you )+',
    caseSensitive: false,
  );

  static final _addPrefix = RegExp(
    r'^(add (a |the )?task[s]? |add |create (a |the )?task[s]? |remind me to )',
    caseSensitive: false,
  );

  static bool containsWakeWord(String transcript) {
    final normalized = _normalize(transcript);
    return wakePhrases.any(normalized.contains);
  }

  /// For mic-button captures: strip a wake phrase if present, otherwise use all text.
  static String taskTextFrom(String transcript, {required bool requireWakeWord}) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return '';

    final normalized = _normalize(trimmed);
    for (final phrase in wakePhrases) {
      final index = normalized.indexOf(phrase);
      if (index >= 0) {
        final after = trimmed.substring(index + phrase.length).trim();
        return _cleanCommand(after);
      }
    }

    if (requireWakeWord) return '';
    return _cleanCommand(trimmed);
  }

  static String _cleanCommand(String text) {
    var result = text.replaceFirst(RegExp(r'^[,.!:;?\-\s]+'), '').trim();
    result = result.replaceFirst(_leadingFiller, '').trim();
    result = result.replaceFirst(_addPrefix, '').trim();
    return result;
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
