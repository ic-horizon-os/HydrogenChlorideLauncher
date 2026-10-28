import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:hydrogen_chloride_launcher/app.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_settings.dart';
import 'package:hydrogen_chloride_launcher/core/services/core_bridge.dart';
import 'package:hydrogen_chloride_launcher/state/app_scope.dart';
import 'package:hydrogen_chloride_launcher/state/app_state.dart';

/// Renders key Alpha screens to PNG for visual review.
///
/// Not part of the default `flutter test` run because it depends on a system
/// CJK font and golden output. Run explicitly:
///   flutter test tool/screenshots_test.dart --update-goldens
Future<void> _loadTestFont() async {
  final String home = Platform.environment['HOME'] ?? '';
  final List<String> noto = <String>[
    if (home.isNotEmpty) '$home/.fonts/NotoSansCJK-Regular.ttc',
    if (home.isNotEmpty) '$home/.fonts/NotoSansCJK-Bold.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc',
  ];
  final List<String> maple = <String>[
    if (home.isNotEmpty) '$home/.fonts/MapleMono-NF-CN-Regular.ttf',
    if (home.isNotEmpty) '$home/.fonts/MapleMono-NF-CN-Bold.ttf',
    '/usr/share/fonts/maple-mono-nf-cn/MapleMono-NF-CN-Regular.ttf',
    '/usr/share/fonts/maple-mono-nf-cn/MapleMono-NF-CN-Bold.ttf',
  ];

  Future<List<ByteData>> readFonts(List<String> paths) async {
    final List<ByteData> result = <ByteData>[];
    for (final String path in paths) {
      final File file = File(path);
      if (!file.existsSync()) continue;
      final Uint8List bytes = await file.readAsBytes();
      result.add(ByteData.view(bytes.buffer));
    }
    return result;
  }

  Future<void> register(List<ByteData> fonts) async {
    for (final String family in <String>[
      'Ahem',
      'Roboto',
      'Segoe UI',
      'Segoe UI Variable',
      'Segoe UI Variable Text',
    ]) {
      final FontLoader loader = FontLoader(family);
      for (final ByteData font in fonts) {
        loader.addFont(Future<ByteData>.value(font));
      }
      await loader.load();
    }
  }

  List<ByteData> fonts = await readFonts(noto);
  if (fonts.isEmpty) fonts = await readFonts(maple);
  if (fonts.isNotEmpty) {
    try {
      await register(fonts);
    } on Object {
      final List<ByteData> fallback = await readFonts(maple);
      if (fallback.isNotEmpty) await register(fallback);
    }
  }

  final List<String> iconCandidates = <String>[
    if (home.isNotEmpty)
      '$home/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final String path in iconCandidates) {
    final File file = File(path);
    if (!file.existsSync()) continue;
    final Uint8List bytes = await file.readAsBytes();
    final FontLoader loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
    break;
  }

  final List<String> mapleCandidates = <String>[
    '/usr/share/fonts/maple-mono-nf-cn/MapleMono-NF-CN-Regular.ttf',
    if (home.isNotEmpty) '$home/.fonts/MapleMono-NF-CN-Regular.ttf',
    'assets/fonts/MapleMono-NF-CN-Regular.ttf',
  ];
  for (final String path in mapleCandidates) {
    final File file = File(path);
    if (!file.existsSync()) continue;
    final Uint8List bytes = await file.readAsBytes();
    final FontLoader loader = FontLoader('Maple Mono NF CN')
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
    break;
  }

  final String fluentPackage = home.isEmpty
      ? ''
      : '$home/.pub-cache/hosted/pub.dev/fluent_ui-4.17.0/fonts';
  final Map<String, String> fluentFonts = <String, String>{
    'FluentIcons': '$fluentPackage/FluentIcons.ttf',
    'packages/fluent_ui/FluentIcons': '$fluentPackage/FluentIcons.ttf',
    'SegoeIcons': '$fluentPackage/SegoeIcons.ttf',
    'packages/fluent_ui/SegoeIcons': '$fluentPackage/SegoeIcons.ttf',
  };
  for (final MapEntry<String, String> entry in fluentFonts.entries) {
    final File file = File(entry.value);
    if (!file.existsSync()) continue;
    final Uint8List bytes = await file.readAsBytes();
    final FontLoader loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

void main() {
  testWidgets('capture Alpha screens', (WidgetTester tester) async {
    await tester.runAsync(_loadTestFont);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-screenshots-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    // Seed the official Minecraft key art so the library banner renders the
    // real cover instead of the offline placeholder. HCL_SCREENSHOT_COVER can
    // point at a downloaded copy; otherwise the file is fetched once here.
    await _seedCoverArt(root);
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
    await tester.runAsync(() => app.scanJava());

    await tester.pumpWidget(AppScope(notifier: app, child: const HclApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(FluentApp),
      matchesGoldenFile('goldens/00-splash.png'),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      // ignore: avoid_print
      print('CAPTURE_START $name');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 8),
      );
      await expectLater(
        find.byType(FluentApp),
        matchesGoldenFile('goldens/$name.png'),
      );
      // ignore: avoid_print
      print('CAPTURE_DONE $name');
    }

    await capture('01-browse');

    app.selectTab(HomeTab.library);
    await capture('02-library');

    app.selectTab(HomeTab.community);
    await capture('03-community');

    app.selectTab(HomeTab.account);
    await capture('04-account');

    app.openSettings();
    await capture('05-settings-account');

    app.selectSettingsSection(SettingsSection.personalization);
    await capture('06-settings-personalization');

    app.selectSettingsSection(SettingsSection.plugins);
    await capture('07-settings-plugins');

    app.selectSettingsSection(SettingsSection.java);
    await capture('08-settings-java');

    app.selectSettingsSection(SettingsSection.versions);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await capture('09-settings-versions');

    app.selectSettingsSection(SettingsSection.statistics);
    await capture('10-settings-statistics');

    app.selectSettingsSection(SettingsSection.about);
    await capture('11-settings-about');

    // Dark theme snapshot of the library.
    await tester.runAsync(() => app.setThemeMode(AppThemeMode.dark));
    app.closeSettings();
    await tester.pumpAndSettle();
    app.selectTab(HomeTab.library);
    await capture('12-library-dark');
  });
}

/// Copies the official key art into the temporary app data directory so the
/// library banner renders the real cover in the captures.
///
/// The file is read from `HCL_SCREENSHOT_COVER` (or `assets/covers/
/// java-bedrock.jpg` when present). No network access happens inside the
/// widget test: its fake clock would never let a real request complete.
Future<void> _seedCoverArt(Directory root) async {
  final String? provided =
      Platform.environment['HCL_SCREENSHOT_COVER'] ??
      (File('assets/covers/java-bedrock.jpg').existsSync()
          ? 'assets/covers/java-bedrock.jpg'
          : null);
  if (provided == null) return;
  final File source = File(provided);
  if (!source.existsSync()) return;
  final Directory covers = Directory(p.join(root.path, 'data', 'covers'));
  await covers.create(recursive: true);
  await source.copy(p.join(covers.path, 'java-bedrock.jpg'));
}
