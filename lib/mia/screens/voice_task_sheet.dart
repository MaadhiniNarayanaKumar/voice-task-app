import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/voice/cloud_speech_service.dart';
import '../../core/voice/listening_sheet.dart';
import '../models/category.dart';
import '../services/voice_intent_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_due_widgets.dart';
import 'add_task_sheet.dart';

enum _VoicePhase { listening, processing, confirm }

class VoiceActionResult {
  const VoiceActionResult._(this.kind, {this.draft, this.categoryName});

  final VoiceIntentKind kind;
  final AddTaskDraft? draft;
  final String? categoryName;

  factory VoiceActionResult.addTask(AddTaskDraft draft) =>
      VoiceActionResult._(VoiceIntentKind.addTask, draft: draft);

  factory VoiceActionResult.addCategory(String name) =>
      VoiceActionResult._(VoiceIntentKind.addCategory, categoryName: name);

  factory VoiceActionResult.navigate(VoiceIntentKind kind) =>
      VoiceActionResult._(kind);
}

Future<void> showVoiceTaskSheet({
  required BuildContext context,
  required CloudSpeechService speech,
  required Future<void> Function(AddTaskDraft draft) onAddTask,
  required Future<void> Function(String name) onAddCategory,
  VoidCallback? onOpenCategories,
  VoidCallback? onOpenTasks,
  VoidCallback? onOpenHome,
  List<TaskCategory> categories = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _VoiceTaskSheet(
          speech: speech,
          categories: categories,
          onAddTask: onAddTask,
          onAddCategory: onAddCategory,
          onOpenCategories: onOpenCategories,
          onOpenTasks: onOpenTasks,
          onOpenHome: onOpenHome,
        ),
      );
    },
  );
}

class _VoiceTaskSheet extends StatefulWidget {
  const _VoiceTaskSheet({
    required this.speech,
    required this.categories,
    required this.onAddTask,
    required this.onAddCategory,
    this.onOpenCategories,
    this.onOpenTasks,
    this.onOpenHome,
  });

  final CloudSpeechService speech;
  final List<TaskCategory> categories;
  final Future<void> Function(AddTaskDraft draft) onAddTask;
  final Future<void> Function(String name) onAddCategory;
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenHome;

  @override
  State<_VoiceTaskSheet> createState() => _VoiceTaskSheetState();
}

