import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

import '../core/models/app_settings.dart';
import 'fluent_theme.dart';

/// Mica/Acrylic style background: a base fill, optional user image, an accent
/// mesh when no image is selected, Gaussian blur and an acrylic grain layer.
class AcrylicBackground extends StatefulWidget {
  const AcrylicBackground({
    super.key,
    required this.settings,
    required this.child,
  });

  final AppSettings settings;
  final Widget child;

  @override
  State<AcrylicBackground> createState() => _AcrylicBackgroundState();
}

class _AcrylicBackgroundState extends State<AcrylicBackground> {
  // The shell rebuilds on every state tick; probing the filesystem each
  // build puts synchronous disk I/O on the UI thread. Cache per path.
  String? _checkedPath;
  bool _hasImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant AcrylicBackground old) {
    super.didUpdateWidget(old);
    if (old.settings.backgroundImagePath !=
        widget.settings.backgroundImagePath) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final String? imagePath = widget.settings.backgroundImagePath;
    final bool hasImage =
        imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();
    if (_checkedPath != imagePath || _hasImage != hasImage) {
      setState(() {
        _checkedPath = imagePath;
        _hasImage = hasImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final String? imagePath = widget.settings.backgroundImagePath;
    final bool hasImage = _hasImage;
    final double opacity = widget.settings.backgroundOpacity
        .clamp(0.0, 1.0)
        .toDouble();
    final bool backgroundBlur = widget.settings.backgroundBlur;
    final bool acrylicNoise =
        backgroundBlur &&
        widget.settings.backgroundBlurMode == BackgroundBlurMode.acrylic;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Isolate the static backdrop behind its own repaint boundary: every
        // animated pixel above (page entrances, hovers, progress bars) must
        // not re-record the image, the 2600-rect noise layer or the gradient
        // — those only change when the settings themselves change.
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: palette.background),
              if (hasImage)
                Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                        return _AccentMesh(
                          accent: palette.accent,
                          isDark: palette.isDark,
                        );
                      },
                )
              else
                _AccentMesh(accent: palette.accent, isDark: palette.isDark),
              if (backgroundBlur)
                ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: widget.settings.backgroundBlurSigma,
                      sigmaY: widget.settings.backgroundBlurSigma,
                    ),
                    child: ColoredBox(
                      color: palette.background.withValues(alpha: opacity),
                    ),
                  ),
                )
              else
                ColoredBox(color: palette.background.withValues(alpha: opacity)),
              if (acrylicNoise)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _AcrylicNoisePainter(isDark: palette.isDark),
                  ),
                ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        palette.background.withValues(
                          alpha: palette.isDark ? 0.42 : 0.5,
                        ),
                        palette.background.withValues(alpha: 0.06),
                        palette.background.withValues(
                          alpha: palette.isDark ? 0.55 : 0.62,
                        ),
                      ],
                      stops: const <double>[0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // And keep app-content repaints from dirtying the backdrop either.
        RepaintBoundary(child: widget.child),
      ],
    );
  }
}

class _AccentMesh extends StatelessWidget {
  const _AccentMesh({required this.accent, required this.isDark});

  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AccentMeshPainter(accent: accent, isDark: isDark),
    );
  }
}

class _AccentMeshPainter extends CustomPainter {
  _AccentMeshPainter({required this.accent, required this.isDark});

  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..color = isDark ? const Color(0xFF050505) : Colors.white,
    );

    final Color secondary = HSLColor.fromColor(accent)
        .withHue((HSLColor.fromColor(accent).hue + 58) % 360)
        .withSaturation(0.62)
        .withLightness(isDark ? 0.46 : 0.64)
        .toColor();

    final Paint first = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.9, -1.05),
        radius: 1.35,
        colors: <Color>[
          accent.withValues(alpha: isDark ? 0.46 : 0.30),
          accent.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, first);

    final Paint second = Paint()
      ..shader = RadialGradient(
        center: const Alignment(1.05, 0.95),
        radius: 1.15,
        colors: <Color>[
          secondary.withValues(alpha: isDark ? 0.30 : 0.20),
          secondary.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, second);

    final Paint glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.25, 0.2),
        radius: 0.65,
        colors: <Color>[
          Colors.white.withValues(alpha: isDark ? 0.035 : 0.16),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);
  }

  @override
  bool shouldRepaint(covariant _AccentMeshPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.isDark != isDark;
  }
}

class _AcrylicNoisePainter extends CustomPainter {
  _AcrylicNoisePainter({required this.isDark});

  final bool isDark;
  static final Random _random = Random(117);
  static final List<Offset> _points = List<Offset>.generate(
    2600,
    (int index) => Offset(_random.nextDouble(), _random.nextDouble()),
    growable: false,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.028);
    for (final Offset point in _points) {
      canvas.drawRect(
        Rect.fromLTWH(point.dx * size.width, point.dy * size.height, 1.1, 1.1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AcrylicNoisePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = FluentTokens.radiusLarge,
    this.color,
    this.borderColor,
    this.blurSigma = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Card(
      padding: padding,
      margin: EdgeInsets.zero,
      backgroundColor: color ?? palette.surface,
      borderColor: borderColor ?? palette.border,
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}
