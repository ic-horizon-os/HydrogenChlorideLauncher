import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _prepareWindow();

  try {
    final AppState state = await AppState.bootstrap();
    runApp(AppScope(notifier: state, child: const HclApp()));
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
