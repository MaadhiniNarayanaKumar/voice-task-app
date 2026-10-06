import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill-shaped bottom bar with a raised mic and a cradled notch.
class RaisedCenterNavBar extends StatelessWidget {
  const RaisedCenterNavBar({
    super.key,
    required this.left,
    required this.right,
    required this.onCenterTap,
    this.centerIcon = Icons.mic_rounded,
    this.centerTooltip,
    this.tip,
  });

  final Widget left;
  final Widget right;
  final VoidCallback onCenterTap;
  final IconData centerIcon;
  final String? centerTooltip;
  final Widget? tip;

  static const _barHeight = 58.0;
  static const _micSize = 56.0;
  static const _notchRadius = 34.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tip != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: tip!,
            ),
          SizedBox(
            height: _barHeight + 28,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barHeight,
                  child: CustomPaint(
                    painter: _NotchedBarPainter(
                      color: AppColors.card,
                      shadowColor:
                          const Color(0xFF111827).withValues(alpha: 0.08),
                      notchRadius: _notchRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          left,
                          const Spacer(),
                          SizedBox(width: _notchRadius * 2),
                          const Spacer(),
                          right,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: _barHeight - 18,
                  child: Tooltip(
                    message: centerTooltip ?? '',
                    child: GestureDetector(
                      onTap: onCenterTap,
                      child: Container(
                        width: _micSize,
                        height: _micSize,
                        decoration: BoxDecoration(
                          color: AppColors.indigo,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.indigo.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(centerIcon, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  _NotchedBarPainter({
    required this.color,
    required this.shadowColor,
    required this.notchRadius,
  });

  final Color color;
  final Color shadowColor;
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    final bar = Path()..addRRect(rrect);
    final notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, 0),
          radius: notchRadius,
        ),
      );
    final shape = Path.combine(PathOperation.difference, bar, notch);

    canvas.drawShadow(shape, shadowColor, 10, false);
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.notchRadius != notchRadius;
  }
}

/// Small dismissible tip chip used above [RaisedCenterNavBar].
class RaisedCenterNavTip extends StatelessWidget {
  const RaisedCenterNavTip({
    super.key,
    required this.label,
    required this.onDismiss,
  });

  final String label;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.indigo,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
