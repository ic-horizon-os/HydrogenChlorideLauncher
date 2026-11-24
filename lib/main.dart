import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

/// Profiling probe (profile builds only): `--dart-define=HCL_PERF_TAB=library`
/// auto-switches to that tab 2.5s after startup and prints build/raster frame
/// times so library-entry jank can be attributed. Inert when undefined.
const String _perfTab = String.fromEnvironment('HCL_PERF_TAB');

void _perfTimings(List<FrameTiming> timings) {
  for (final FrameTiming t in timings) {
    final int totalMs = t.totalSpan.inMilliseconds;
    if (totalMs < 18) continue;
    debugPrint(
      '[perf] frame=${t.frameNumber} '
      'build=${t.buildDuration.inMilliseconds}ms '
      'raster=${t.rasterDuration.inMilliseconds}ms '
      'total=${totalMs}ms '
      'layerCache=${t.layerCacheCount}/${t.layerCacheMegabytes.toStringAsFixed(1)}MB '
      'pictureCache=${t.pictureCacheCount}/${t.pictureCacheMegabytes.toStringAsFixed(1)}MB',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _prepareWindow();

  try {
    final AppState state = await AppState.bootstrap();
    runApp(AppScope(notifier: state, child: const HclApp()));
    if (_perfTab.isNotEmpty) {
      SchedulerBinding.instance.addTimingsCallback(_perfTimings);
      final HomeTab tab = HomeTab.values.firstWhere(
        (HomeTab t) => t.name == _perfTab,
        orElse: () => HomeTab.library,
      );
      debugPrint('[perf] armed, switching to ${tab.name} in 2.5s');
      Future<void>.delayed(const Duration(milliseconds: 2500), () {
        debugPrint('[perf] switch ${tab.name} now');
        state.selectTab(tab);
      });
    }
  } on Object catch (error, stackTrace) {
    debugPrint('Bootstrap failed: $error\n$stackTrace');
    runApp(_BootstrapErrorApp(message: '$error'));
  }
}

Future<void> _prepareWindow() async {
  try {
    await windowManager.ensureInitialized();
    const WindowOptions options = WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1080, 680),
      center: true,
      title: AppInfo.name,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Color(0xFF000000),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.show();
      await windowManager.focus();
    });
  } on Object catch (error) {
    debugPrint('Window manager unavailable: $error');
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(brightness: Brightness.dark),
      home: ScaffoldPage(
        content: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    FluentIcons.error,
                    color: Color(0xFFE81123),
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '启动器初始化失败',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 18),
                  const Text(
                    '请检查配置目录是否可写，或删除 '
                    '~/.config/hyalab/hydrogen-chloride-launcher 后重试。',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
