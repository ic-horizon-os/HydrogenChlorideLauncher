import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../config/app_paths.dart';
import '../minecraft/game_launcher.dart';
import '../minecraft/java_runtime_manager.dart';
import '../minecraft/version_chain.dart';
import '../minecraft/version_json.dart';
import '../models/account.dart';
import '../models/app_entry.dart';
import '../models/app_settings.dart';
import '../models/java_runtime.dart';
import '../models/play_session.dart';
import 'library_store.dart';
import 'stats_service.dart';
import 'version_isolation.dart';

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();

  @override
  String toString() => '需要先登录 Microsoft 账户才能启动 Minecraft。';
}

class MissingVersionException implements Exception {
  const MissingVersionException(this.versionId, this.root);

  final String versionId;
  final String root;

  @override
  String toString() => '找不到版本 $versionId 的版本文件，请先在「版本管理」中安装。';
}

/// Snapshot passed into [LaunchService.start] so the service never reaches
/// back into UI state.
class LaunchContext {
  const LaunchContext({
    required this.settings,
    required this.account,
    required this.javaRuntimes,
    required this.javaManagerFor,
  });

  final AppSettings settings;
  final MinecraftAccount? account;
  final List<JavaRuntime> javaRuntimes;

  /// Builds a manager rooted at the given `.minecraft` directory.
  final JavaRuntimeManager Function(String root) javaManagerFor;
}

/// Starts the real Java process, tracks its lifetime, and records playtime
/// and sessions when it exits.
class LaunchService extends ChangeNotifier {
  LaunchService({
    required this.library,
    required this.stats,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryStore library;
  final StatsService stats;
  final DateTime Function() _clock;

  AppEntry? _activeApp;
  DateTime? _startedAt;
  Process? _process;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  bool _starting = false;
  bool _disposed = false;
  bool _stopping = false;
  int? _lastExitCode;
  String? _logPath;
  String? _launchError;

  AppEntry? get activeApp => _activeApp;
  DateTime? get startedAt => _startedAt;
  Duration get elapsed => _elapsed;
  bool get isStarting => _starting;
  int? get lastExitCode => _lastExitCode;
  String? get logPath => _logPath;
  String? get launchError => _launchError;

  bool isRunning(String id) => _activeApp?.id == id;

  bool get hasActiveProcess => _process != null;

  /// Starts [entry]. Minecraft entries need a logged-in account and a real
  /// version on disk; custom entries spawn their configured executable.
  Future<void> start(
    AppEntry entry, {
    required bool authenticated,
    LaunchContext? context,
    void Function(String stage, double fraction)? onProgress,
  }) async {
    if (_activeApp != null || _starting) {
      throw StateError('已有应用正在运行，请先停止当前应用。');
    }
    if (entry.isMinecraft && !authenticated) {
      throw const NotAuthenticatedException();
    }

    _starting = true;
    _launchError = null;
    _lastExitCode = null;
    _logPath = null;
    notifyListeners();

    late final Process process;
    try {
      if (entry.isMinecraft) {
        final LaunchContext ctx =
            context ?? (throw const LaunchException('缺少启动上下文。'));
        process = await _startMinecraft(entry, ctx, onProgress);
      } else {
        process = await _startCustom(entry);
      }
    } on Object catch (error) {
      _starting = false;
      _launchError = error.toString();
      notifyListeners();
      rethrow;
    }

    _process = process;
    _activeApp = entry;
    _startedAt = _clock();
    _elapsed = Duration.zero;
    _starting = false;
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final DateTime? started = _startedAt;
      if (started == null || _disposed) {
        timer.cancel();
        return;
      }
      _elapsed = _clock().difference(started);
      notifyListeners();
    });
    notifyListeners();

    unawaited(
      process.exitCode.then((int code) {
        _lastExitCode = code;
        return _finish(entry);
      }),
    );
  }

  Future<Process> _startMinecraft(
    AppEntry entry,
    LaunchContext context,
    void Function(String stage, double fraction)? onProgress,
  ) async {
    final AppSettings settings = context.settings;
    final String root = minecraftRoot(settings);
    final String versionId = versionIdOf(entry);
    final VersionJson? version = await loadVersionJson(root, versionId);
    if (version == null) {
      throw MissingVersionException(versionId, root);
    }

    final String java = await _resolveJava(
      entry: entry,
      version: version,
      context: context,
      root: root,
      onProgress: onProgress,
    );

    await VersionIsolation.ensure(entry, settings);
    final String gameDir = VersionIsolation.instanceDir(entry, settings);
    await Directory(gameDir).create(recursive: true);
    final String stamp = _clock().toIso8601String().replaceAll(
      RegExp('[:.]'),
      '-',
    );
    final String logPath = p.join(gameDir, 'logs', 'hcl-launch-$stamp.log');
    _logPath = logPath;
    final VersionChain? chain = await VersionChain.load(root, versionId);

    final LaunchPlan plan = GameLauncher.plan(
      version: version,
      entry: entry,
      settings: settings,
      account: context.account,
      minecraftRoot: root,
      gameDirectory: gameDir,
      javaExecutable: java,
      memoryMb: entry.memoryMbOverride ?? settings.defaultMemoryMb,
      extraJvmArguments: splitArguments(
        entry.jvmArgsOverride ?? settings.defaultJvmArgs,
      ),
      logPath: logPath,
      versionChain: chain,
    );
    return GameLauncher.start(plan);
  }

