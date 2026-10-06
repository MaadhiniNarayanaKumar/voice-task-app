import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/services/task_enrichment_service.dart';
import 'package:voice_task_app/services/voice_command_parser.dart';

void main() {
  test('strips Hey Mia and add-task filler', () {
    expect(
      VoiceCommandParser.taskTextFrom(
        'Hey Mia, can you add a task buy milk tomorrow',
        requireWakeWord: true,
      ),
      'buy milk tomorrow',
    );
  });

  test('mic capture does not require a wake word', () {
    expect(
      VoiceCommandParser.taskTextFrom(
        'email the landlord today',
        requireWakeWord: false,
      ),
      'email the landlord today',
    );
  });

  test('requires wake word when asked', () {
    expect(
      VoiceCommandParser.taskTextFrom(
        'buy milk',
        requireWakeWord: true,
      ),
      '',
    );
  });

  test('detects wake word variants', () {
    expect(VoiceCommandParser.containsWakeWord('hi mia add milk'), isTrue);
    expect(VoiceCommandParser.containsWakeWord('hello there'), isFalse);
  });

  test('heuristic classifies groceries from keywords', () {
    final result = TaskEnrichmentService.heuristic(
      'buy milk and eggs',
      const ['Groceries', 'Class', 'Job', 'Personal'],
    );
    expect(result.categoryName, 'Groceries');
  });
}
