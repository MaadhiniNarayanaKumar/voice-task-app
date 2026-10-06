import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_due_widgets.dart';

Future<void> showEditTaskSheet({
  required BuildContext context,
  required Task task,
  required List<TaskCategory> categories,
  required Future<void> Function({
    required String title,
    required String priority,
    DateTime? dueDate,
    String? categoryId,
    String? categoryName,
  }) onSave,
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
        child: _EditTaskForm(
          task: task,
          categories: categories,
          onSave: onSave,
        ),
      );
    },
  );
}

class _EditTaskForm extends StatefulWidget {
  const _EditTaskForm({
    required this.task,
    required this.categories,
    required this.onSave,
  });

  final Task task;
  final List<TaskCategory> categories;
  final Future<void> Function({
    required String title,
    required String priority,
    DateTime? dueDate,
    String? categoryId,
    String? categoryName,
  }) onSave;

  @override
  State<_EditTaskForm> createState() => _EditTaskFormState();
}

class _EditTaskFormState extends State<_EditTaskForm> {
  late final TextEditingController _title;
  late String _priority;
  DateTime? _dueDate;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;
    _categoryId = widget.task.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String? get _categoryName {
    if (_categoryId == null) return null;
    for (final category in widget.categories) {
      if (category.id == _categoryId) return category.name;
    }
    return widget.task.categoryName;
  }

  Future<void> _save() async {
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a due date.')),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(
      title: _title.text.trim().isEmpty
          ? widget.task.rawText
          : _title.text.trim(),
      priority: _priority,
      dueDate: _dueDate,
      categoryId: _categoryId,
      categoryName: _categoryName,
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
            Text('Edit task', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _title,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'What needs doing?',
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            CategorySelector(
              categories: widget.categories,
              selectedId: _categoryId,
              allowNone: true,
              onChanged: (value) => setState(() => _categoryId = value),
            ),
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
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
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
