import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable listening UI shell: pulsing mic orb, stop, cancel, and errors.
/// Domain-specific hint text and processing/confirm flows stay in the caller.
class ListeningSheet extends StatelessWidget {
  const ListeningSheet({
    super.key,
    required this.pulse,
    required this.onStop,
    required this.onCancel,
    this.title = 'Listening…',
    this.hint,
    this.error,
    this.onOpenSettings,
  });

  final AnimationController pulse;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final String title;
  final String? hint;
  final String? error;
  final Future<bool> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final needsSettings =
        onOpenSettings != null && (error ?? '').contains('Settings');
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final scale = 1 + (pulse.value * 0.08);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.indigo,
                      AppColors.indigoSoft.withValues(alpha: 0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo.withValues(
                        alpha: 0.25 + pulse.value * 0.2,
                      ),
                      blurRadius: 24 + pulse.value * 12,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _WavePainter(pulse.value),
                  child: const Center(
                    child:
                        Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),
            );
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 20),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.high),
          ),
          if (needsSettings)
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: 72,
          height: 72,
          child: FilledButton(
            onPressed: onStop,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.stop_rounded, size: 32),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final radius = 28 + i * 10 + math.sin((t + i) * math.pi) * 4;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.t != t;
}
