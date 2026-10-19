import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../data/datasources/workflow_models.dart';

/// Draws only one patient's analyte/unit series, without converting units or
/// inventing clinical reference ranges.
class LabTrendChart extends StatelessWidget {
  const LabTrendChart({super.key, required this.observations});
  final List<LabObservation> observations;
  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) return const SizedBox.shrink();
    assert(
      observations.every((v) => v.seriesKey == observations.first.seriesKey),
    );
    final points = [...observations]
      ..sort((a, b) => a.reportedAt.compareTo(b.reportedAt));
    final locale = Localizations.localeOf(context).toString();
    final minimum = points.map((e) => e.value).reduce(math.min);
    final maximum = points.map((e) => e.value).reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$minimum – $maximum ${points.first.unit}'),
        const SizedBox(height: 12),
        Semantics(
          label: points
              .map(
                (e) =>
                    '${DateFormat.yMMMd(locale).format(e.reportedAt)}: ${e.value} ${e.unit}',
              )
              .join('; '),
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _TrendPainter(points, minimum, maximum),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(DateFormat.yMMMd(locale).format(points.first.reportedAt)),
            Text(DateFormat.yMMMd(locale).format(points.last.reportedAt)),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.minimum, this.maximum);
  final List<LabObservation> points;
  final double minimum, maximum;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 8 + (size.height - 16) * i / 2;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    final range = maximum - minimum;
    final duration = points.last.reportedAt
        .difference(points.first.reportedAt)
        .inMilliseconds;
    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(
          8 +
              (size.width - 16) *
                  (duration == 0
                      ? (points.length == 1 ? 0.5 : i / (points.length - 1))
                      : points[i].reportedAt
                                .difference(points.first.reportedAt)
                                .inMilliseconds /
                            duration),
          size.height -
              8 -
              (size.height - 16) *
                  (range == 0 ? 0.5 : (points[i].value - minimum) / range),
        ),
    ];
    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.primary;
    for (final point in offsets) {
      canvas.drawCircle(point, 4, dot);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) => oldDelegate.points != points;
}
