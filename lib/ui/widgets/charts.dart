import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import '../../core/utils/format.dart';
import '../../theme/fluent_theme.dart';

List<Color> chartColors(Color accent) {
  final HSLColor base = HSLColor.fromColor(accent);
  return <Color>[
    accent,
    base.withHue((base.hue + 42) % 360).withSaturation(0.55).toColor(),
    base.withHue((base.hue + 118) % 360).withSaturation(0.48).toColor(),
    base.withHue((base.hue + 196) % 360).withSaturation(0.58).toColor(),
    base.withHue((base.hue + 286) % 360).withSaturation(0.5).toColor(),
  ];
}

class DurationPieChart extends StatelessWidget {
  const DurationPieChart({
    super.key,
    required this.data,
    this.size = 190,
    this.centerLabel = '总时长',
  });

  final Map<String, Duration> data;
  final double size;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<MapEntry<String, Duration>> entries = data.entries
        .where(
          (MapEntry<String, Duration> entry) => entry.value > Duration.zero,
        )
        .toList(growable: false);
    if (entries.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: palette.textTertiary, fontSize: 12),
          ),
        ),
      );
    }
    final int totalSeconds = entries.fold<int>(
      0,
      (int value, MapEntry<String, Duration> entry) =>
          value + entry.value.inSeconds,
    );
    final List<Color> colors = chartColors(palette.accent);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(size),
            painter: _PiePainter(
              entries: entries,
              colors: colors,
              totalSeconds: totalSeconds,
              trackColor: palette.surfaceAlt,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                formatDuration(Duration(seconds: totalSeconds), compact: true),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerLabel,
                style: TextStyle(color: palette.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.entries,
    required this.colors,
    required this.totalSeconds,
    required this.trackColor,
  });

  final List<MapEntry<String, Duration>> entries;
  final List<Color> colors;
  final int totalSeconds;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 10,
    );
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    double start = -math.pi / 2;
    const double gap = 0.035;
    for (int i = 0; i < entries.length; i++) {
      final double sweep =
          (entries[i].value.inSeconds / totalSeconds) * math.pi * 2;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.butt
        ..color = colors[i % colors.length];
      final double drawSweep = math.max(0, sweep - gap);
      canvas.drawArc(rect, start + gap / 2, drawSweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.totalSeconds != totalSeconds ||
        oldDelegate.entries != entries ||
        oldDelegate.trackColor != trackColor;
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.data, this.maxItems = 5});

  final Map<String, Duration> data;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<Color> colors = chartColors(palette.accent);
    final List<MapEntry<String, Duration>> entries = data.entries.toList()
      ..sort(
        (MapEntry<String, Duration> a, MapEntry<String, Duration> b) =>
            b.value.compareTo(a.value),
      );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < entries.length && i < maxItems; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entries[i].key,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatDuration(entries[i].value, compact: true),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class DurationBarChart extends StatelessWidget {
  const DurationBarChart({super.key, required this.data, this.maxItems = 8});

  final Map<String, Duration> data;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<MapEntry<String, Duration>> entries = data.entries.toList()
      ..sort(
        (MapEntry<String, Duration> a, MapEntry<String, Duration> b) =>
            b.value.compareTo(a.value),
      );
    if (entries.isEmpty) {
      return _empty(palette);
    }
    final List<MapEntry<String, Duration>> visible = entries
        .take(maxItems)
        .toList(growable: false);
    final int maxSeconds = visible.first.value.inSeconds;
    return Column(
      children: <Widget>[
        for (final MapEntry<String, Duration> entry in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 132,
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 10,
                      color: palette.surfaceAlt,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: maxSeconds == 0
                            ? 0
                            : (entry.value.inSeconds / maxSeconds)
                                  .clamp(0.02, 1.0)
                                  .toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                palette.accent,
                                palette.accent.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 68,
                  child: Text(
                    formatDuration(entry.value, compact: true),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _empty(FluentPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: palette.textTertiary, fontSize: 12),
        ),
      ),
    );
  }
}

class DurationLineChart extends StatelessWidget {
  const DurationLineChart({super.key, required this.daily, this.height = 190});

  final Map<DateTime, Duration> daily;
  final double height;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<MapEntry<DateTime, Duration>> entries = daily.entries.toList()
      ..sort(
        (MapEntry<DateTime, Duration> a, MapEntry<DateTime, Duration> b) =>
            a.key.compareTo(b.key),
      );
    final int maxSeconds = entries.fold<int>(
      0,
      (int value, MapEntry<DateTime, Duration> entry) =>
          math.max(value, entry.value.inSeconds),
    );
    if (entries.isEmpty || maxSeconds == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: palette.textTertiary, fontSize: 12),
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _LinePainter(
              entries: entries,
              maxSeconds: maxSeconds,
              accent: palette.accent,
              grid: palette.border,
              textColor: palette.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              formatShortDate(entries.first.key),
              style: TextStyle(color: palette.textTertiary, fontSize: 10),
            ),
            Text(
              '最近 ${entries.length} 天',
              style: TextStyle(color: palette.textTertiary, fontSize: 10),
            ),
            Text(
              formatShortDate(entries.last.key),
              style: TextStyle(color: palette.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.entries,
    required this.maxSeconds,
    required this.accent,
    required this.grid,
    required this.textColor,
  });

  final List<MapEntry<DateTime, Duration>> entries;
  final int maxSeconds;
  final Color accent;
  final Color grid;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 34;
    const double right = 8;
    const double top = 10;
    const double bottom = 8;
    final double width = size.width - left - right;
    final double height = size.height - top - bottom;

    final Paint gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = top + height * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final int value = (maxSeconds * (3 - i) / 3).round();
      final String label = value >= 3600
          ? '${(value / 3600).toStringAsFixed(1)}h'
          : '${(value / 60).round()}m';
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(left - painter.width - 6, y - 5));
    }

    final double step = entries.length > 1 ? width / (entries.length - 1) : 0;
    final List<Offset> points = <Offset>[
      for (int i = 0; i < entries.length; i++)
        Offset(
          left + step * i,
          top + height * (1 - entries[i].value.inSeconds / maxSeconds),
        ),
    ];

    final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final Offset previous = points[i - 1];
      final Offset current = points[i];
      final double mid = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        mid,
        previous.dy,
        mid,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final Path fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, top + height)
      ..lineTo(points.first.dx, top + height)
      ..close();
    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          accent.withValues(alpha: 0.28),
          accent.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(left, top, width, height));
    canvas.drawPath(fillPath, fill);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawPath(linePath, stroke);

    final Paint dot = Paint()..color = accent;
    for (final Offset point in points) {
      canvas.drawCircle(point, 2.6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.maxSeconds != maxSeconds ||
        oldDelegate.accent != accent;
  }
}