class _VoiceTaskSheetState extends State<_VoiceTaskSheet>
    with SingleTickerProviderStateMixin {
  _VoicePhase _phase = _VoicePhase.listening;
  final _controller = TextEditingController();
  VoiceIntent? _intent;
  String _priority = 'medium';
  DateTime? _dueDate;
  String? _categoryId;
  bool _saving = false;
  String? _error;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startListening();
  }

  @override
  void dispose() {
    if (_phase == _VoicePhase.listening) {
      widget.speech.cancel();
    }
    _pulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _phase = _VoicePhase.listening;
      _error = null;
      _intent = null;
    });
    try {
      HapticFeedback.lightImpact();
      await widget.speech.startRecording();
      _pulse.repeat(reverse: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _stopAndProcess() async {
    setState(() {
      _phase = _VoicePhase.processing;
      _error = null;
    });
    _pulse.stop();
    HapticFeedback.mediumImpact();
    try {
      final transcript = await widget.speech.stopAndTranscribe();
      if (!mounted) return;
      if (transcript == null || transcript.trim().isEmpty) {
        setState(() {
          _phase = _VoicePhase.listening;
          _error = "I didn't catch that. Try again.";
        });
        _pulse.repeat(reverse: true);
        await widget.speech.startRecording();
        return;
      }

      final names = widget.categories.map((c) => c.name).toList();
      final intent = await VoiceIntentService.classify(
        transcript,
        categoryNames: names,
      );
      if (!mounted) return;

      _intent = intent;
      _priority = intent.priority;
      _dueDate =
          intent.dueDate ?? DateTime.now().add(const Duration(days: 1));
      _categoryId = null;
      if (intent.categoryName != null) {
        for (final c in widget.categories) {
          if (c.name.toLowerCase() == intent.categoryName!.toLowerCase()) {
            _categoryId = c.id;
            break;
          }
        }
      }

      switch (intent.kind) {
        case VoiceIntentKind.addTask:
          _controller.text = intent.taskTitle ?? intent.transcript;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        case VoiceIntentKind.addCategory:
          _controller.text = intent.categoryName ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        case VoiceIntentKind.help:
        case VoiceIntentKind.openCategories:
        case VoiceIntentKind.openTasks:
        case VoiceIntentKind.openHome:
        case VoiceIntentKind.unknown:
          _controller.text = intent.transcript;
      }

      setState(() => _phase = _VoicePhase.confirm);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _VoicePhase.listening;
        _error = '$e';
      });
      _pulse.repeat(reverse: true);
      try {
        await widget.speech.startRecording();
      } catch (_) {}
    }
  }

  Future<void> _cancel() async {
    if (_phase == _VoicePhase.listening) {
      await widget.speech.cancel();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reRecord() async {
    setState(() {
      _phase = _VoicePhase.listening;
      _error = null;
      _intent = null;
    });
    await _startListening();
  }

  Future<void> _confirm() async {
    final intent = _intent;
    if (intent == null) return;

    switch (intent.kind) {
      case VoiceIntentKind.addTask:
        final text = _controller.text.trim();
        if (text.isEmpty) {
          setState(() => _error = 'Enter a task first.');
          return;
        }
        if (_dueDate == null) {
          setState(() => _error = 'Please pick a due date.');
          return;
        }
        String? categoryName;
        if (_categoryId != null) {
          for (final c in widget.categories) {
            if (c.id == _categoryId) {
              categoryName = c.name;
              break;
            }
          }
        }
        setState(() => _saving = true);
        HapticFeedback.lightImpact();
        await widget.onAddTask(
          AddTaskDraft(
            text: text,
            priority: _priority,
            dueDate: _dueDate,
            categoryId: _categoryId,
            categoryName: categoryName,
          ),
        );
        if (mounted) Navigator.pop(context);

      case VoiceIntentKind.addCategory:
        final name = _controller.text.trim();
        if (name.isEmpty) {
          setState(() => _error = 'Enter a category name.');
          return;
        }
        setState(() => _saving = true);
        HapticFeedback.lightImpact();
        await widget.onAddCategory(name);
        if (mounted) Navigator.pop(context);

      case VoiceIntentKind.openCategories:
        Navigator.pop(context);
        widget.onOpenCategories?.call();

      case VoiceIntentKind.openTasks:
        Navigator.pop(context);
        widget.onOpenTasks?.call();

      case VoiceIntentKind.openHome:
        Navigator.pop(context);
        widget.onOpenHome?.call();

      case VoiceIntentKind.help:
      case VoiceIntentKind.unknown:
        // Stay on sheet; user can re-record or cancel.
        setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: switch (_phase) {
            _VoicePhase.listening => ListeningSheet(
                pulse: _pulse,
                error: _error,
                onStop: _stopAndProcess,
                onCancel: _cancel,
                onOpenSettings: openAppSettings,
                hint:
                    'Try: “Buy milk tomorrow” or “Add category Class”',
              ),
            _VoicePhase.processing => const _ProcessingPane(),
            _VoicePhase.confirm => _buildConfirm(),
          },
        ),
      ),
    );
  }

  Widget _buildConfirm() {
    final intent = _intent!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          intent.actionLabel,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'What I heard: “${intent.transcript}”',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(
            intent.summary,
            style: TextStyle(
              color: AppColors.indigo,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...switch (intent.kind) {
          VoiceIntentKind.addTask => _taskFields(),
          VoiceIntentKind.addCategory => _categoryFields(),
          VoiceIntentKind.openCategories ||
          VoiceIntentKind.openTasks ||
          VoiceIntentKind.openHome =>
            [
              Text(
                'Tap confirm to ${intent.summary.toLowerCase()}.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          VoiceIntentKind.help || VoiceIntentKind.unknown => [
              const Text(
                'You can say things like:\n'
                '• “Buy milk tomorrow, high priority”\n'
                '• “Add category Groceries”\n'
                '• “Open categories”\n'
                '• “Show my tasks”\n'
                '• “Go home”',
                style: TextStyle(height: 1.45),
              ),
            ],
        },
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.high)),
        ],
        const SizedBox(height: 20),
        if (intent.kind == VoiceIntentKind.help ||
            intent.kind == VoiceIntentKind.unknown)
          FilledButton(
            onPressed: _reRecord,
            child: const Text('Try again'),
          )
        else
          FilledButton(
            onPressed: _saving ? null : _confirm,
            child: Text(intent.actionLabel),
          ),
        TextButton(
          onPressed: _saving ? null : _reRecord,
          child: const Text('Re-record'),
        ),
        TextButton(
          onPressed: _saving ? null : _cancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  List<Widget> _taskFields() {
    return [
      TextField(
        controller: _controller,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'What needs doing?',
          suffixIcon: IconButton(
            tooltip: 'Re-record',
            onPressed: _reRecord,
            icon: const Icon(Icons.mic_rounded),
          ),
        ),
      ),
      if (widget.categories.isNotEmpty) ...[
        const SizedBox(height: 16),
        CategorySelector(
          categories: widget.categories,
          selectedId: _categoryId,
          onChanged: (value) => setState(() => _categoryId = value),
        ),
      ],
      const SizedBox(height: 16),
      PrioritySelector(
        value: _priority,
        onChanged: (value) => setState(() => _priority = value),
      ),
      const SizedBox(height: 16),
      DueDateCalendar(
        selected: _dueDate,
        onChanged: (value) => setState(() => _dueDate = value),
      ),
    ];
  }

  List<Widget> _categoryFields() {
    return [
      TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'Category name',
        ),
      ),
    ];
  }
}

class _ProcessingPane extends StatelessWidget {
  const _ProcessingPane();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Understanding…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Figuring out if this is a task, category, or action',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
