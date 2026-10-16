import 'package:flutter/material.dart';

import '../../core/nav/raised_center_nav_bar.dart';
import '../../core/theme/app_theme.dart';

/// Shared Mia chrome: Home · Mic · Add on every Mia page.
class MiaBottomBar extends StatelessWidget {
  const MiaBottomBar({
    super.key,
    required this.onHome,
    required this.onMic,
    required this.onAdd,
    this.tip,
  });

  final VoidCallback onHome;
  final VoidCallback onMic;
  final VoidCallback onAdd;
  final Widget? tip;

  @override
  Widget build(BuildContext context) {
    return RaisedCenterNavBar(
      tip: tip,
      left: _item(
        icon: Icons.home_outlined,
        label: 'Home',
        onTap: onHome,
      ),
      right: _item(
        icon: Icons.add_rounded,
        label: 'Add',
        onTap: onAdd,
      ),
      onCenterTap: onMic,
      centerTooltip: 'Voice',
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
