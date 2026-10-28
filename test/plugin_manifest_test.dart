import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/models/plugin_manifest.dart';
import 'package:hydrogen_chloride_launcher/core/services/plugin_registry.dart';

Map<String, dynamic> validManifest() => <String, dynamic>{
  'id': 'test-plugin',
  'name': 'Test Plugin',
  'version': '1.2.3',
  'author': 'Tester',
  'description': 'A plugin used by unit tests.',
  'minLauncherVersion': '0.1.0',
  'permissions': <String>['openUrl'],
  'contributes': <String, dynamic>{
    'pages': <Object?>[
      <String, dynamic>{
        'id': 'main',
        'title': 'Test Page',
        'icon': 'auto_awesome',
        'widgets': <Object?>[
          <String, dynamic>{'type': 'heading', 'text': 'Hello'},
          <String, dynamic>{
            'type': 'button',
            'label': 'Docs',
            'action': <String, dynamic>{
              'type': 'openUrl',
              'url': 'https://example.com',
            },
          },
        ],
      },
    ],
  },
};

void main() {
  test('parses a valid manifest and pages', () {
    final PluginManifest manifest = PluginManifest.fromJson(
      validManifest(),
      directory: '/tmp/test-plugin',
    );
    expect(manifest.id, 'test-plugin');
    expect(manifest.name, 'Test Plugin');
    expect(manifest.version, '1.2.3');
    expect(manifest.permissions, <String>['openUrl']);
    expect(manifest.pages, hasLength(1));
    expect(manifest.pages.first.title, 'Test Page');
    expect(manifest.pages.first.widgets, hasLength(2));
  });

  test('rejects invalid ids and missing fields', () {
    expect(
      () => PluginManifest.fromJson(
        validManifest()..['id'] = 'Invalid ID',
        directory: '/tmp/x',
      ),
      throwsFormatException,
    );
    expect(
      () => PluginManifest.fromJson(
        validManifest()..remove('name'),
        directory: '/tmp/x',
      ),
      throwsFormatException,
    );
    expect(
      () => PluginManifest.fromJson(
        validManifest()..remove('version'),
        directory: '/tmp/x',
      ),
      throwsFormatException,
    );
  });

  test(
    'registry discovers, disables, installs and uninstalls plugins',
    () async {
      final Directory root = Directory.systemTemp.createTempSync(
        'hcl-plugin-test-',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final AppPaths paths = AppPaths.forTesting(root);
      await paths.ensure();

      final Directory installed = Directory(
        '${paths.pluginsDir.path}/test-plugin',
      );
      installed.createSync(recursive: true);
      File('${installed.path}/plugin.json')
          .writeAsStringSync(jsonEncode(validManifest()));

      final PluginRegistry registry = PluginRegistry(paths);
      addTearDown(registry.dispose);
      await registry.load(includeDemo: false);

      expect(registry.plugins, hasLength(1));
      expect(registry.plugins.first.enabled, isTrue);

      await registry.setEnabled('test-plugin', false);
      await registry.load(includeDemo: false);
      expect(registry.plugins.first.enabled, isFalse);

      final Directory source = Directory('${root.path}/source/test-plugin')
        ..createSync(recursive: true);
      File('${source.path}/plugin.json').writeAsStringSync(
        jsonEncode(
          validManifest()
            ..['id'] = 'second-plugin'
            ..['name'] = 'Second',
        ),
      );
      final PluginManifest manifest = await registry.installFromDirectory(
        source,
      );
      expect(manifest.id, 'second-plugin');
      expect(registry.plugins, hasLength(2));

      await registry.uninstall('second-plugin');
      expect(registry.plugins, hasLength(1));
    },
  );

  test('registry rejects plugins that require a newer launcher', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-plugin-version-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();
    final Directory plugin = Directory('${paths.pluginsDir.path}/future')
      ..createSync(recursive: true);
    File('${plugin.path}/plugin.json').writeAsStringSync(
      jsonEncode(validManifest()..['minLauncherVersion'] = '99.0.0'),
    );

    final PluginRegistry registry = PluginRegistry(paths);
    addTearDown(registry.dispose);
    await registry.load(includeDemo: false);

    expect(registry.plugins, isEmpty);
    expect(registry.invalid, hasLength(1));
    expect(registry.invalid.first.error, contains('99.0.0'));
  });
}
