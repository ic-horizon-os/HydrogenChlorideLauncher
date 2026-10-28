import 'package:fluent_ui/fluent_ui.dart';

import '../../core/constants.dart';
import '../../theme/fluent_theme.dart';

/// Minimal opening screen: full product name in Maple Mono NF CN on the
/// theme's pure white/black background. No logo or loading indicator.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return ColoredBox(
      color: palette.background,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.96 + value * 0.04, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 32),
            child: Text(
              AppInfo.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Maple Mono NF CN',
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
