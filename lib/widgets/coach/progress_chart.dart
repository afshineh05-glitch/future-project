import 'package:flutter/material.dart';
import 'package:future_project/theme/app_theme.dart';

class CoachProgressChart extends StatelessWidget {
  const CoachProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Momentum',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                'Last 30 days',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _MomentumChartPainter(),
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentumChartPainter extends CustomPainter {
  const _MomentumChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final points = <Offset>[
      Offset(0, size.height * 0.78),
      Offset(size.width * 0.14, size.height * 0.66),
      Offset(size.width * 0.28, size.height * 0.69),
      Offset(size.width * 0.42, size.height * 0.50),
      Offset(size.width * 0.56, size.height * 0.58),
      Offset(size.width * 0.70, size.height * 0.38),
      Offset(size.width * 0.84, size.height * 0.43),
      Offset(size.width, size.height * 0.22),
    ];

    final linePaint = Paint()
      ..color = AppTheme.primaryGreen
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      points.last,
      6,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}