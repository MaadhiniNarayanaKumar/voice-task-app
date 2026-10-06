import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/voice/cloud_speech_service.dart';
import '../models/category.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_due_widgets.dart';

class AddTaskDraft {
  const AddTaskDraft({
    required this.text,
    required this.priority,
    this.dueDate,
    this.categoryId,
    this.categoryName,
    this.notes,
  });

  final String text;
  final String priority;
  final DateTime? dueDate;
  final String? categoryId;
  final String? categoryName;
  final String? notes;
}

Future<void> showAddTaskSheet({
  required BuildContext context,
  required Future<void> Function(AddTaskDraft draft) onAdd,
  List<TaskCategory> categories = const [],
  CloudSpeechService? speech,
  VoidCallback? onVoice,
  String initialText = '',
  String initialPriority = 'low',
  DateTime? initialDueDate,
  String? initialCategoryId,
  String? heardCaption,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
        child: _AddTaskForm(
          onAdd: onAdd,
          onVoice: onVoice,
          categories: categories,
          initialText: initialText,
          initialPriority: initialPriority,
          initialDueDate: initialDueDate,
          initialCategoryId: initialCategoryId,
          heardCaption: heardCaption,
        ),
      );
    },
  );
}

class _AddTaskForm extends StatefulWidget {
  const _AddTaskForm({
    required this.onAdd,
    this.onVoice,
    required this.categories,
    required this.initialText,
    required this.initialPriority,
    this.initialDueDate,
    this.initialCategoryId,
    this.heardCaption,
  });

  final Future<void> Function(AddTaskDraft draft) onAdd;
  final VoidCallback? onVoice;
  final List<TaskCategory> categories;
  final String initialText;
  final String initialPriority;
  final DateTime? initialDueDate;
  final String? initialCategoryId;
  final String? heardCaption;

  @override
  State<_AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<_AddTaskForm> {
  late final TextEditingController _controller;
  late final TextEditingController _notes;
  late String _priority;
  DateTime? _dueDate;
  String? _categoryId;
  bool _saving = false;
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _notes = TextEditingController();
    _priority = widget.initialPriority;
    _dueDate = widget.initialDueDate;
    _categoryId = widget.initialCategoryId;
    if (widget.initialText.isNotEmpty) {
      _controller.selection =
          TextSelection.collapsed(offset: widget.initialText.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a task first.')),
      );
      return;
    }
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a due date.')),
      );
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
    await widget.onAdd(
      AddTaskDraft(
        text: text,
        priority: _priority,
        dueDate: _dueDate,
        categoryId: _categoryId,
        categoryName: categoryName,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a task', style: Theme.of(context).textTheme.titleLarge),
            if (widget.heardCaption != null) ...[
              const SizedBox(height: 8),
              Text(
                'What I heard: “${widget.heardCaption}”',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'What needs doing?',
                suffixIcon: widget.onVoice == null
                    ? null
                    : IconButton(
                        tooltip: 'Dictate',
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onVoice!();
                        },
                        icon: const Icon(Icons.mic_rounded),
                      ),
              ),
            ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              CategorySelector(
                categories: widget.categories,
                selectedId: _categoryId,
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            PrioritySelector(
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: AppSpace.lg),
            DueDateCalendar(
              selected: _dueDate,
              onChanged: (date) => setState(() => _dueDate = date),
            ),
            const SizedBox(height: AppSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showNotes = !_showNotes),
                icon: Icon(
                  _showNotes
                      ? Icons.expand_less_rounded
                      : Icons.notes_rounded,
                ),
                label: Text(_showNotes ? 'Hide notes' : 'Add notes'),
              ),
            ),
            if (_showNotes)
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Optional notes…',
                ),
              ),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Add'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
