import 'package:fluent_ui/fluent_ui.dart';

import '../core/models/app_settings.dart';

/// Fluent-derived palette used by the custom surfaces and charts.
@immutable
class FluentPalette {
  const FluentPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceStrong,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentForeground,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceStrong;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentForeground;
  final Color success;
  final Color warning;
  final Color danger;

  Color get hover => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.045);

  Color get pressed => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  Color get subtleFill => isDark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.black.withValues(alpha: 0.03);
}

class FluentColors {
  const FluentColors._(this.palette);

  final FluentPalette palette;

  static FluentColors of(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final ResourceDictionary resources = theme.resources;
    return FluentColors._(
      FluentPalette(
        isDark: theme.brightness == Brightness.dark,
        background: theme.brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        surface: theme.cardColor,
        surfaceAlt: resources.subtleFillColorSecondary,
        surfaceStrong: theme.menuColor,
        border: resources.cardStrokeColorDefault,
        textPrimary: resources.textFillColorPrimary,
        textSecondary: resources.textFillColorSecondary,
        textTertiary: resources.textFillColorTertiary,
        accent: theme.accentColor.normal,
        accentForeground: resources.textOnAccentFillColorPrimary,
        success: Colors.green,
        warning: Colors.orange,
        danger: Colors.red,
      ),
    );
  }
}

class FluentTokens {
  FluentTokens._();

  static const double radiusSmall = 4;
  static const double radius = 8;
  static const double radiusLarge = 8;
  static const double titleBarHeight = 40;
  static const double navBarHeight = 48;
  static const double contentMaxWidth = 1180;
}

/// Builds the Win11/Fluent theme. The app background is owned by
/// [AcrylicBackground], so the Fluent scaffold surfaces stay transparent.
FluentThemeData buildFluentTheme({
  required AppSettings settings,
  required Brightness platformBrightness,
}) {
  final Brightness brightness = switch (settings.themeMode) {
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
    AppThemeMode.system => platformBrightness,
  };
  final bool isDark = brightness == Brightness.dark;
  return FluentThemeData(
    brightness: brightness,
    accentColor: settings.accentColor.toAccentColor(),
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: Colors.transparent,
    micaBackgroundColor: Colors.transparent,
    acrylicBackgroundColor: Colors.transparent,
    acrylicFallbackColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
    cardColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
    menuColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
    acrylicTintOpacity: isDark ? 0.25 : 0.0,
    acrylicLuminosityOpacity: isDark ? 0.85 : 0.9,
    navigationPaneTheme: const NavigationPaneThemeData(
      iconPadding: EdgeInsets.zero,
    ),
  );
}
