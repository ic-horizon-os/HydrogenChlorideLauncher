import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_entry.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_settings.dart';
import 'package:hydrogen_chloride_launcher/core/services/version_isolation.dart';

void main() {
  final AppEntry entry = AppEntry(
    id: 'isolated',
    name: 'Fabulously Optimized',
    subtitle: '',
    description: '',
    kind: AppKind.modpack,
    versionId: '1.21.1-fabric',
    isolated: true,
  );

  test('isolated game dir follows the version folder', () {
    final Directory root = Directory.systemTemp.createTempSync('hcl-iso-');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppSettings settings = AppSettings.defaults(minecraftDir: root.path);
    expect(
      VersionIsolation.gameDir(entry, settings),
      '${root.path}/versions/1.21.1-fabric',
    );
    expect(
      VersionIsolation.gameDir(entry.copyWith(isolated: false), settings),
      root.path,
    );
  });

  test('ensure creates the isolated subdirectories', () async {
    final Directory root = Directory.systemTemp.createTempSync('hcl-iso-');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppSettings settings = AppSettings.defaults(minecraftDir: root.path);
    await VersionIsolation.ensure(entry, settings);
    final String base = VersionIsolation.gameDir(entry, settings);
    for (final String name in <String>['mods', 'config', 'saves']) {
      expect(Directory('$base/$name').existsSync(), isTrue);
    }
  });
}
