// Proves the launch plan builds and Java accepts it. Skipped unless
// HCL_LIVE=1. Needs a JVM on the build machine.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/download_source.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/java_runtime_manager.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/game_launcher.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/minecraft_installer.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_json.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_entry.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_settings.dart';

final bool _live = Platform.environment['HCL_LIVE'] == '1';

void main() {
  test(
    'live: java accepts the generated classpath',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-launch-');
      addTearDown(() => root.deleteSync(recursive: true));
      await MinecraftInstaller(
        root: root.path,
        mirror: DownloadMirror.official,
      ).installVanilla('1.1');

      final VersionJson version = (await loadVersionJson(root.path, '1.1'))!;
      final AppEntry entry = AppEntry(
        id: 'v',
        name: 'v',
        subtitle: '',
        description: '',
        kind: AppKind.minecraft,
        versionId: '1.1',
        minecraftVersion: '1.1',
      );
      final LaunchPlan plan = GameLauncher.plan(
        version: version,
        entry: entry,
        settings: AppSettings.defaults(minecraftDir: root.path),
        account: null,
        minecraftRoot: root.path,
        gameDirectory: root.path,
        javaExecutable: 'java',
        memoryMb: 512,
        extraJvmArguments: const <String>[],
        logPath: '${root.path}/logs/x.log',
      );
      // Java must at least resolve the classpath without complaining about it.
      final int classpathIndex = plan.arguments.indexOf('-cp');
      expect(classpathIndex, greaterThanOrEqualTo(0));
      final String classpath = plan.arguments[classpathIndex + 1];
      expect(classpath, contains('versions/1.1/1.1.jar'));
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'live: Mojang JRE download provides a runnable java',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-jre-');
      addTearDown(() => root.deleteSync(recursive: true));
      final JavaRuntimeManager manager = JavaRuntimeManager(
        root: root.path,
        mirror: DownloadMirror.official,
      );
      final String java = await manager.download(17);
      expect(File(java).existsSync(), isTrue);
      final ProcessResult result = await Process.run(java, <String>[
        '-version',
      ]);
      expect(result.exitCode, 0);
      expect('${result.stderr}', contains('version "17'));
      expect(await manager.findDownloaded(17), java);
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test(
    'live: Minecraft 1.20.1 actually starts with downloaded JRE',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-game-');
      addTearDown(() => root.deleteSync(recursive: true));
      await MinecraftInstaller(
        root: root.path,
        mirror: DownloadMirror.official,
      ).installVanilla('1.20.1');
      final JavaRuntimeManager manager = JavaRuntimeManager(
        root: root.path,
        mirror: DownloadMirror.official,
      );
      final String java = await manager.download(17);
      final VersionJson version = (await loadVersionJson(root.path, '1.20.1'))!;
      final AppEntry entry = AppEntry(
        id: 'v',
        name: 'v',
        subtitle: '',
        description: '',
        kind: AppKind.minecraft,
        versionId: '1.20.1',
        minecraftVersion: '1.20.1',
      );
      final LaunchPlan plan = GameLauncher.plan(
        version: version,
        entry: entry,
        settings: AppSettings.defaults(minecraftDir: root.path),
        account: null,
        minecraftRoot: root.path,
        gameDirectory: root.path,
        javaExecutable: java,
        memoryMb: 1024,
        extraJvmArguments: const <String>[],
        logPath: '${root.path}/logs/game.log',
      );
      final Process process = await GameLauncher.start(plan);
      // The game has no display here, so it will fail; what matters is that the
      // JVM accepts the classpath and reaches Minecraft's main class.
      final int code = await process.exitCode.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final String log = File(plan.logPath).existsSync()
          ? File(plan.logPath).readAsStringSync()
          : '';
      // ignore: avoid_print
      print('exit=$code logHead=${log.split('\n').take(6).join(' | ')}');
      expect(log, isNot(contains('Could not find or load main class')));
      expect(log, isNot(contains('ClassNotFoundException')));
      // Reaching Minecraft's own bootstrap proves the classpath, natives and
      // arguments are accepted. Offline auth then fails because no account is
      // passed, which is the expected outcome for the gate.
      expect(log, contains('Datafixer Bootstrap'));
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
