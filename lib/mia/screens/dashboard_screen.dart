import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/config.dart';
import '../../core/nav/raised_center_nav_bar.dart';
import '../../core/prefs/local_flags.dart';
import '../../core/settings/settings_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/app_components.dart';
import '../../core/voice/cloud_speech_service.dart';
import '../../app/settings/settings_screen.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../services/assistant_bridge.dart';
import '../services/category_repository.dart';
import '../services/priority_escalation.dart';
import '../services/task_enrichment_service.dart';
import '../services/task_repository.dart';
import '../services/voice_command_parser.dart';
import 'add_task_sheet.dart';
import 'categories_screen.dart';
import 'edit_task_sheet.dart';
import '../widgets/mia_bottom_bar.dart';
import 'voice_task_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.auth,
    required this.uid,
    this.initialFilterCategoryId,
  });

  final AuthService auth;
  final String uid;
  final String? initialFilterCategoryId;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _speech = CloudSpeechService();
  final _repository = TaskRepository();
  final _categories = CategoryRepository();

  int _refreshToken = 0;
  String? _filterCategoryId;
  List<TaskCategory> _categoryCache = [];
  final Set<String> _escalating = {};
  final Set<String> _completing = {};
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _search = '';
  String _sort = 'due';
  bool _showMicTip = false;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _filterCategoryId = widget.initialFilterCategoryId;
    AssistantBridge.listen(_onExternalTaskText);
    _categories.ensureDefaults(widget.uid);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMicTip());
  }

  Future<void> _loadMicTip() async {
    final settings = SettingsScope.maybeOf(context);
    if (settings != null && !settings.miaVoiceTips) {
      if (!mounted) return;
      setState(() => _showMicTip = false);
      return;
    }
    final dismissed = await LocalFlags.isSet(LocalFlags.micTipDismissed);
    if (!mounted) return;
    setState(() => _showMicTip = !dismissed);
  }

  Future<void> _dismissMicTip() async {
    setState(() => _showMicTip = false);
    await LocalFlags.set(LocalFlags.micTipDismissed);
  }

  @override
  void dispose() {
    _speech.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _displayTitle(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final time = TimeOfDay.fromDateTime(due);
    final timeLabel = time.format(context);
    final diff = dueDay.difference(start).inDays;
    if (diff == 0) return 'Today, $timeLabel';
    if (diff == 1) return 'Tomorrow, $timeLabel';
    if (diff == -1) return 'Yesterday, $timeLabel';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[due.month - 1]} ${due.day}, $timeLabel';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh() async {
    await _speech.cancel();
    if (!mounted) return;
    setState(() => _refreshToken++);
  }

  Future<void> _onExternalTaskText(String text) async {
    final command = VoiceCommandParser.taskTextFrom(
      text,
      requireWakeWord: false,
    );
    if (command.isEmpty || !mounted) return;
    await _openTypeSheet(initialText: command);
  }

  Future<void> _createFromDraft(AddTaskDraft draft) async {
    final text = draft.text.trim();
    if (text.isEmpty || draft.dueDate == null) return;

    try {
      final priority = PriorityEscalation.effective(
        current: draft.priority,
        dueDate: draft.dueDate,
        completed: false,
      );
      final raw = draft.notes == null || draft.notes!.isEmpty
          ? text
          : '$text\n${draft.notes}';
      final id = await _repository.createTask(
        uid: widget.uid,
        rawText: raw,
        priority: priority,
        dueDate: draft.dueDate!,
        categoryId: draft.categoryId,
        categoryName: draft.categoryName,
      );
      if (draft.categoryId == null) {
        _enrichTask(id, text);
      } else {
        await _repository.applyTitleEnrichment(
          uid: widget.uid,
          taskId: id,
          title: text,
          categoryId: draft.categoryId,
          categoryName: draft.categoryName,
        );
      }
      if (!mounted) return;
      final where = draft.categoryName ?? 'tasks';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to $where')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save task: $e')),
      );
    }
  }

  Future<void> _enrichTask(String taskId, String rawText) async {
    try {
      final names = _categoryCache.map((c) => c.name).toList();
      final result = await TaskEnrichmentService.enrich(
        rawText,
        categoryNames: names,
      );

      String? categoryId;
      var categoryName = result.categoryName;
      if (categoryName != null) {
        final needle = categoryName.toLowerCase();
        for (final category in _categoryCache) {
          if (category.name.toLowerCase() == needle) {
            categoryId = category.id;
            categoryName = category.name;
            break;
          }
        }
      }

      await _repository.applyTitleEnrichment(
        uid: widget.uid,
        taskId: taskId,
        title: result.title,
        categoryId: categoryId,
        categoryName: categoryName,
      );
    } catch (e) {
      debugPrint('Enrichment failed: $e');
    }
  }

  Future<void> _openTypeSheet({String initialText = ''}) {
    final priority =
        SettingsScope.maybeOf(context)?.miaDefaultPriority ?? 'medium';
    return showAddTaskSheet(
      context: context,
      initialText: initialText,
      initialPriority: priority,
      categories: _categoryCache,
      speech: _speech,
      onAdd: _createFromDraft,
      onVoice: _openVoiceSheet,
    );
  }

  Future<void> _openVoiceSheet() async {
    if (!AppConfig.canTranscribe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your AssemblyAI key in lib/core/config/config.dart'),
        ),
      );
      return;
    }
    await showVoiceTaskSheet(
      context: context,
      speech: _speech,
      categories: _categoryCache,
      onAddTask: _createFromDraft,
      onAddCategory: _createCategoryFromVoice,
      onOpenCategories: () async {
        final id = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => CategoriesScreen(uid: widget.uid),
          ),
        );
        if (id != null && mounted) {
          setState(() => _filterCategoryId = id);
        }
      },
      onOpenTasks: () {
        setState(() => _filterCategoryId = null);
      },
      onOpenHome: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  Future<void> _createCategoryFromVoice(String name) async {
    try {
      await _categories.createCategory(uid: widget.uid, name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category “$name” added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add category: $e')),
      );
    }
  }

  List<Task> _applySort(List<Task> tasks) {
    final sorted = [...tasks];
    switch (_sort) {
      case 'priority':
        const rank = {'high': 0, 'medium': 1, 'low': 2};
        sorted.sort((a, b) {
          final ra = rank[a.priority] ?? 1;
          final rb = rank[b.priority] ?? 1;
          return ra.compareTo(rb);
        });
      case 'created':
        sorted.sort((a, b) {
          final aa = a.createdAt ?? DateTime(1970);
          final bb = b.createdAt ?? DateTime(1970);
          return bb.compareTo(aa);
        });
      default:
        sorted.sort((a, b) {
          final aa = a.dueDate ?? DateTime(2100);
          final bb = b.dueDate ?? DateTime(2100);
          return aa.compareTo(bb);
        });
    }
    return sorted;
  }

  bool _matchesSearch(Task task) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return task.title.toLowerCase().contains(q) ||
        task.rawText.toLowerCase().contains(q) ||
        (task.categoryName?.toLowerCase().contains(q) ?? false);
  }

  Future<void> _showTaskMenu(Task task) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Duplicate'),
                onTap: () => Navigator.pop(context, 'duplicate'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text('Change priority'),
                onTap: () => Navigator.pop(context, 'priority'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await showEditTaskSheet(
          context: context,
          task: task,
          categories: _categoryCache,
          onSave: ({
            required title,
            required priority,
            dueDate,
            categoryId,
            categoryName,
          }) {
            return _repository.updateTask(
              uid: widget.uid,
              taskId: task.id,
              title: title,
              priority: priority,
              dueDate: dueDate,
              categoryId: categoryId,
              categoryName: categoryName,
            );
          },
        );
      case 'duplicate':
        await _repository.duplicateTask(uid: widget.uid, task: task);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task duplicated')),
        );
      case 'priority':
        final next = switch (task.priority) {
          'low' => 'medium',
          'medium' => 'high',
          _ => 'low',
        };
        await _repository.updatePriority(
          uid: widget.uid,
          taskId: task.id,
          priority: next,
        );
      case 'delete':
        await _deleteWithUndo(task);
    }
  }

  Future<void> _deleteWithUndo(Task task) async {
    await _repository.deleteTask(uid: widget.uid, taskId: task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _repository.restoreTask(uid: widget.uid, task: task);
          },
        ),
      ),
    );
  }

  Future<void> _completeTask(Task task) async {
    if (_completing.contains(task.id)) return;
    setState(() => _completing.add(task.id));
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    await _repository.setCompleted(
      uid: widget.uid,
      taskId: task.id,
      completed: true,
    );
    if (!mounted) return;
    setState(() => _completing.remove(task.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task completed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _repository.setCompleted(
              uid: widget.uid,
              taskId: task.id,
              completed: false,
            );
          },
        ),
      ),
    );
  }

  void _escalateOpenTasks(List<Task> tasks) {
    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      if (_escalating.contains(task.id)) continue;
      final next = PriorityEscalation.effective(
        current: task.priority,
        dueDate: task.dueDate,
        completed: false,
      );
      if (next == task.priority) continue;
      _escalating.add(task.id);
      _repository
          .updatePriority(uid: widget.uid, taskId: task.id, priority: next)
          .whenComplete(() => _escalating.remove(task.id));
    }
  }

  int _countForCategory(List<Task> open, String? categoryId) {
    if (categoryId == null) return open.length;
    return open.where((t) => t.categoryId == categoryId).length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskCategory>>(
      stream: _categories.watchCategories(widget.uid),
      builder: (context, categorySnapshot) {
        _categoryCache = categorySnapshot.data ?? _categoryCache;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: StreamBuilder<List<Task>>(
            stream: _repository.watchTasks(widget.uid),
            builder: (context, taskSnap) {
              final open = (taskSnap.data ?? const <Task>[])
                  .where((t) => t.status != TaskStatus.completed)
                  .toList();
              return _buildDrawer(open);
            },
          ),
          body: StreamBuilder<List<Task>>(
            key: ValueKey(_refreshToken),
            stream: _repository.watchTasks(widget.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return _loadingSkeleton();
              }

              final all = snapshot.data!;
              final open = all
                  .where((t) => t.status != TaskStatus.completed)
                  .toList();
              final completed = all
                  .where((t) => t.status == TaskStatus.completed)
                  .toList();
              var filtered = _filterCategoryId == null
                  ? open
                  : open
                      .where((t) => t.categoryId == _filterCategoryId)
                      .toList();
              filtered = filtered.where(_matchesSearch).toList();
              filtered = _applySort(filtered);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _escalateOpenTasks(filtered);
              });

              final now = DateTime.now();
              final start = DateTime(now.year, now.month, now.day);
              final end = start.add(const Duration(days: 1));
              final tomorrowEnd = start.add(const Duration(days: 2));

              final overdue = <Task>[];
              final today = <Task>[];
              final tomorrow = <Task>[];
              final later = <Task>[];

              for (final task in filtered) {
                final due = task.dueDate;
                if (due == null) {
                  today.add(task);
                } else if (due.isBefore(start)) {
                  overdue.add(task);
                } else if (due.isBefore(end)) {
                  today.add(task);
                } else if (due.isBefore(tomorrowEnd)) {
                  tomorrow.add(task);
                } else {
                  later.add(task);
                }
              }

              final dueTodayCount = open.where((t) {
                final due = t.dueDate;
                return due != null && !due.isBefore(start) && due.isBefore(end);
              }).length;
              final overdueCount = open.where((t) {
                final due = t.dueDate;
                return due != null && due.isBefore(start);
              }).length;

              final avatarLetter =
                  (widget.auth.currentUser?.email ?? 'M').trim();
              final initial = avatarLetter.isEmpty
                  ? 'M'
                  : avatarLetter.characters.first.toUpperCase();

              return RefreshIndicator(
                color: AppColors.indigo,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    if (_searchOpen)
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: AppColors.background,
                        automaticallyImplyLeading: false,
                        titleSpacing: 16,
                        title: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: (value) =>
                              setState(() => _search = value.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search tasks',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Close search',
                              onPressed: () {
                                _searchController.clear();
                                _searchFocus.unfocus();
                                setState(() {
                                  _search = '';
                                  _searchOpen = false;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                              borderSide: BorderSide(
                                color: AppColors.indigo,
                                width: 1.5,
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: AppColors.background,
                        automaticallyImplyLeading: false,
                        titleSpacing: 16,
                        title: Text(
                          '${_greeting()} · '
                          '${dueTodayCount == 0 ? (overdueCount > 0 ? '$overdueCount overdue' : 'Welcome back') : '$dueTodayCount due today'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  setState(() => _searchOpen = true);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _searchFocus.requestFocus();
                                  });
                                },
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.indigo,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (open.isNotEmpty || completed.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            children: [
                              _summaryCard(
                                done: completed.length,
                                total: all.length,
                                dueToday: dueTodayCount,
                                overdue: overdueCount,
                                dueTomorrow: tomorrow.length,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 42,
                                child: Stack(
                                  children: [
                                    ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding:
                                          const EdgeInsets.only(right: 28),
                                      children: [
                                        FilterChipPill(
                                          label: 'All',
                                          selected: _filterCategoryId == null,
                                          count: open.length,
                                          onTap: () => setState(
                                            () => _filterCategoryId = null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ..._categoryCache.map(
                                          (c) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: FilterChipPill(
                                              label: '${c.emoji} ${c.name}',
                                              color: AppColors.categoryColor(
                                                c.colorIndex,
                                              ),
                                              selected:
                                                  _filterCategoryId == c.id,
                                              count: _countForCategory(
                                                open,
                                                c.id,
                                              ),
                                              onTap: () => setState(
                                                () =>
                                                    _filterCategoryId = c.id,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 28,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.background
                                                    .withValues(alpha: 0),
                                                AppColors.background,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (filtered.isEmpty && open.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyState(),
                      )
                    else if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No open tasks in this category',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            ..._section('Overdue', overdue, highlight: true),
                            ..._section('Today', today, showSort: true),
                            ..._section('Tomorrow', tomorrow),
                            ..._section('Later', later),
                            if (completed.isNotEmpty &&
                                _filterCategoryId == null)
                              Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  collapsedBackgroundColor: Colors.transparent,
                                  backgroundColor: Colors.transparent,
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  iconColor: AppColors.muted,
                                  collapsedIconColor: AppColors.muted,
                                  title: Text(
                                    'COMPLETED (${completed.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  children: [
                                    for (var i = 0;
                                        i < completed.take(8).length;
                                        i++)
                                      _taskCard(
                                        completed[i],
                                        completed: true,
                                        index: i,
                                      ),
                                  ],
                                ),
                              ),
                            if (open.isNotEmpty &&
                                today.isEmpty &&
                                overdue.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Text(
                                  tomorrow.isNotEmpty
                                      ? 'All caught up for today — ${tomorrow.length} due tomorrow'
                                      : 'Nice work — keep going!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          bottomNavigationBar: _bottomBar(),
        );
      },
    );
  }

  Widget _summaryCard({
    required int done,
    required int total,
    required int dueToday,
    required int overdue,
    required int dueTomorrow,
  }) {
    final value = total == 0 ? 0.0 : done / total;
    final percent = (value * 100).round();
    final subtitle = <String>[
      if (overdue > 0) '$overdue overdue',
      if (dueToday > 0) '$dueToday due today',
      if (dueTomorrow > 0) '$dueTomorrow due tomorrow',
      if (overdue == 0 && dueToday == 0 && dueTomorrow == 0)
        'Nothing due soon',
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: animated,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFE0E7FF),
                      color: AppColors.indigo,
                    ),
                    Center(
                      child: Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$done of $total tasks completed',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: overdue > 0 ? AppColors.high : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    String title,
    List<Task> tasks, {
    bool highlight = false,
    bool showSort = false,
  }) {
    if (tasks.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: highlight ? AppColors.high : AppColors.muted,
              ),
            ),
            const Spacer(),
            if (showSort)
              PopupMenuButton<String>(
                tooltip: 'Sort',
                padding: EdgeInsets.zero,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'due', child: Text('Due date')),
                  PopupMenuItem(value: 'priority', child: Text('Priority')),
                  PopupMenuItem(value: 'created', child: Text('Created')),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 18, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      for (var i = 0; i < tasks.length; i++)
        _taskCard(tasks[i], index: i),
      const SizedBox(height: 4),
    ];
  }

  Widget _taskCard(Task task, {bool completed = false, int index = 0}) {
    final priority = PriorityEscalation.effective(
      current: task.priority,
      dueDate: task.dueDate,
      completed: completed,
    );
    final completing = _completing.contains(task.id);
    final title = _displayTitle(
      task.title.isEmpty ? task.rawText : task.title,
    );
    final dueColor = _dueColor(task.dueDate, completed);
    final categoryColor = task.categoryName == null
        ? AppColors.muted
        : AppColors.categoryDot(task.categoryName!);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + (index * 40).clamp(0, 240)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Dismissible(
          key: ValueKey('${task.id}-$completed'),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: AppColors.low,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.high,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              if (!completed) await _completeTask(task);
              return false;
            }
            await _deleteWithUndo(task);
            return true;
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: completing ? 0.55 : 1,
            child: GestureDetector(
              onLongPress: () => _showTaskMenu(task),
              child: PressableScale(
                onTap: () => showEditTaskSheet(
                  context: context,
                  task: task,
                  categories: _categoryCache,
                  onSave: ({
                    required title,
                    required priority,
                    dueDate,
                    categoryId,
                    categoryName,
                  }) {
                    return _repository.updateTask(
                      uid: widget.uid,
                      taskId: task.id,
                      title: title,
                      priority: priority,
                      dueDate: dueDate,
                      categoryId: categoryId,
                      categoryName: categoryName,
                    );
                  },
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 16, 0, 16),
                          child: Container(
                            width: 4,
                            constraints: const BoxConstraints(minHeight: 28),
                            decoration: BoxDecoration(
                              color: completed
                                  ? AppColors.priority(priority)
                                      .withValues(alpha: 0.35)
                                  : AppColors.priority(priority),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              task.dueDate == null &&
                                      task.categoryName == null
                                  ? 16
                                  : 14,
                              16,
                              task.dueDate == null &&
                                      task.categoryName == null
                                  ? 16
                                  : 14,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Checkbox(
                                    value: completed || completing,
                                    side: const BorderSide(
                                      color: Color(0xFF9CA3AF),
                                      width: 1.8,
                                    ),
                                    onChanged: completed
                                        ? null
                                        : (value) {
                                            if (value == true) {
                                              _completeTask(task);
                                            }
                                          },
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          decoration: completed || completing
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: completed
                                              ? AppColors.muted
                                              : AppColors.text,
                                        ),
                                      ),
                                      if (task.dueDate != null ||
                                          task.categoryName != null ||
                                          task.status ==
                                              TaskStatus
                                                  .pendingEnrichment) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (task.dueDate != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 14,
                                                    color: dueColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _dueLabel(task.dueDate!),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: dueColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (task.categoryName != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: categoryColor
                                                      .withValues(
                                                    alpha: completed
                                                        ? 0.08
                                                        : 0.14,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    AppRadii.pill,
                                                  ),
                                                ),
                                                child: Text(
                                                  task.categoryName!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: completed
                                                        ? categoryColor
                                                            .withValues(
                                                            alpha: 0.7,
                                                          )
                                                        : categoryColor,
                                                  ),
                                                ),
                                              ),
                                            if (task.status ==
                                                TaskStatus.pendingEnrichment)
                                              Text(
                                                'Classifying…',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
      children: List.generate(
        5,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Center(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),
        ),
      ),
    );
  }

  Color _dueColor(DateTime? due, bool completed) {
    if (completed || due == null) return AppColors.muted;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    if (due.isBefore(start)) return AppColors.high;
    if (due.isBefore(end)) return AppColors.medium;
    // Future dates: neutral, not link-like indigo.
    return AppColors.muted;
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
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
              Icons.check_circle_outline_rounded,
              size: 40,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "You're all caught up",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Add or the mic to create a task',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Text(
            'Try: “Buy milk tomorrow, high priority, groceries”',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.indigo,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _openTypeSheet(),
            child: const Text('Add your first task'),
          ),
          TextButton.icon(
            onPressed: _openVoiceSheet,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Speak a task'),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return MiaBottomBar(
      homeSelected: true,
      tip: _showMicTip
          ? RaisedCenterNavTip(
              label: 'Tap and say a task',
              onDismiss: _dismissMicTip,
            )
          : null,
      onHome: () => Navigator.of(context).maybePop(),
      onMic: _openVoiceSheet,
      onAdd: () => _openTypeSheet(),
    );
  }

  Widget _buildDrawer(List<Task> openTasks) {
    final email = widget.auth.currentUser?.email ?? 'guest@mia.app';
    final name = email.split('@').first;
    final initial = name.isEmpty ? 'M' : name.characters.first.toUpperCase();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.indigo, AppColors.indigoSoft],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mia',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _drawerItem(
                    icon: Icons.list_alt_rounded,
                    label: 'All tasks',
                    badge: '${openTasks.length}',
                    selected: _filterCategoryId == null,
                    onTap: () {
                      setState(() => _filterCategoryId = null);
                      Navigator.pop(context);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.category_outlined,
                    label: 'Categories',
                    onTap: () async {
                      Navigator.pop(context);
                      final id = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => CategoriesScreen(uid: widget.uid),
                        ),
                      );
                      if (id != null && mounted) {
                        setState(() => _filterCategoryId = id);
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      'CATEGORIES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  ..._categoryCache.map(
                    (c) => _drawerItem(
                      icon: Icons.circle,
                      iconSize: 10,
                      iconColor: AppColors.categoryColor(c.colorIndex),
                      label: '${c.emoji} ${c.name}',
                      badge: '${_countForCategory(openTasks, c.id)}',
                      selected: _filterCategoryId == c.id,
                      onTap: () {
                        setState(() => _filterCategoryId = c.id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              subtitle: const Text('Theme, Mia preferences'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(auth: widget.auth),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded),
              title: const Text('Back to home'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).maybePop();
              },
            ),
            if (!AppConfig.skipSignIn)
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  widget.auth.signOut();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Color? iconColor,
    double iconSize = 22,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: AppColors.tint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        leading: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? (selected ? AppColors.indigo : AppColors.muted),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.indigo : AppColors.text,
          ),
        ),
        trailing: badge == null
            ? null
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? AppColors.indigo : AppColors.tint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.indigo,
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
