import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../models/cal_event.dart';
import '../models/cal_event_source.dart';
import 'cal_style.dart';

Future<void> showCalEventDetailSheet({
  required BuildContext context,
  required CalEvent event,
  required Future<void> Function() onDelete,
  Future<void> Function()? onDuplicate,
  Future<void> Function()? onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (context) => _CalEventDetail(
      event: event,
      onDelete: onDelete,
      onDuplicate: onDuplicate,
      onEdit: onEdit,
    ),
  );
}

class _CalEventDetail extends StatelessWidget {
  const _CalEventDetail({
    required this.event,
    required this.onDelete,
    this.onDuplicate,
    this.onEdit,
  });

  final CalEvent event;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onDuplicate;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    final bar = CalStyle.barColor(event);
    final video = CalStyle.isVideoLink(event.location);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: bar, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  event.source.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              event.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              CalStyle.fmtDayDate(event.start),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CalStyle.fmtDuration(
                event.start,
                event.end,
                allDay: event.allDay,
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.indigo,
              ),
            ),
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    video ? Icons.videocam_rounded : Icons.place_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(color: AppColors.text, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
            if (event.description != null &&
                event.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                event.description!,
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
            const SizedBox(height: 18),
            if (video) ...[
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(event.location!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Join'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await onEdit!();
                    },
                    child: const Text('Edit'),
                  ),
                if (onDuplicate != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await onDuplicate!();
                    },
                    child: const Text('Duplicate'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onDelete();
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.high),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
