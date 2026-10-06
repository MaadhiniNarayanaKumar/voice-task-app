import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/app_components.dart';
import '../../mia/widgets/mia_bottom_bar.dart';
import '../data/cal_repository.dart';
import '../models/cal_event.dart';
import '../models/cal_event_source.dart';
import 'add_cal_event_sheet.dart';
import 'cal_style.dart';
import 'event_detail_sheet.dart';
import 'voice_event_sheet.dart';

enum _CalView { agenda, day, week, month }

enum _CalFilter { all, work, personal, extension }

/// Calendar home — week strip, agenda, filters, indigo actions.
class CalHomeScreen extends StatefulWidget {
  const CalHomeScreen({super.key, required this.uid});

  final String uid;

  @override
  State<CalHomeScreen> createState() => _CalHomeScreenState();
}

class _CalHomeScreenState extends State<CalHomeScreen> {
  final _repo = CalRepository();
  final _listKey = GlobalKey();
  final Map<DateTime, GlobalKey> _dayKeys = {};

  _CalView _view = _CalView.agenda;
  _CalFilter _filter = _CalFilter.all;
  late DateTime _focusedDay;
  DateTime? _lastSynced;
  String _syncLabel = 'Pull to refresh';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<DateTime> get _weekDays {
    final start = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  Future<void> _addEvent() async {
    await AddCalEventSheet.show(context, uid: widget.uid);
  }

  Future<void> _voiceEvent() async {
    await showVoiceEventSheet(context: context, uid: widget.uid);
  }

  Future<void> _editEvent(CalEvent event) async {
    await AddCalEventSheet.show(context, uid: widget.uid, existing: event);
  }

  Future<void> _confirmDelete(CalEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteEvent(uid: widget.uid, id: event.id);
  }

  Future<void> _duplicate(CalEvent event) async {
    await _repo.createEvent(
      uid: widget.uid,
      title: '${event.title} (copy)',
      start: event.start.add(const Duration(days: 1)),
      end: event.end.add(const Duration(days: 1)),
      allDay: event.allDay,
      location: event.location,
      description: event.description,
      source: CalEventSource.manual,
      calendarId: event.calendarId,
      color: event.color,
    );
  }

  List<CalEvent> _cleanAndFilter(List<CalEvent> raw) {
    return raw.where((e) {
      if (CalStyle.isJunkTitle(e.title)) return false;
      switch (_filter) {
        case _CalFilter.all:
          return true;
        case _CalFilter.work:
          return e.calendarId == 'work';
        case _CalFilter.personal:
          return e.calendarId == 'manual' ||
              e.source == CalEventSource.manual;
        case _CalFilter.extension:
          return e.source == CalEventSource.extension ||
              e.calendarId == 'extension';
      }
    }).toList();
  }

  Map<DateTime, List<CalEvent>> _byDay(List<CalEvent> events) {
    final map = <DateTime, List<CalEvent>>{};
    for (final e in events) {
      final key = DateTime(e.start.year, e.start.month, e.start.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return map;
  }

  List<DateTime> _agendaDays(Map<DateTime, List<CalEvent>> byDay) {
    final today = _today;
    final keys = byDay.keys.toList()..sort();
    final out = <DateTime>[];
    // Always include today so empty-day message can show.
    if (!keys.contains(today)) out.add(today);
    for (final k in keys) {
      if (k.isBefore(today)) continue;
      if (!out.contains(k)) out.add(k);
    }
    // Include the focused day when tapped from the week strip.
    if (!_focusedDay.isBefore(today) && !out.contains(_focusedDay)) {
      out.add(_focusedDay);
    }
    out.sort();
    return out;
  }

  void _jumpToday() {
    setState(() => _focusedDay = _today);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dayKeys[_today];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _syncLabel = 'Syncing…');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _lastSynced = DateTime.now();
      _syncLabel = 'Synced just now';
    });
  }

