// End-to-end: install vanilla + Fabric, then launch and confirm the loader
// takes over. The vanilla client jar must be on the classpath for that, which
// is exactly the regression this guards.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/download_source.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/game_launcher.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/java_runtime_manager.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/loader_installer.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/minecraft_installer.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_chain.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_json.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_entry.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_settings.dart';

final bool _live = Platform.environment['HCL_LIVE'] == '1';

void main() {
  test('live: fabric launch finds the game', () async {
    final Directory root = Directory.systemTemp.createTempSync('hcl-fab-');
    addTearDown(() => root.deleteSync(recursive: true));

    // Install vanilla 1.20.1 explicitly, then Fabric on top of it.
    await MinecraftInstaller(
      root: root.path,
      mirror: DownloadMirror.official,
    ).installVanilla('1.20.1');

    final LoaderInstaller installer = LoaderInstaller(
      root: root.path,
      mirror: DownloadMirror.official,
    );
    final List<LoaderBuild> builds = await installer.listBuilds(
      LoaderKind.fabric,
      '1.20.1',
    );
    final LoaderInstallResult result = await installer.install(
      LoaderKind.fabric,
      '1.20.1',
      builds.first.loaderVersion,
    );

    final VersionJson version =
        (await loadVersionJson(root.path, result.versionId))!;
    final VersionChain? chain = await VersionChain.load(
      root.path,
      result.versionId,
    );
    expect(chain, isNotNull);
    expect(
      chain!.clientJars(root.path).any((String j) => j.contains('1.20.1.jar')),
      isTrue,
      reason: 'vanilla jar must be resolved through inheritsFrom',
    );

    final String java = await JavaRuntimeManager(
      root: root.path,
      mirror: DownloadMirror.official,
    ).download(version.javaVersion ?? 17);

    final LaunchPlan plan = GameLauncher.plan(
      version: version,
      entry: AppEntry(
        id: 'x',
        name: 'x',
        subtitle: '',
        description: '',
        kind: AppKind.minecraft,
        versionId: result.versionId,
        minecraftVersion: '1.20.1',
      ),
      settings: AppSettings.defaults(minecraftDir: root.path),
      account: null,
      minecraftRoot: root.path,
      gameDirectory: root.path,
      javaExecutable: java,
      memoryMb: 1024,
      extraJvmArguments: const <String>[],
      logPath: '${root.path}/logs/fabric.log',
      versionChain: chain,
    );

    final Process process = await GameLauncher.start(plan);
    final int code = await process.exitCode.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    final String log = File(plan.logPath).readAsStringSync();
    // ignore: avoid_print
    print('EXIT=$code');
    // ignore: avoid_print
    print('FABRIC_LINES=${log.split('\n').where((l) => l.toLowerCase().contains('fabric')).take(5).join(' | ')}');
    expect(log, isNot(contains("couldn't locate the game")));
  }, skip: !_live, timeout: const Timeout(Duration(minutes: 20)));
}
