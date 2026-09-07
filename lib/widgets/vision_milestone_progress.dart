import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:future_project/models/vision_milestones.dart';

class VisionMilestoneProgressRing extends StatelessWidget {
  final double progress;
  final VisionMilestoneStatus status;
  final IconData icon;
  final Color accent;
  final double size;

  const VisionMilestoneProgressRing({
    super.key,
    required this.progress,
    required this.status,
    required this.icon,
    required this.accent,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final locked = status == VisionMilestoneStatus.locked;
    final completed = status == VisionMilestoneStatus.completed;
    final activeColor = locked ? const Color(0xFF71857E) : accent;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: activeColor.withValues(alpha: .22),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress.clamp(0, 1),
            trackColor: locked
                ? const Color(0x4D9BAAA5)
                : const Color(0x334FE0A0),
            progressColor: activeColor,
          ),
          child: Center(
            child: Icon(
              completed
                  ? Icons.check_rounded
                  : locked
                  ? Icons.lock_outline_rounded
                  : icon,
              color: locked ? const Color(0xFFA7B5B0) : Colors.white,
              size: size * .37,
            ),
          ),
        ),
      ),
    );
  }
}

class VisionMilestoneProgressBar extends StatelessWidget {
  final double progress;
  final VisionMilestoneStatus status;
  final Color accent;

  const VisionMilestoneProgressBar({
    super.key,
    required this.progress,
    required this.status,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final locked = status == VisionMilestoneStatus.locked;
    final fill = locked ? const Color(0xFF71857E) : accent;
    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * progress.clamp(0, 1);
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: locked
                        ? const Color(0x335F756D)
                        : Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (width > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: locked
                          ? null
                          : [
                              BoxShadow(
                                color: fill.withValues(alpha: .35),
                                blurRadius: 7,
                              ),
                            ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(3.0, size.width * .085);
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final active = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);
    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        active,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