  String get _monthTitle {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[_focusedDay.month - 1]} ${_focusedDay.year}';
  }

  CalEvent? _nextUp(List<CalEvent> events) {
    final now = DateTime.now();
    final upcoming = events.where((e) => e.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String? _freeAfterSummary(List<CalEvent> events) {
    final todayEvents = events
        .where((e) {
          final d = DateTime(e.start.year, e.start.month, e.start.day);
          return d == _today;
        })
        .toList()
      ..sort((a, b) => a.end.compareTo(b.end));
    if (todayEvents.isEmpty) return 'Free the rest of today';
    final last = todayEvents.last;
    if (last.end.isBefore(DateTime.now())) return 'Free the rest of today';
    return 'Free after ${CalStyle.fmtTime(last.end)} today';
  }

  List<DateTime> _visibleDays(Map<DateTime, List<CalEvent>> byDay) {
    switch (_view) {
      case _CalView.day:
        return [_focusedDay];
      case _CalView.week:
        return _weekDays;
      case _CalView.month:
        return _agendaDays(byDay);
      case _CalView.agenda:
        return _agendaDays(byDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(_monthTitle),
        actions: [
          TextButton(
            onPressed: _jumpToday,
            child: Text(
              'Today',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.indigo,
              ),
            ),
          ),
          IconButton(
            tooltip: _syncLabel,
            onPressed: _refresh,
            icon: Icon(Icons.sync_rounded, color: AppColors.indigo),
          ),
        ],
      ),
      bottomNavigationBar: MiaBottomBar(
        homeSelected: true,
        onHome: () => Navigator.of(context).maybePop(),
        onMic: _voiceEvent,
        onAdd: _addEvent,
      ),
      body: StreamBuilder<List<CalEvent>>(
        stream: _repo.watchAgenda(widget.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Couldn’t load events.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }

          final loading = !snap.hasData;
          final events = _cleanAndFilter(snap.data ?? const []);
          final byDay = _byDay(events);
          final weekHas = {
            for (final d in _weekDays) d: byDay[d]?.isNotEmpty == true,
          };
          final days = _visibleDays(byDay);

          return RefreshIndicator(
            color: AppColors.indigo,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _weekStrip(weekHas)),
                SliverToBoxAdapter(child: _viewSwitcher()),
                SliverToBoxAdapter(child: _filterChips()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _lastSynced == null ? _syncLabel : 'Synced just now',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ),
                if (loading)
                  SliverToBoxAdapter(child: _skeletons())
                else if (_view == _CalView.month)
                  SliverToBoxAdapter(child: _monthGrid(byDay))
                else
                  ..._agendaSlivers(days, byDay, events),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _agendaSlivers(
    List<DateTime> days,
    Map<DateTime, List<CalEvent>> byDay,
    List<CalEvent> events,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverList(
          key: _listKey,
          delegate: SliverChildListDelegate([
            for (final day in days)
              _daySection(day, byDay[day] ?? const [], events),
            const SizedBox(height: 8),
            _nextUpCard(events),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ];
  }

  Widget _monthGrid(Map<DateTime, List<CalEvent>> byDay) {
    final first = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final startOffset = first.weekday % 7;
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final cells = startOffset + daysInMonth;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              for (final l in ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'])
                Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(child: _monthCell(r * 7 + c, startOffset, daysInMonth, byDay)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthCell(
    int index,
    int startOffset,
    int daysInMonth,
    Map<DateTime, List<CalEvent>> byDay,
  ) {
    final dayNum = index - startOffset + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 44);
    }
    final day = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
    final has = byDay[day]?.isNotEmpty == true;
    final selected = day == _focusedDay;
    final isToday = day == _today;
    return InkWell(
      onTap: () => setState(() {
        _focusedDay = day;
        _view = _CalView.day;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !selected
              ? Border.all(color: AppColors.indigo, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: has
                    ? (selected ? Colors.white : AppColors.indigo)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekStrip(Map<DateTime, bool> hasEvents) {
    const labels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _WeekDayCell(
                label: labels[i],
                day: _weekDays[i],
                selected: _weekDays[i] == _focusedDay,
                isToday: _weekDays[i] == _today,
                hasEvents: hasEvents[_weekDays[i]] == true,
                onTap: () {
                  setState(() {
                    _focusedDay = _weekDays[i];
                    if (_view == _CalView.month) _view = _CalView.day;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final key = _dayKeys[_weekDays[i]];
                    final ctx = key?.currentContext;
                    if (ctx != null) {
                      Scrollable.ensureVisible(
                        ctx,
                        duration: const Duration(milliseconds: 280),
                        alignment: 0.08,
                      );
                    }
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _viewSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            for (final v in _CalView.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _view = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _view == v ? AppColors.indigo : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      v.name[0].toUpperCase() + v.name.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _view == v ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    Color chipColor(_CalFilter f) => switch (f) {
          _CalFilter.all => AppColors.indigo,
          _CalFilter.work => const Color(0xFF2563EB),
          _CalFilter.personal => const Color(0xFF16A34A),
          _CalFilter.extension => const Color(0xFF7C3AED),
        };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          for (final f in _CalFilter.values) ...[
            FilterChipPill(
              label: switch (f) {
                _CalFilter.all => 'All',
                _CalFilter.work => 'Work',
                _CalFilter.personal => 'Personal',
                _CalFilter.extension => 'Extension',
              },
              selected: _filter == f,
              color: chipColor(f),
              showDot: f != _CalFilter.all,
              onTap: () => setState(() => _filter = f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _daySection(
    DateTime day,
    List<CalEvent> dayEvents,
    List<CalEvent> all,
  ) {
    _dayKeys.putIfAbsent(day, GlobalKey.new);
    final isToday = day == _today;
    final now = DateTime.now();

    return KeyedSubtree(
      key: _dayKeys[day],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DayHeader(day: day, isToday: isToday),
          if (dayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: CalStyle.flatCard(
                  borderColor: const Color(0xFFE5E7EB),
                ),
                child: Text(
                  isToday
                      ? 'Nothing today · ${_nextUp(all) != null ? 'Next: ${_nextUp(all)!.title}' : 'You’re free'}'
                      : 'Nothing scheduled',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            )
          else ...[
            for (var i = 0; i < dayEvents.length; i++) ...[
              if (isToday && _shouldShowNowBefore(dayEvents, i, now))
                _NowChip(),
              _EventCard(
                event: dayEvents[i],
                dimmed: isToday && dayEvents[i].end.isBefore(now),
                onTap: () => showCalEventDetailSheet(
                  context: context,
                  event: dayEvents[i],
                  onDelete: () => _confirmDelete(dayEvents[i]),
                  onDuplicate: () => _duplicate(dayEvents[i]),
                  onEdit: () => _editEvent(dayEvents[i]),
                ),
                onDelete: () => _confirmDelete(dayEvents[i]),
                onDuplicate: () => _duplicate(dayEvents[i]),
                onEdit: () => _editEvent(dayEvents[i]),
              ),
            ],
            if (isToday &&
                dayEvents.isNotEmpty &&
                dayEvents.every((e) => !e.start.isAfter(now)))
              _NowChip(),
          ],
        ],
      ),
    );
  }

  bool _shouldShowNowBefore(List<CalEvent> dayEvents, int index, DateTime now) {
    final event = dayEvents[index];
    if (!event.start.isAfter(now)) return false;
    if (index == 0) return dayEvents.any((e) => !e.start.isAfter(now));
    final prev = dayEvents[index - 1];
    return !prev.start.isAfter(now);
  }

  Widget _nextUpCard(List<CalEvent> events) {
    final next = _nextUp(events);
    final free = _freeAfterSummary(events);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: next == null
            ? null
            : () => showCalEventDetailSheet(
                  context: context,
                  event: next,
                  onDelete: () => _confirmDelete(next),
                  onDuplicate: () => _duplicate(next),
                  onEdit: () => _editEvent(next),
                ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: CalStyle.flatCard(borderColor: const Color(0xFFE5E7EB)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next up',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next == null ? 'No upcoming events' : next.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 4),
                Text(
                  CalStyle.fmtDayDate(next.start),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CalStyle.fmtDuration(next.start, next.end, allDay: next.allDay),
                  style: TextStyle(
                    color: AppColors.indigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (free != null) ...[
                const SizedBox(height: 8),
                Text(free, style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            height: 78,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.label,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasEvents,
    required this.onTap,
  });

  final String label;
  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool hasEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.indigo : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !selected
                    ? Border.all(color: AppColors.indigo, width: 1.5)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: hasEvents ? AppColors.indigo : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
              color: isToday ? AppColors.indigo : AppColors.text,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              weekdays[day.weekday - 1],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isToday ? AppColors.indigo : AppColors.muted,
              ),
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.indigo,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NowChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.indigo,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.indigo.withValues(alpha: 0.35),
            ),
          ),
          Text(
            'Now',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onEdit,
    this.dimmed = false,
  });

  final CalEvent event;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final Future<void> Function() onDuplicate;
  final Future<void> Function() onEdit;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final bar = CalStyle.barColor(event);
    final video = CalStyle.isVideoLink(event.location);
    final soon = !event.allDay &&
        event.start.difference(DateTime.now()).inMinutes <= 15 &&
        event.start.isAfter(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(event.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.softRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline_rounded, color: AppColors.high),
        ),
        confirmDismiss: (_) async {
          await onDelete();
          return false;
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: () async {
              HapticFeedback.mediumImpact();
              final action = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
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
                        onTap: () => Navigator.pop(context, 'dup'),
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline, color: AppColors.high),
                        title: Text('Delete', style: TextStyle(color: AppColors.high)),
                        onTap: () => Navigator.pop(context, 'del'),
                      ),
                    ],
                  ),
                ),
              );
              if (action == 'edit') await onEdit();
              if (action == 'dup') await onDuplicate();
              if (action == 'del') await onDelete();
            },
            child: Opacity(
              opacity: dimmed ? 0.45 : 1,
              child: Container(
                decoration: CalStyle.flatCard(
                  borderColor: const Color(0xFFE5E7EB),
                ),
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 64,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.allDay
                                      ? 'All day'
                                      : CalStyle.fmtDuration(
                                          event.start,
                                          event.end,
                                        ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.indigo,
                                  ),
                                ),
                              ),
                              Icon(
                                CalStyle.sourceIcon(event.source),
                                size: 14,
                                color: bar.withValues(alpha: 0.85),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                              height: 1.25,
                            ),
                          ),
                          if (event.location != null &&
                              event.location!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  video
                                      ? Icons.videocam_rounded
                                      : Icons.place_outlined,
                                  size: 14,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                if (video && soon)
                                  TextButton(
                                    onPressed: () async {
                                      final uri = Uri.tryParse(event.location!);
                                      if (uri != null) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.indigo,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(40, 28),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Join',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
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
          ),
        ),
      ),
    );
  }
}
