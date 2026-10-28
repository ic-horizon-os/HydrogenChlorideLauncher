// Live loader-install checks against real loader APIs. Skipped unless
// HCL_LIVE=1.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/download_source.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/java_runtime_manager.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/loader_installer.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/minecraft_installer.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_json.dart';

final bool _live = Platform.environment['HCL_LIVE'] == '1';

void main() {
  late Directory root;
  late LoaderInstaller installer;

  setUp(() {
    root = Directory.systemTemp.createTempSync('hcl-loader-');
    installer = LoaderInstaller(
      root: root.path,
      mirror: DownloadMirror.official,
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'live: fabric build list and install',
    () async {
      final List<LoaderBuild> builds = await installer.listBuilds(
        LoaderKind.fabric,
        '1.21.1',
      );
      expect(builds, isNotEmpty);
      final LoaderInstallResult result = await installer.install(
        LoaderKind.fabric,
        '1.21.1',
        builds.first.loaderVersion,
      );
      expect(result.versionId, isNotEmpty);
      final VersionJson? json = await loadVersionJson(
        root.path,
        result.versionId,
      );
      expect(json, isNotNull);
      // Fabric merges the vanilla main class and libraries through inheritsFrom.
      expect(json!.mainClass, isNotEmpty);
      expect(
        json.libraries.any(
          (LibraryEntry lib) => lib.name.contains('fabric-loader'),
        ),
        isTrue,
      );
      expect(
        File('${root.path}/versions/1.21.1/1.21.1.jar').existsSync(),
        isTrue,
      );
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'live: forge build list',
    () async {
      final List<LoaderBuild> builds = await installer.listBuilds(
        LoaderKind.forge,
        '1.20.1',
      );
      expect(builds, isNotEmpty);
      expect(builds.first.loaderVersion, isNotEmpty);
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'live: neoforge build list',
    () async {
      try {
        final List<LoaderBuild> builds = await installer.listBuilds(
          LoaderKind.neoforge,
          '1.21.1',
        );
        expect(builds, isNotEmpty);
        expect(builds.first.loaderVersion, startsWith('21.1'));
      } on InstallException catch (error) {
        // neoforged's maven is unreachable from some networks; the installer
        // must report that clearly instead of hanging.
        expect(error.message, contains('maven.neoforged.net'));
      }
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'live: neoforge rejects pre-1.20.2 versions',
    () async {
      expect(
        () => installer.listBuilds(LoaderKind.neoforge, '1.20.1'),
        throwsA(isA<InstallException>()),
      );
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'live: forge installer runs with Mojang JRE',
    () async {
      final List<LoaderBuild> builds = await installer.listBuilds(
        LoaderKind.forge,
        '1.20.1',
      );
      final String java = await JavaRuntimeManager(
        root: root.path,
        mirror: DownloadMirror.official,
      ).download(17);
      final LoaderInstallResult result = await installer.install(
        LoaderKind.forge,
        '1.20.1',
        builds.first.loaderVersion,
        javaExecutable: java,
      );
      // Forge names the folder after the loaded game ("1.20.1-forge-47.4.28"),
      // so require a version JSON for the reported id rather than a guessed path.
      expect(result.warnings, isEmpty);
      expect(
        File(
              '${root.path}/versions/${result.versionId}/${result.versionId}.json',
            ).existsSync() ||
            Directory('${root.path}/versions/${result.versionId}')
                .listSync()
                .any((FileSystemEntity e) => e.path.endsWith('.json')),
        isTrue,
      );
      final VersionJson? merged = await loadVersionJson(
        root.path,
        result.versionId,
      );
      expect(merged, isNotNull);
      expect(
        merged!.libraries.any((LibraryEntry l) => l.name.contains('forge')),
        isTrue,
      );
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
