import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import 'core/constants.dart';
import 'core/models/app_settings.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/fluent_theme.dart';
import 'ui/shell/home_shell.dart';
import 'ui/shell/splash_screen.dart';

class HclApp extends StatefulWidget {
  const HclApp({super.key, this.showSplash = true});

  /// Disabled by widget tests so they can assert the main shell directly.
  final bool showSplash;

  @override
  State<HclApp> createState() => _HclAppState();
}

class _HclAppState extends State<HclApp> {
  Timer? _splashTimer;
  late bool _showSplash = widget.showSplash;

  @override
  void initState() {
    super.initState();
    if (_showSplash) {
      _splashTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showSplash = false);
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return FluentApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: const <Locale>[Locale('zh'), Locale('en', 'US')],
      theme: buildFluentTheme(
        settings: app.settings,
        platformBrightness: Brightness.light,
      ),
      darkTheme: buildFluentTheme(
        settings: app.settings,
        platformBrightness: Brightness.dark,
      ),
      themeMode: switch (app.settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
        child: _showSplash
            ? const SplashScreen(key: ValueKey<String>('splash'))
            : const HomeShell(key: ValueKey<String>('home')),
      ),
    );
  }
}
