import 'package:flutter/material.dart';

/// A single-series trend line of recent "form" (each run's score as a
/// fraction of that mode's personal best at the time — see
/// [StatsService.recentForm]). One series, one axis: no legend needed, the
/// caption names it. The most recent run is the only point emphasized with
/// a filled marker, per the "selective direct labels" rule — every point
/// labeled would be noise.
class ScoreTrendSparkline extends StatelessWidget {
  const ScoreTrendSparkline({
    super.key,
    required this.values,
    required this.accent,
  });

  /// Oldest first, each in 0.0-1.0.
  final List<double> values;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text(
        'Play a few runs to see your recent form here.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.white54),
      );
    }
    final latestPct = (values.last * 100).round();
    String trendLabel = '';
    if (values.length >= 2) {
      final delta = values.last - values[values.length - 2];
      if (delta > 0.02) {
        trendLabel = ' · trending up';
      } else if (delta < -0.02) {
        trendLabel = ' · trending down';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT FORM (LAST ${values.length} RUNS, VS. YOUR BEST)',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white54,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(values: values, accent: accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Last run: $latestPct% of best$trendLabel',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.accent});

  final List<double> values;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 6.0;
    final bottom = size.height;
    final top = topPadding;
    final usableHeight = bottom - top;

    Offset pointAt(int i) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = bottom - values[i].clamp(0.0, 1.0) * usableHeight;
      return Offset(x, y);
    }

    if (values.length == 1) {
      canvas.drawCircle(pointAt(0), 4, Paint()..color = accent);
      return;
    }

    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (int i = 1; i < values.length; i++) {
      final p = pointAt(i);
      linePath.lineTo(p.dx, p.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(pointAt(values.length - 1).dx, bottom)
      ..lineTo(pointAt(0).dx, bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.28), accent.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, usableHeight)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );

    // Emphasize only the most recent point (a direct label, not a mark on
    // every point) with a filled ring anchored to the line.
    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = accent);
    canvas.drawCircle(
      last,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF14161F),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.accent != accent;
}
