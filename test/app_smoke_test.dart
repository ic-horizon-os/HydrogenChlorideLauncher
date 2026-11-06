import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hydrogen_chloride_launcher/app.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_entry.dart';
import 'package:hydrogen_chloride_launcher/core/services/core_bridge.dart';
import 'package:hydrogen_chloride_launcher/state/app_scope.dart';
import 'package:hydrogen_chloride_launcher/state/app_state.dart';

void main() {
  testWidgets('shell renders and navigates across tabs and settings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-widget-test-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppState app = (await tester.runAsync(
      () => AppState.bootstrap(
        paths: AppPaths.forTesting(root),
        coreBridge: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
        httpClient: MockClient(
          (http.Request request) async => http.Response('{}', 500),
        ),
        scanJavaOnStart: false,
      ),
    ))!;
    addTearDown(app.dispose);
    // The shell test exercises the sample entries, which are opt-in now.
    await tester.runAsync(() => app.setDemoData(true));

    await tester.pumpWidget(
      AppScope(notifier: app, child: const HclApp(showSplash: false)),
    );
    await _settle(tester, 'initial');

    await tester.tap(find.text('HCL'));
    await _settle(tester, 'hcl-settings');
    expect(find.text('HCL 设置'), findsOneWidget);
    app.closeSettings();
    await _settle(tester, 'close-hcl-settings');

    expect(find.text('浏览 Minecraft 内容'), findsOneWidget);
    expect(find.text('库'), findsWidgets);

    final Rect tabRect = tester.getRect(find.text('浏览'));
    final Rect indicatorRect = tester.getRect(
      find.byKey(const ValueKey<String>('nav-selection-indicator')),
    );
    expect(
      (tabRect.center.dx - indicatorRect.center.dx).abs(),
      lessThan(1.5),
      reason: 'tab underline should be centered under the label',
    );

    await tester.tap(find.text('社区'));
    await _settle(tester, 'nav-community');
    expect(find.text('来源'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.back));
    await _settle(tester, 'nav-back');
    expect(find.text('浏览 Minecraft 内容'), findsOneWidget);
    await tester.tap(find.byIcon(FluentIcons.forward));
    await _settle(tester, 'nav-forward');
    expect(find.text('来源'), findsOneWidget);

    app.selectTab(HomeTab.library);
    await _settle(tester, 'library');
    expect(find.text('添加自定义程序'), findsOneWidget);
    expect(find.textContaining('Fabulously Optimized'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('detail-tab-mods')));
    await _settle(tester, 'library-mods');
    expect(find.text('模组管理'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('detail-tab-overview')));
    await _settle(tester, 'library-overview');

    app.selectTab(HomeTab.community);
    await _settle(tester, 'community');
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('添加订阅'), findsWidgets);

    app.selectTab(HomeTab.account);
    await _settle(tester, 'account');
    expect(find.text('登录 Microsoft 账户'), findsOneWidget);

    app.openSettings();
    await _settle(tester, 'settings-account');
    expect(find.text('登录信息'), findsWidgets);
    expect(find.text('未登录'), findsWidgets);

    app.selectSettingsSection(SettingsSection.personalization);
    await _settle(tester, 'settings-personalization');
    expect(find.text('背景预览'), findsOneWidget);
    expect(find.text('背景填充透明度'), findsOneWidget);

    app.selectSettingsSection(SettingsSection.statistics);
    await _settle(tester, 'settings-statistics');
    expect(find.text('使用时长分布'), findsOneWidget);
    expect(find.text('应用时长排行'), findsOneWidget);

    app.selectSettingsSection(SettingsSection.plugins);
    await _settle(tester, 'settings-plugins');
    expect(find.text('插件管理'), findsWidgets);
    expect(find.text('Hello HCL'), findsOneWidget);

    app.selectSettingsSection(SettingsSection.about);
    await _settle(tester, 'settings-about');
    expect(find.text('技术栈与依赖'), findsOneWidget);
    expect(find.textContaining('0.1.0-alpha.2'), findsWidgets);

    app.closeSettings();
    await _settle(tester, 'close-settings');
    app.selectTab(HomeTab.browse);
    await _settle(tester, 'back-home');
    expect(find.text('浏览 Minecraft 内容'), findsOneWidget);
  });

  testWidgets('Minecraft launch is blocked before login', (
    WidgetTester tester,
  ) async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-widget-gate-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppState app = (await tester.runAsync(
      () => AppState.bootstrap(
        paths: AppPaths.forTesting(root),
        coreBridge: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
        httpClient: MockClient(
          (http.Request request) async => http.Response('{}', 500),
        ),
        scanJavaOnStart: false,
      ),
    ))!;
    addTearDown(app.dispose);

    await tester.runAsync(() => app.setDemoData(true));
    final AppEntry minecraft = app.visibleEntries.firstWhere(
      (AppEntry entry) => entry.isMinecraft,
    );
    await app.launch(minecraft);

    expect(app.isAuthenticated, isFalse);
    expect(app.lastError, contains('登录'));
    expect(app.settingsOpen, isTrue);
    expect(app.settingsSection, SettingsSection.account);
    expect(app.launcher.activeApp, isNull);
  });
}

Future<void> _settle(WidgetTester tester, String step) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
}