  Future<String> _resolveJava({
    required AppEntry entry,
    required VersionJson version,
    required LaunchContext context,
    required String root,
    void Function(String stage, double fraction)? onProgress,
  }) async {
    final AppSettings settings = context.settings;
    final JavaRuntimeManager manager = context.javaManagerFor(root);
    final int required = version.javaVersion ?? 8;

    String? override = entry.javaPathOverride?.trim();
    if (override != null && override.isNotEmpty) {
      if (await File(override).exists()) return override;
      throw LaunchException('条目指定的 Java 不存在：$override');
    }
    final String? defaultPath = settings.defaultJavaPath?.trim();
    if (defaultPath != null &&
        defaultPath.isNotEmpty &&
        await File(defaultPath).exists()) {
      return defaultPath;
    }
    final JavaRuntime? installed = manager.pickInstalled(
      context.javaRuntimes,
      requiredMajor: required,
    );
    if (installed != null) return installed.path;

    final String? downloaded = await manager.findDownloaded(required);
    if (downloaded != null) return downloaded;

    if (!settings.autoDownloadJava) {
      throw LaunchException(
        '版本 ${version.id} 需要 Java $required，本机没有匹配的运行时。'
        '请在「Java 设置」中指定，或开启自动下载 Java。',
      );
    }
    onProgress?.call('准备 Java 运行时', 0.1);
    return manager.download(
      required,
      onProgress: (String stage, double fraction) =>
          onProgress?.call(stage, fraction),
    );
  }

  Future<Process> _startCustom(AppEntry entry) async {
    final String executable = (entry.executablePath ?? '').trim();
    if (executable.isEmpty) {
      throw const LaunchException('该条目没有设置可执行文件路径。');
    }
    final String configured = (entry.workingDir ?? '').trim();
    final String workingDirectory = configured.isEmpty
        ? p.dirname(executable)
        : configured;
    return Process.start(
      executable,
      splitArguments(entry.arguments ?? ''),
      workingDirectory: workingDirectory,
    );
  }

  static String minecraftRoot(AppSettings settings) =>
      settings.minecraftDirs.isNotEmpty
      ? settings.minecraftDirs.first
      : AppPaths.defaultMinecraftDir();

  static String versionIdOf(AppEntry entry) =>
      entry.versionId ?? VersionIsolation.versionFolderName(entry);

  /// Splits a command line on spaces, honouring double quotes.
  static List<String> splitArguments(String raw) => splitCommandLine(raw);

  Future<void> _finish(AppEntry entry) async {
    final DateTime started = _startedAt ?? _clock();
    final Duration duration = _clock().difference(started);
    final int seconds = max(1, duration.inSeconds);
    _ticker?.cancel();
    _ticker = null;
    _process = null;
    _activeApp = null;
    _startedAt = null;
    _elapsed = Duration.zero;
    _starting = false;
    _stopping = false;
    if (_disposed) return;
    notifyListeners();

    if (entry.trackPlaytime && seconds >= 1) {
      await library.recordPlaytime(
        entry.id,
        duration: Duration(seconds: seconds),
        startedAt: started,
      );
      await stats.record(
        PlaySession(
          appId: entry.id,
          appName: entry.name,
          kind: entry.kind.name,
          startedAt: started,
          durationSeconds: seconds,
          loader: entry.loader,
          minecraftVersion: entry.minecraftVersion,
          isDemo: entry.isDemo,
        ),
      );
    }
    notifyListeners();
  }

  /// Asks the game to close. `_finish` runs when the process actually exits,
  /// so the recorded session length is the real playtime.
  Future<void> stop() async {
    final Process? process = _process;
    if (process == null || _stopping) return;
    _stopping = true;
    notifyListeners();
    // Minecraft handles SIGTERM as a clean shutdown on Linux/macOS.
    process.kill();
    unawaited(
      Future<void>.delayed(const Duration(seconds: 10), () {
        if (_process == null) return;
        // Still alive after ten seconds: force it.
        process.kill(ProcessSignal.sigkill);
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
