import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../data/cal_repository.dart';
import '../models/cal_event.dart';
import '../models/cal_event_source.dart';
import '../services/voice_event_parser.dart';

/// Add or edit a manual event. Paste invite text into Notes + Parse.
class AddCalEventSheet extends StatefulWidget {
  const AddCalEventSheet({
    super.key,
    required this.uid,
    this.repository,
    this.existing,
  });

  final String uid;
  final CalRepository? repository;
  final CalEvent? existing;

  static Future<bool> show(
    BuildContext context, {
    required String uid,
    CalEvent? existing,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AddCalEventSheet(uid: uid, existing: existing),
      ),
    );
    return result == true;
  }

  @override
  State<AddCalEventSheet> createState() => _AddCalEventSheetState();
}

class _AddCalEventSheetState extends State<AddCalEventSheet> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();

  late DateTime _start;
  late DateTime _end;
  bool _allDay = false;
  bool _saving = false;
  String? _error;

  late final CalRepository _repo;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CalRepository();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _location.text = existing.location ?? '';
      _notes.text = existing.description ?? '';
      _start = existing.start;
      _end = existing.end;
      _allDay = existing.allDay;
    } else {
      final now = DateTime.now();
      _start = DateTime(now.year, now.month, now.day, now.hour + 1);
      _end = _start.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _parsePaste() async {
    final draft = VoiceEventParser.parseInvitePaste(_notes.text);
    if (draft == null) {
      setState(() => _error = 'Paste a Google Calendar invite, then tap Parse');
      return;
    }
    setState(() {
      _error = null;
      _title.text = draft.title;
      _start = draft.start;
      _end = draft.end;
      _allDay = draft.allDay;
      if (draft.location != null) _location.text = draft.location!;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    TimeOfDay? time;
    if (!_allDay) {
      time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;
    }

    final next = DateTime(
      date.year,
      date.month,
      date.day,
      _allDay ? 0 : (time?.hour ?? initial.hour),
      _allDay ? 0 : (time?.minute ?? initial.minute),
    );

    setState(() {
      if (isStart) {
        _start = next;
        if (!_end.isAfter(_start)) {
          _end = _allDay
              ? DateTime(next.year, next.month, next.day, 23, 59)
              : next.add(const Duration(hours: 1));
        }
      } else {
        _end = next;
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var start = _start;
      var end = _end;
      if (_allDay) {
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(end.year, end.month, end.day, 23, 59);
      }
      final existing = widget.existing;
      if (existing != null) {
        await _repo.updateEvent(
          uid: widget.uid,
          event: CalEvent(
            id: existing.id,
            title: title,
            start: start,
            end: end,
            allDay: _allDay,
            location:
                _location.text.trim().isEmpty ? null : _location.text.trim(),
            calendarId: existing.calendarId,
            color: existing.color,
            recurring: existing.recurring,
            description:
                _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            source: existing.source,
            externalId: existing.externalId,
          ),
        );
      } else {
        await _repo.createEvent(
          uid: widget.uid,
          title: title,
          start: start,
          end: end,
          allDay: _allDay,
          location: _location.text,
          description: _notes.text,
          source: CalEventSource.manual,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  String _fmt(DateTime d) {
    if (_allDay) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Edit event' : 'Add event',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saved in Mia (Firestore). Use the Chrome extension to capture '
              'from any page. Paste invite text into Notes if you want.',
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _allDay,
              activeThumbColor: AppColors.indigo,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts'),
              subtitle: Text(_fmt(_start)),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ends'),
              subtitle: Text(_fmt(_end)),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: () => _pickDate(isStart: false),
            ),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Notes / paste invite',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText:
                    'Paste Google Calendar invite text, then tap Parse invite…',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _parsePaste,
                icon: const Icon(Icons.content_paste_search_rounded, size: 18),
                label: const Text('Parse invite'),
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: AppColors.high)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Save event'),
            ),
          ],
        ),
      ),
    );
  }
}
