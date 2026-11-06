import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show Uint8List;

import '../../theme/fluent_theme.dart';

/// Front-view rendering of a Minecraft skin texture (64x64, or legacy
/// 64x32 with mirrored limbs). Base layer composes with its overlay, and
/// the whole figure scales to the available box without blurring pixels.
class SkinPreview extends StatefulWidget {
  const SkinPreview({
    super.key,
    required this.file,
    this.model = 'classic',
    this.height = 220,
  });

  final File? file;

  /// `classic` or `slim`; only affects arm width.
  final String model;
  final double height;

  @override
  State<SkinPreview> createState() => _SkinPreviewState();
}

class _SkinPreviewState extends State<SkinPreview> {
  ui.Image? _image;
  bool _legacy = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant SkinPreview old) {
    super.didUpdateWidget(old);
    if (old.file?.path != widget.file?.path) _decode();
  }

  Future<void> _decode() async {
    final File? file = widget.file;
    if (file == null || !file.existsSync()) {
      if (mounted) setState(() => _image = null);
      return;
    }
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _legacy = frame.image.height <= 32;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _image = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final ui.Image? image = _image;
    if (image == null) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.person_outline, size: 34, color: palette.textTertiary),
              const SizedBox(height: 8),
              Text(
                '暂无皮肤预览',
                style: TextStyle(color: palette.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: Center(
        child: CustomPaint(
          size: Size(widget.height * 0.5, widget.height),
          painter: _SkinPainter(
            image: image,
            slim: widget.model == 'slim',
            legacy: _legacy,
          ),
        ),
      ),
    );
  }
}

class _SkinPainter extends CustomPainter {
  const _SkinPainter({
    required this.image,
    required this.slim,
    required this.legacy,
  });

  final ui.Image image;
  final bool slim;
  final bool legacy;

  // Front-face regions in the standard 64x64 layout.
  static const Rect _headFront = Rect.fromLTWH(8, 8, 8, 8);
  static const Rect _headHat = Rect.fromLTWH(40, 8, 8, 8);
  static const Rect _bodyFront = Rect.fromLTWH(20, 20, 8, 12);
  static const Rect _bodyJacket = Rect.fromLTWH(20, 36, 8, 12);
  static const Rect _rightArmFront = Rect.fromLTWH(44, 20, 4, 12);
  static const Rect _rightArmSleeve = Rect.fromLTWH(44, 36, 4, 12);
  static const Rect _rightLegFront = Rect.fromLTWH(4, 20, 4, 12);
  static const Rect _rightLegPants = Rect.fromLTWH(4, 36, 4, 12);
  static const Rect _leftArmFront = Rect.fromLTWH(36, 52, 4, 12);
  static const Rect _leftArmSleeve = Rect.fromLTWH(52, 52, 4, 12);
  static const Rect _leftLegFront = Rect.fromLTWH(20, 52, 4, 12);
  static const Rect _leftLegPants = Rect.fromLTWH(4, 52, 4, 12);

  @override
  void paint(Canvas canvas, Size size) {
    // The figure is left arm + torso + right arm wide, 32 tall (head 8 +
    // body 12 + legs 12); scale so it fits while keeping square pixels.
    final double armWidth = slim ? 3 : 4;
    final double figureWidth = 4 + 8 + armWidth;
    final double pixel = (size.height / 32).clamp(1.0, 32.0);
    final double width = figureWidth * pixel;
    final Offset origin = Offset(
      (size.width - width) / 2,
      (size.height - 32 * pixel) / 2,
    );
    final Paint paint = Paint()..filterQuality = FilterQuality.none;

    Rect dst(double col, double row, double w, double h) => Rect.fromLTWH(
      origin.dx + col * pixel,
      origin.dy + row * pixel,
      w * pixel,
      h * pixel,
    );

    final double leftArmX = 0;
    final double bodyX = 4; // torso occupies columns 4..11
    final double rightArmX = 12; // right arm sits flush against the torso
    final double headX = 4; // head is 8 wide, centred over the torso

    void draw(Rect region, Rect target) {
      canvas.drawImageRect(image, region, target, paint);
    }

    Rect trimmed(Rect region, double width) =>
        Rect.fromLTWH(region.left, region.top, width, region.height);

    // Head with hat overlay, centred over the torso column.
    draw(_headFront, dst(headX, 0, 8, 8));
    draw(_headHat, dst(headX, 0, 8, 8));

    // Torso with jacket overlay.
    draw(_bodyFront, dst(bodyX, 8, 8, 12));
    draw(_bodyJacket, dst(bodyX, 8, 8, 12));

    // Arms: left flush at the figure edge, right beside the torso.
    draw(trimmed(_leftArmFront, armWidth), dst(leftArmX, 8, armWidth, 12));
    draw(trimmed(_leftArmSleeve, armWidth), dst(leftArmX, 8, armWidth, 12));
    draw(trimmed(_rightArmFront, armWidth), dst(rightArmX, 8, armWidth, 12));
    draw(trimmed(_rightArmSleeve, armWidth), dst(rightArmX, 8, armWidth, 12));

    // Legs, directly below the torso: right at columns 4..7, left at 8..11.
    draw(_rightLegFront, dst(4, 20, 4, 12));
    draw(_rightLegPants, dst(4, 20, 4, 12));
    if (legacy) {
      // 64x32 skins have no left-limb regions; mirror the right ones.
      drawMirrored(canvas, _rightLegFront, dst(8, 20, 4, 12), paint);
      drawMirrored(canvas, _rightLegPants, dst(8, 20, 4, 12), paint);
      drawMirrored(
        canvas,
        trimmed(_rightArmFront, armWidth),
        dst(leftArmX, 8, armWidth, 12),
        paint,
      );
      drawMirrored(
        canvas,
        trimmed(_rightArmSleeve, armWidth),
        dst(leftArmX, 8, armWidth, 12),
        paint,
      );
    } else {
      draw(_leftLegFront, dst(8, 20, 4, 12));
      draw(_leftLegPants, dst(8, 20, 4, 12));
    }
  }

  void drawMirrored(
    Canvas canvas,
    Rect region,
    Rect target,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(target.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-target.center.dx, 0);
    canvas.drawImageRect(image, region, target, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkinPainter old) =>
      old.image != image || old.slim != slim || old.legacy != legacy;
}
