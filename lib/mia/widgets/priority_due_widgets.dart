import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/app_components.dart';

class PriorityColors {
  static Color of(String priority) => AppColors.priority(priority);
}

class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            for (final item in const [
              ('low', 'Low', Icons.flag_outlined),
              ('medium', 'Medium', Icons.flag_outlined),
              ('high', 'High', Icons.flag_rounded),
            ]) ...[
              Expanded(
                child: _PriorityChip(
                  label: item.$2,
                  icon: item.$3,
                  selected: value == item.$1,
                  color: PriorityColors.of(item.$1),
                  onTap: () => onChanged(item.$1),
                ),
              ),
              if (item.$1 != 'high') const SizedBox(width: AppSpace.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: BorderSide(
          color: selected ? color : const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 18, color: selected ? color : AppColors.muted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = PriorityColors.of(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DueDateCalendar extends StatelessWidget {
  const DueDateCalendar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;

  Future<void> _openCalendar(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select due date',
    );
    if (picked == null) return;
    onChanged(DateTime(picked.year, picked.month, picked.day, 9));
  }

  void _setDay(DateTime day) {
    onChanged(DateTime(day.year, day.month, day.day, 9));
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));
    final label = selected == null
        ? 'Pick a date'
        : '${selected!.month}/${selected!.day}/${selected!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Due date', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterChipPill(
                label: 'Today',
                selected: _isSameDay(selected, today),
                onTap: () => _setDay(today),
              ),
              const SizedBox(width: 8),
              FilterChipPill(
                label: 'Tomorrow',
                selected: _isSameDay(selected, tomorrow),
                onTap: () => _setDay(tomorrow),
              ),
              const SizedBox(width: 8),
              FilterChipPill(
                label: 'Next week',
                selected: _isSameDay(selected, nextWeek),
                onTap: () => _setDay(nextWeek),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton.icon(
          onPressed: () => _openCalendar(context),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                selected == null ? AppColors.indigo : AppColors.text,
            alignment: Alignment.centerLeft,
          ),
        ),
      ],
    );
  }
}
