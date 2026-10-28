import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants.dart';
import '../models/account.dart';
import '../models/app_entry.dart';
import '../models/app_settings.dart';
import 'launch_variables.dart';
import 'minecraft_installer.dart' show classpathFor;
import 'version_chain.dart';
import 'version_json.dart';

class LaunchException implements Exception {
  const LaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything needed to start Java, resolved ahead of time so the UI can show
/// errors before a window flashes.
class LaunchPlan {
  const LaunchPlan({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.logPath,
    required this.versionName,
    required this.minecraftVersion,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final String logPath;
  final String versionName;
  final String minecraftVersion;
}

/// Builds the JVM command line from a merged version JSON.
class GameLauncher {
  GameLauncher._();

  /// Default JVM flags Mojang's launcher adds on top of the version JSON.
  /// The placeholders are filled by [substituteVariables].
  static const List<String> defaultJvmFlags = <String>[
    r'-Djava.library.path=${natives_directory}',
    r'-Djna.tmpdir=${natives_directory}',
    r'-Dorg.lwjgl.system.SharedLibraryExtractPath=${natives_directory}',
    r'-Dio.netty.native.workdir=${natives_directory}',
    r'-Dminecraft.launcher.brand=${launcher_name}',
    r'-Dminecraft.launcher.version=${launcher_version}',
  ];

  static LaunchPlan plan({
    required VersionJson version,
    required AppEntry entry,
    required AppSettings settings,
    required MinecraftAccount? account,
    required String minecraftRoot,
    required String gameDirectory,
    required String javaExecutable,
    required int memoryMb,
    required List<String> extraJvmArguments,
    required String logPath,
    VersionChain? versionChain,
  }) {
    final String librariesRoot = p.join(minecraftRoot, 'libraries');
    final String assetsRoot = p.join(minecraftRoot, 'assets');
    final String nativesDir = p.join(
      minecraftRoot,
      'versions',
      version.id,
      'natives',
    );

    // Loader versions (Fabric/Forge/NeoForge) have no jar of their own; the
    // game classes come from the vanilla parent named by `inheritsFrom`.
    final List<String> jars = <String>[
      ...?versionChain?.clientJars(minecraftRoot),
    ];
    if (jars.isEmpty) {
      final String single = p.join(
        minecraftRoot,
        'versions',
        version.id,
        '${version.id}.jar',
      );
      if (File(single).existsSync()) jars.add(single);
    }
    final List<String> classpath = <String>[
      ...jars,
      ...classpathFor(version, minecraftRoot),
    ].where((String path) => File(path).existsSync()).toList();

    if (classpath.isEmpty) {
      throw LaunchException('版本 ${version.id} 缺少客户端 jar 和库文件，请重新安装。');
    }

    final bool legacy =
        version.id.contains('1.5.2') ||
        _legacyAssets(entry.minecraftVersion ?? version.id);
    final LaunchVariables variables = LaunchVariables(
      authPlayerName: account?.name ?? 'Steve',
      authUuid: account?.uuid ?? '',
      authAccessToken: account?.accessToken ?? '0',
      xuid: account?.xuid ?? '',
      userType: 'msa',
      versionType: version.type,
      gameDirectory: gameDirectory,
      assetsRoot: assetsRoot,
      assetsIndexName: version.assets,
      gameAssets: legacy
          ? p.join(assetsRoot, 'virtual', 'legacy', version.assets)
          : assetsRoot,
      libraryDirectory: librariesRoot,
      versionName: version.id,
      nativesDirectory: nativesDir,
      launcherName: AppInfo.name,
      launcherVersion: AppInfo.version,
      classpath: classpath.join(LaunchVariables.pathSeparator),
    );

    final List<String> jvm = <String>[
      '-Xmx${memoryMb}M',
      '-Xms${(memoryMb / 4).round().clamp(512, memoryMb)}M',
      if (Platform.isWindows) r'-Dfile.encoding=UTF-8',
      if (Platform.isMacOS) '-XstartOnFirstThread',
    ];
    final Map<String, String> jvmValues = <String, String>{
      ...variables.values,
      if (Platform.isWindows) ...<String, String>{
        'natives_directory': _escapeWindowsPath(variables.nativesDirectory),
        'classpath': _escapeWindowsPath(variables.classpath),
      },
    };

    if (version.jvmArguments.isNotEmpty) {
      // Modern version JSONs already carry every default flag, including
      // -Djava.library.path and -cp, so only fall back to the built-in set
      // when the list is missing them.
      final List<String> substituted = <String>[];
      for (final ArgumentEntry argument in version.jvmArguments) {
        if (!argument.matches()) continue;
        final String value = substituteVariables(argument.value, jvmValues);
        if (!substituted.contains(value)) substituted.add(value);
      }
      if (!substituted.any(
        (String arg) => arg.startsWith('-Djava.library.path='),
      )) {
        jvm.add('-Djava.library.path=${jvmValues['natives_directory']}');
      }
      if (!substituted.any((String arg) => arg.startsWith('-Djna.tmpdir='))) {
        jvm.add('-Djna.tmpdir=${jvmValues['natives_directory']}');
      }
      if (!substituted.contains('-cp') && !substituted.contains('-classpath')) {
        jvm
          ..add('-cp')
          ..add(jvmValues['classpath']!);
      }
      jvm.addAll(substituted);
    } else {
      for (final String flag in defaultJvmFlags) {
        jvm.add(substituteVariables(flag, jvmValues));
      }
      jvm
        ..add('-Djava.library.path=${jvmValues['natives_directory']}')
        ..add('-cp')
        ..add(jvmValues['classpath']!);
    }
    jvm.addAll(extraJvmArguments.where((String arg) => arg.trim().isNotEmpty));
    jvm.add(version.mainClass);

    final List<String> game = <String>[];
    if (version.gameArguments.isNotEmpty) {
      for (final ArgumentEntry argument in version.gameArguments) {
        if (!argument.matches(features: variables.features)) continue;
        game.add(substituteVariables(argument.value, variables.values));
      }
    } else if (version.legacyArguments != null) {
      for (final String token in _splitLegacyArguments(
        version.legacyArguments!,
      )) {
        game.add(substituteVariables(token, variables.values));
      }
    }
    // Older or hand-written version JSONs may omit these; add only what is
    // missing so modern JSONs stay untouched.
    void ensurePair(String flag, String value) {
      if (game.contains(flag)) return;
      game
        ..add(flag)
        ..add(value);
    }

    ensurePair('--username', variables.authPlayerName);
    ensurePair('--version', version.id);
    ensurePair('--gameDir', gameDirectory);
    ensurePair('--assetsDir', assetsRoot);
    ensurePair('--assetIndex', version.assets);
    ensurePair('--uuid', variables.authUuid);
    ensurePair('--accessToken', variables.authAccessToken);
    ensurePair('--userType', variables.userType);
    ensurePair('--versionType', version.type);

    return LaunchPlan(
      executable: javaExecutable,
      arguments: <String>[...jvm, ...game],
      workingDirectory: gameDirectory,
      logPath: logPath,
      versionName: version.id,
      minecraftVersion: entry.minecraftVersion ?? version.id,
    );
  }

  static bool _legacyAssets(String version) {
    // Assets moved from assets/virtual/legacy to assets/objects in 1.7.3.
    final List<int>? nums = RegExp(r'^1\.(\d+)')
        .firstMatch(version)
        ?.group(1)
        ?.split('')
        .map(int.parse)
        .toList();
    if (nums == null) return false;
    final int minor = nums.isEmpty ? 0 : nums.first;
    return minor < 7;
  }

  /// Legacy `minecraftArguments` is a whitespace-separated string with quoted
  /// values for paths that contain spaces.
  static List<String> _splitLegacyArguments(String raw) =>
      splitCommandLine(raw);

  /// Java parses `-Dkey=value` looking for backslash escapes, so Windows
  /// paths inside JVM properties must be doubled.
  static String _escapeWindowsPath(String value) =>
      value.replaceAll(r'\', r'\\');

  /// Starts the game. Returns the process so the caller can watch exit.
  static Future<Process> start(LaunchPlan plan) async {
    await Directory(p.dirname(plan.logPath)).create(recursive: true);
    final IOSink log = File(plan.logPath).openWrite();
    log.writeln(
      '${DateTime.now().toIso8601String()} 启动 ${plan.executable} '
      '（版本 ${plan.versionName}）',
    );
    final Process process = await Process.start(
      plan.executable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      environment: <String, String>{
        ...Platform.environment,
        // Modern versions expect UTF-8 stdout; Windows consoles default to GBK.
        'JAVA_TOOL_OPTIONS': '',
      },
      runInShell: false,
    );
    log.writeln(plan.arguments.join(' '));
    process.stdout.listen(
      (List<int> data) => log.add(data),
      onDone: () {},
      onError: (Object _) {},
    );
    process.stderr.listen(
      (List<int> data) => log.add(data),
      onDone: () {},
      onError: (Object _) {},
    );
    unawaitedClose(process, log);
    return process;
  }

  static void unawaitedClose(Process process, IOSink log) {
    unawaited(
      process.exitCode.then((int code) async {
        log.writeln('\n退出码 $code');
        await log.flush();
        await log.close();
      }),
    );
  }
}

/// Splits a command line on spaces, honouring double quotes. Used for JVM
/// arguments typed by the user and for legacy `minecraftArguments`.
List<String> splitCommandLine(String raw) {
  final List<String> result = <String>[];
  final StringBuffer current = StringBuffer();
  bool inQuotes = false;
  for (final int code in raw.runes) {
    final String char = String.fromCharCode(code);
    if (char == '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (char == ' ' && !inQuotes) {
      if (current.isNotEmpty) {
        result.add(current.toString());
        current.clear();
      }
      continue;
    }
    current.write(char);
  }
  if (current.isNotEmpty) result.add(current.toString());
  return result;
}
