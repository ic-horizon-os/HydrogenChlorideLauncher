import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/java_runtime.dart';
import '../utils/json_utils.dart';
import 'download_manager.dart';
import 'download_source.dart';

/// Resolves which Java binary can run a given Minecraft version.
///
/// Order: per-entry override -> launcher default path -> installed runtimes
/// that satisfy `javaVersion.majorVersion` -> Mojang-provided JRE (downloaded
/// on demand into `<root>/runtime/`).
class JavaRuntimeManager {
  JavaRuntimeManager({
    required this.root,
    required this.mirror,
    DownloadManager? downloader,
  }) : downloader = downloader ?? DownloadManager();

  final String root;
  final DownloadMirror mirror;
  final DownloadManager downloader;

  /// Candidates per required major, newest component first. Mojang rotates
  /// these names, so every known alias is tried.
  static const Map<int, List<String>> _componentsForMajor = <int, List<String>>{
    8: <String>['jre-legacy'],
    16: <String>['java-runtime-alpha'],
    17: <String>['java-runtime-beta', 'java-runtime-delta'],
    21: <String>['java-runtime-gamma', 'java-runtime-delta'],
  };

  static String platformKey() {
    if (Platform.isWindows) {
      return Platform.version.contains('arm64')
          ? 'windows-arm64'
          : 'windows-x64';
    }
    if (Platform.isMacOS) {
      return Platform.version.contains('arm64') ? 'mac-os-arm64' : 'mac-os';
    }
    return 'linux';
  }

  String get runtimeRoot => p.join(root, 'runtime');

  static String binaryName() => Platform.isWindows ? 'java.exe' : 'java';

  /// Picks from an already-scanned list.
  JavaRuntime? pickInstalled(
    List<JavaRuntime> runtimes, {
    String? override,
    String? defaultPath,
    int? requiredMajor,
  }) {
    JavaRuntime? byPath(String? path) {
      if (path == null || path.isEmpty) return null;
      for (final JavaRuntime runtime in runtimes) {
        if (runtime.path == path) return runtime;
      }
      return JavaRuntime(
        path: path,
        version: '',
        major: -1,
        vendor: '',
        arch: '',
        source: 'manual',
      );
    }

    final JavaRuntime? forced = byPath(override) ?? byPath(defaultPath);
    if (forced != null) return forced;
    final int major = requiredMajor ?? 0;
    if (major <= 0) return runtimes.isEmpty ? null : runtimes.first;

    // Prefer the closest matching major (Java 17 for a 17 requirement even if
    // 21 is installed), then fall back to the highest compatible one.
    final List<JavaRuntime> compatible =
        runtimes
            .where((JavaRuntime runtime) => _satisfies(runtime.major, major))
            .toList()
          ..sort((JavaRuntime a, JavaRuntime b) {
            final int diff = (a.major - major).abs() - (b.major - major).abs();
            return diff != 0 ? diff : b.major.compareTo(a.major);
          });
    return compatible.isEmpty ? null : compatible.first;
  }

  /// Whether a runtime of [actual] major can run a version requiring
  /// [required]. Old versions run fine on newer Java; new versions do not run
  /// on old Java.
  static bool _satisfies(int actual, int required) {
    if (actual <= 0) return false;
    if (actual < required) return false;
    // Java 8 and below are pinned; 9+ are generally interchangeable upward.
    if (required <= 8) return actual <= 22;
    return actual >= required;
  }

  /// Finds a downloaded Mojang runtime that satisfies [requiredMajor].
  Future<String?> findDownloaded(int requiredMajor) async {
    final Directory dir = Directory(runtimeRoot);
    if (!await dir.exists()) return null;
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! Directory) continue;
      final String name = p.basename(entity.path);
      final int dash = name.lastIndexOf('-');
      final int? major = dash < 0
          ? null
          : int.tryParse(name.substring(dash + 1));
      if (major == null || !_satisfies(major, requiredMajor)) continue;
      final String bin = p.join(entity.path, 'bin', binaryName());
      if (await File(bin).exists()) return bin;
    }
    return null;
  }

  /// Downloads Mojang's JRE component for [requiredMajor]. Returns the binary
  /// path, or throws when no component is published for the platform.
  Future<String> download(
    int requiredMajor, {
    void Function(String stage, double fraction)? onProgress,
  }) async {
    final List<String> components =
        _componentsForMajor[requiredMajor] ?? <String>['java-runtime-gamma'];
    onProgress?.call('获取 Java 运行时清单', 0.02);
    final Map<String, dynamic> all = await downloader.fetchJson(
      mirror.javaRuntimesUrl,
    );
    // Layout: { "<platform>": { "<component>": [ { manifest, version, ... } ] } }
    final Object? platformRaw = all[platformKey()];
    final Map<String, dynamic> platform = platformRaw is Map
        ? Map<String, dynamic>.from(platformRaw)
        : <String, dynamic>{};
    Map<String, dynamic>? platformEntry;
    String? component;
    for (final String name in components) {
      final Object? raw = platform[name];
      if (raw is! List) continue;
      for (final Object? item in raw) {
        if (item is Map && item['manifest'] is Map) {
          platformEntry = <String, dynamic>{
            for (final MapEntry<Object?, Object?> e in item.entries)
              '${e.key}': e.value,
          };
          component = name;
          break;
        }
      }
      if (platformEntry != null) break;
    }
    if (platformEntry == null) {
      throw Exception('Mojang 没有为当前平台发布 Java $requiredMajor。');
    }
    final Map<String, dynamic> manifestMeta = asMap(platformEntry['manifest']);
    final String manifestUrl = asString(manifestMeta['url']);
    if (manifestUrl.isEmpty) {
      throw Exception('Java 运行时清单缺少下载地址。');
    }
    onProgress?.call('读取 Java 运行时文件列表', 0.1);
    final Map<String, dynamic> manifest = await downloader.fetchJson(
      manifestUrl,
    );
    final String target = p.join(runtimeRoot, '$component-$requiredMajor');
    final List<DownloadRequest> files = <DownloadRequest>[];
    final Map<String, dynamic> filesJson = asMap(manifest['files']);
    for (final MapEntry<String, dynamic> entry in filesJson.entries) {
      final Map<String, dynamic> file = asMap(entry.value);
      if (asString(file['type']) == 'directory') continue;
      final Map<String, dynamic> raw = asMap(asMap(file['downloads'])['raw']);
      final String url = asString(raw['url']);
      if (url.isEmpty) continue;
      files.add(
        DownloadRequest(
          url: url,
          destination: p.joinAll(<String>[target, ...entry.key.split('/')]),
          sha1: asString(raw['sha1']),
          size: asInt(raw['size'], 0),
        ),
      );
    }
    if (files.isEmpty) {
      throw Exception('Java 运行时清单为空。');
    }
    onProgress?.call('下载 Java 运行时', 0.15);
    final DownloadBatchResult result = await downloader.run(
      files,
      onProgress: (DownloadProgress progress) {
        onProgress?.call('下载 Java 运行时', 0.15 + progress.fraction * 0.8);
      },
    );
    if (!result.ok) {
      throw Exception('Java 运行时下载失败：${result.failures.first.error}');
    }
    final File bin = File(p.join(target, 'bin', binaryName()));
    if (!await bin.exists()) {
      throw Exception('Java 运行时下载完成但缺少 bin/${binaryName()}。');
    }
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['+x', bin.path]);
    }
    onProgress?.call('完成', 1);
    return bin.path;
  }
}
