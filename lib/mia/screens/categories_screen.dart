import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/app_components.dart';
import '../../core/voice/cloud_speech_service.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../services/category_repository.dart';
import '../services/task_repository.dart';
import '../widgets/mia_bottom_bar.dart';
import 'voice_task_sheet.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.uid});

  final String uid;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final _repository = CategoryRepository();
  final _tasks = TaskRepository();
  final _speech = CloudSpeechService();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake;
  bool _saving = false;
  bool _showPickers = false;
  String _emoji = '📁';
  int _colorIndex = 0;

  static const _emojis = [
    '📁',
    '🛒',
    '📚',
    '💼',
    '🏠',
    '🎯',
    '💡',
    '✈️',
    '💪',
    '❤️',
  ];

  @override
  void initState() {
    super.initState();
    _repository.ensureDefaults(widget.uid);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _focus.addListener(() {
      if (_focus.hasFocus && !_showPickers) {
        setState(() => _showPickers = true);
      }
    });
    _controller.addListener(() {
      if (_controller.text.isNotEmpty && !_showPickers) {
        setState(() => _showPickers = true);
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _controller.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _openVoice() {
    return showVoiceTaskSheet(
      context: context,
      speech: _speech,
      categories: const [],
      onAddTask: (_) async {
        if (mounted) Navigator.pop(context);
      },
      onAddCategory: (name) async {
        await _repository.createCategory(uid: widget.uid, name: name);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category “$name” added')),
        );
      },
      onOpenHome: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  Future<void> _addCategory() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() => _showPickers = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a category name')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.createCategory(
        uid: widget.uid,
        name: name,
        emoji: _emoji,
        colorIndex: _colorIndex,
      );
      _controller.clear();
      setState(() {
        _emoji = '📁';
        _colorIndex = 0;
        _showPickers = false;
      });
      _focus.unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(TaskCategory category, int openCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: Text(
          openCount > 0
              ? 'This category has $openCount open task${openCount == 1 ? '' : 's'}. Tasks will keep their labels.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.high),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repository.deleteCategory(
      uid: widget.uid,
      categoryId: category.id,
    );
  }

  Future<void> _editCategory(TaskCategory category) async {
    final nameController = TextEditingController(text: category.name);
    var emoji = category.emoji;
    var colorIndex = category.colorIndex;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: 'Category name'),
                  ),
                  const SizedBox(height: 16),
                  Text('Color', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: List.generate(6, (i) {
                      final color = AppColors.palette[i];
                      final selected = colorIndex == i;
                      return GestureDetector(
                        onTap: () => setModal(() => colorIndex = i),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: AppColors.text, width: 2.5)
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text('Icon', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _emojis.map((e) {
                      final selected = emoji == e;
                      return GestureDetector(
                        onTap: () => setModal(() => emoji = e),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.tint : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(
                              color: selected
                                  ? AppColors.indigo
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      await _repository.updateCategory(
        uid: widget.uid,
        categoryId: category.id,
        name: nameController.text.trim(),
        emoji: emoji,
        colorIndex: colorIndex,
      );
    }
    nameController.dispose();
  }

  Widget _colorDot(int i) {
    final selected = _colorIndex == i;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _colorIndex = i),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.palette[i],
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: AppColors.text, width: 2.5)
                : Border.all(color: Colors.transparent, width: 2.5),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _emojiTile(String e) {
    final selected = _emoji == e;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _emoji = e),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.tint : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: selected ? AppColors.indigo : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(e, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      bottomNavigationBar: MiaBottomBar(
        onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onMic: _openVoice,
        onAdd: () {
          setState(() => _showPickers = true);
          _focus.requestFocus();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final dx = (1 - _shake.value) *
                    8 *
                    ((_shake.value * 10).floor().isEven ? 1 : -1) *
                    (_shake.isAnimating ? 1 : 0);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCategory(),
                    onTap: () => setState(() => _showPickers = true),
                    decoration: InputDecoration(
                      hintText: 'New category name',
                      suffixIcon: IconButton(
                        tooltip: 'Add',
                        onPressed: _saving ? null : _addCategory,
                        icon: Icon(
                          Icons.add_circle_rounded,
                          color: _saving ? AppColors.muted : AppColors.indigo,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _showPickers
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Color',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 36,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: List.generate(6, _colorDot),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  color: AppColors.muted.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Icon',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 36,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: _emojis.map(_emojiTile).toList(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TaskCategory>>(
              stream: _repository.watchCategories(widget.uid),
              builder: (context, catSnap) {
                return StreamBuilder<List<Task>>(
                  stream: _tasks.watchTasks(widget.uid),
                  builder: (context, taskSnap) {
                    if (catSnap.hasError) {
                      return Center(child: Text('${catSnap.error}'));
                    }
                    if (!catSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final categories = catSnap.data!;
                    final tasks = taskSnap.data ?? const <Task>[];
                    if (categories.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: AppColors.tint,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.category_outlined,
                                size: 40,
                                color: AppColors.indigo,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No categories yet',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add one above to organize your tasks',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: categories.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final openCount = tasks
                                  .where(
                                    (t) =>
                                        t.categoryId == category.id &&
                                        t.status != TaskStatus.completed,
                                  )
                                  .length;
                              final color = AppColors.palette[
                                  category.colorIndex %
                                      AppColors.palette.length];

                              return Dismissible(
                                key: ValueKey(category.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  await _confirmDelete(category, openCount);
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.high,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.lg),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                child: PressableScale(
                                  onTap: () =>
                                      Navigator.pop(context, category.id),
                                  child: GestureDetector(
                                    onLongPress: () =>
                                        _editCategory(category),
                                    child: AppCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppRadii.sm,
                                              ),
                                            ),
                                            child: Text(
                                              category.emoji,
                                              style: const TextStyle(
                                                fontSize: 22,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  category.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  '$openCount open task${openCount == 1 ? '' : 's'}',
                                                  style: TextStyle(
                                                    color: AppColors.muted,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppColors.muted.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                          child: Text(
                            'Swipe left to delete · Tap to view tasks · Long-press to rename',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
