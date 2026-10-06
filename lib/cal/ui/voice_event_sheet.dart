import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/cloud_speech_service.dart';
import '../../core/voice/listening_sheet.dart';
import '../data/cal_repository.dart';
import '../models/cal_event_source.dart';
import '../services/voice_event_parser.dart';

enum _Phase { listening, processing, confirm }

Future<bool> showVoiceEventSheet({
  required BuildContext context,
  required String uid,
  CloudSpeechService? speech,
  CalRepository? repository,
}) async {
  if (!AppConfig.canTranscribe) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add ASSEMBLYAI_API_KEY to .env to use voice events'),
      ),
    );
    return false;
  }

  final result = await showModalBottomSheet<bool>(
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
        child: _VoiceEventSheet(
          uid: uid,
          speech: speech ?? CloudSpeechService(),
          repository: repository ?? CalRepository(),
        ),
      );
    },
  );
  return result == true;
}

class _VoiceEventSheet extends StatefulWidget {
  const _VoiceEventSheet({
    required this.uid,
    required this.speech,
    required this.repository,
  });

  final String uid;
  final CloudSpeechService speech;
  final CalRepository repository;

  @override
  State<_VoiceEventSheet> createState() => _VoiceEventSheetState();
}

class _VoiceEventSheetState extends State<_VoiceEventSheet>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.listening;
  late final AnimationController _pulse;
  final _title = TextEditingController();
  final _location = TextEditingController();
  VoiceEventDraft? _draft;
  DateTime? _start;
  DateTime? _end;
  bool _allDay = false;
  bool _saving = false;
  String? _error;

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
    if (_phase == _Phase.listening) {
      widget.speech.cancel();
    }
    _pulse.dispose();
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _phase = _Phase.listening;
      _error = null;
      _draft = null;
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
      _phase = _Phase.processing;
      _error = null;
    });
    _pulse.stop();
    HapticFeedback.mediumImpact();
    try {
      final transcript = await widget.speech.stopAndTranscribe();
      if (!mounted) return;
      if (transcript == null || transcript.trim().isEmpty) {
        setState(() {
          _phase = _Phase.listening;
          _error = "I didn't catch that. Try again.";
        });
        _pulse.repeat(reverse: true);
        await widget.speech.startRecording();
        return;
      }

      final draft = await VoiceEventParser.parse(transcript);
      if (!mounted) return;
      _draft = draft;
      _title.text = draft.title;
      _location.text = draft.location ?? '';
      _start = draft.start;
      _end = draft.end;
      _allDay = draft.allDay;
      setState(() => _phase = _Phase.confirm);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.listening;
        _error = '$e';
      });
      _pulse.repeat(reverse: true);
      try {
        await widget.speech.startRecording();
      } catch (_) {}
    }
  }

  Future<void> _pickWhen({required bool isStart}) async {
    final initial = isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
        if (_end == null || !_end!.isAfter(next)) {
          _end = next.add(const Duration(hours: 1));
        }
      } else {
        _end = next;
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final start = _start;
    final end = _end;
    if (title.isEmpty || start == null || end == null) {
      setState(() => _error = 'Add a title and time');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createEvent(
        uid: widget.uid,
        title: title,
        start: start,
        end: end,
        allDay: _allDay,
        location: _location.text,
        description: _draft?.transcript,
        source: CalEventSource.manual,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.month}/${d.day} $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: switch (_phase) {
            _Phase.listening => ListeningSheet(
                pulse: _pulse,
                title: 'Listening for an event…',
                hint: 'Try “Meeting with Zach tomorrow at 2”',
                error: _error,
                onStop: _stopAndProcess,
                onCancel: () => Navigator.pop(context, false),
                onOpenSettings: () => openAppSettings(),
              ),
            _Phase.processing => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Turning that into an event…'),
                  ],
                ),
              ),
            _Phase.confirm => _confirm(),
          },
        ),
      ),
    );
  }

  Widget _confirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Confirm event',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        if (_draft?.transcript.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            'Heard: “${_draft!.transcript}”',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
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
          subtitle: Text(_start == null ? '—' : _fmt(_start!)),
          trailing: const Icon(Icons.schedule_rounded),
          onTap: () => _pickWhen(isStart: true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ends'),
          subtitle: Text(_end == null ? '—' : _fmt(_end!)),
          trailing: const Icon(Icons.schedule_rounded),
          onTap: () => _pickWhen(isStart: false),
        ),
        TextField(
          controller: _location,
          decoration: const InputDecoration(
            labelText: 'Location / link',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.high)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await _startListening();
                      try {
                        await widget.speech.startRecording();
                      } catch (_) {}
                    },
              child: const Text('Re-record'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save event'),
            ),
          ],
        ),
      ],
    );
  }
}
