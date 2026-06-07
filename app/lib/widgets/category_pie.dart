import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/insights.dart';
import '../theme.dart';

/// Dependency-free pie chart of trips by category (FR-11).
class CategoryPie extends StatelessWidget {
  final List<CategoryStat> stats;
  final double size;

  const CategoryPie({super.key, required this.stats, this.size = 180});

  @override
  Widget build(BuildContext context) {
    final total = stats.fold<int>(0, (s, c) => s + c.count);
    if (total == 0) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('No trips to chart yet')),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _PiePainter(stats, total)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: stats.map((s) {
              final pct = (s.count / total * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: categoryColor(s.category),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_label(s.category)} · $pct%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _label(String c) =>
      c.isEmpty ? c : '${c[0].toUpperCase()}${c.substring(1)}';
}

class _PiePainter extends CustomPainter {
  final List<CategoryStat> stats;
  final int total;

  _PiePainter(this.stats, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    double start = -math.pi / 2; // start at top

    for (final s in stats) {
      final sweep = (s.count / total) * 2 * math.pi;
      final paint = Paint()
        ..color = categoryColor(s.category)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
      start += sweep;
    }

    // Donut hole for a cleaner look.
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.total != total || old.stats != stats;
}
