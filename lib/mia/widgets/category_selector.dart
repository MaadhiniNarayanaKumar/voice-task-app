import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/app_components.dart';
import '../models/category.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onChanged,
    this.allowNone = true,
  });

  final List<TaskCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (allowNone)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChipPill(
                    label: 'Auto',
                    selected: selectedId == null,
                    onTap: () => onChanged(null),
                  ),
                ),
              ...categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChipPill(
                    label: '${category.emoji} ${category.name}',
                    color: AppColors.categoryDot(category.name),
                    selected: selectedId == category.id,
                    onTap: () => onChanged(category.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
