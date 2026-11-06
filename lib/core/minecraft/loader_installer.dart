import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'download_manager.dart';
import 'download_source.dart';
import 'minecraft_installer.dart';

enum LoaderKind { fabric, forge, neoforge, optifine }

extension LoaderKindLabel on LoaderKind {
  String get label {
    switch (this) {
      case LoaderKind.fabric:
        return 'Fabric';
      case LoaderKind.forge:
        return 'Forge';
      case LoaderKind.neoforge:
        return 'NeoForge';
      case LoaderKind.optifine:
        return 'OptiFine';
    }
  }

  String get slug {
    switch (this) {
      case LoaderKind.fabric:
        return 'fabric';
      case LoaderKind.forge:
        return 'forge';
      case LoaderKind.neoforge:
        return 'neoforge';
      case LoaderKind.optifine:
        return 'optifine';
    }
  }
}

class LoaderBuild {
  const LoaderBuild({
    required this.id,
    required this.loaderVersion,
    required this.gameVersion,
    this.channel = 'stable',
  });

  final String id;
  final String loaderVersion;
  final String gameVersion;
  final String channel;
}

class LoaderInstallResult {
  const LoaderInstallResult({
    required this.versionId,
    required this.loaderVersion,
    required this.gameVersion,
    required this.loader,
    this.warnings = const <String>[],
  });

  final String versionId;
  final String loaderVersion;
  final String gameVersion;
  final LoaderKind loader;
  final List<String> warnings;
}

/// Installs mod loaders into `<root>/versions/<id>/` by writing a version JSON
/// that inherits from the vanilla version, plus any loader-specific libraries.
class LoaderInstaller {
  LoaderInstaller({
    required this.root,
    required this.mirror,
    DownloadManager? downloader,
    MinecraftInstaller? vanillaInstaller,
  }) : downloader = downloader ?? DownloadManager(),
       vanilla =
           vanillaInstaller ?? MinecraftInstaller(root: root, mirror: mirror);

  final String root;
  final DownloadMirror mirror;
  final DownloadManager downloader;
  final MinecraftInstaller vanilla;

  static const String fabricMeta = 'https://meta.fabricmc.net/v2';
  static const String forgeMaven =
      'https://maven.minecraftforge.net/net/minecraftforge/forge';

  /// `promotions_slim.json` is served by the website host, not the maven root.
  static const String forgePromotions =
      'https://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json';
  static const String neoforgeMaven =
      'https://maven.neoforged.net/releases/net/neoforged/neoforge';

  Future<List<LoaderBuild>> listBuilds(
    LoaderKind loader,
    String gameVersion, {
    bool force = false,
  }) async {
    switch (loader) {
      case LoaderKind.fabric:
        return _fabricBuilds(gameVersion);
      case LoaderKind.forge:
        return _forgeBuilds(gameVersion);
      case LoaderKind.neoforge:
        return _neoforgeBuilds(gameVersion);
      case LoaderKind.optifine:
        return const <LoaderBuild>[];
    }
  }

  Future<List<LoaderBuild>> _fabricBuilds(String gameVersion) async {
    final Object? decoded = jsonDecode(
      utf8.decode(
        await downloader.fetchBytes('$fabricMeta/versions/loader/$gameVersion'),
      ),
    );
    if (decoded is! List) return const <LoaderBuild>[];
    return decoded
        .whereType<Map>()
        .map(
          (Map item) => LoaderBuild(
            id: '${item['loader']['version']}',
            loaderVersion: '${item['loader']['version']}',
            gameVersion: gameVersion,
            channel: '${item['loader']['stable']}' == 'true'
                ? 'stable'
                : 'unstable',
          ),
        )
        .toList(growable: false);
  }

  Future<List<LoaderBuild>> _forgeBuilds(String gameVersion) async {
    final Map<String, dynamic> promo = await downloader.fetchJson(
      forgePromotions,
    );
    final Map<String, dynamic> promos = promo['promos'] is Map
        ? Map<String, dynamic>.from(promo['promos'] as Map)
        : <String, dynamic>{};
    final String? latest = promos['$gameVersion-latest'] as String?;
    final String? recommended = promos['$gameVersion-recommended'] as String?;
    final Set<String> versions = <String>{?latest, ?recommended};
    // Recent builds listed in maven-metadata when the promo is missing.
    if (versions.isEmpty) {
      try {
        final String xml = utf8.decode(
          await downloader.fetchBytes(
            '$forgeMaven/maven-metadata.xml',
            timeoutOverride: const Duration(seconds: 60),
          ),
        );
        final String suffix = '-$gameVersion';
        for (final RegExpMatch match in RegExp(
          '<version>([^<]+)</version>',
        ).allMatches(xml)) {
          final String version = match.group(1)!;
          if (version.endsWith(suffix)) {
            versions.add(version.substring(0, version.length - suffix.length));
          }
        }
      } on Object {
        // Ignore: an empty list is reported by the UI.
      }
    }
    return versions
        .map(
          (String version) => LoaderBuild(
            id: '$gameVersion-$version',
            loaderVersion: version,
            gameVersion: gameVersion,
            channel: version == recommended ? 'recommended' : 'latest',
          ),
        )
        .toList(growable: false);
  }

  Future<List<LoaderBuild>> _neoforgeBuilds(String gameVersion) async {
    final Match? match = RegExp(r'^1\.(\d+)(?:\.(\d+))?')
        .firstMatch(gameVersion);
    if (match == null) return const <LoaderBuild>[];
    final int minor = int.parse(match.group(1)!);
    final int patch = match.group(2) == null ? 0 : int.parse(match.group(2)!);
    // NeoForge starts at Minecraft 1.20.2 and ships as
    // `neoforge/<minor>.<patch>.<build>` (e.g. 20.4.x, 21.1.x).
    if (minor < 20 || (minor == 20 && patch < 2)) {
      throw const InstallException('NeoForge 支持 Minecraft 1.20.2 及之后版本。');
    }
    final String prefix = '$minor.$patch.';
    final List<String> candidates = <String>[];
    // neoforged's maven can be unreachable from some networks. Try once with
    // a moderate timeout, then fail with an actionable message instead of
    // leaving the picker spinning.
    String xml;
    try {
      xml = utf8.decode(
        await downloader.fetchBytes(
          '$neoforgeMaven/maven-metadata.xml',
          retries: 1,
          timeoutOverride: const Duration(seconds: 20),
        ),
      );
    } on Object {
      throw const InstallException(
        '连不上 maven.neoforged.net，暂时无法获取 NeoForge 版本列表。'
        '请稍后重试或检查网络。',
      );
    }
    for (final RegExpMatch entry in RegExp(
      '<version>([^<]+)</version>',
    ).allMatches(xml)) {
      final String version = entry.group(1)!;
      if (!version.startsWith(prefix)) continue;
      if (version.contains('-beta')) continue;
      candidates.add(version);
    }
    if (candidates.isEmpty) {
      throw InstallException('没有找到 NeoForge $gameVersion 的可用构建。');
    }
    candidates.sort((String a, String b) => _compareVersions(b, a));
    return candidates
        .take(12)
        .map(
          (String version) => LoaderBuild(
            id: version,
            loaderVersion: version,
            gameVersion: gameVersion,
          ),
        )
        .toList(growable: false);
  }

  Future<LoaderInstallResult> install(
    LoaderKind loader,
    String gameVersion,
    String loaderVersion, {
    void Function(InstallProgress progress)? onProgress,
    String? javaExecutable,
  }) async {
    void report(String stage, double fraction, [String detail = '']) {
      onProgress?.call(
        InstallProgress(stage: stage, fraction: fraction, detail: detail),
      );
    }

    // The loader version JSON inherits from vanilla, so vanilla must exist.
    final File vanillaFile = File(
      p.join(root, 'versions', gameVersion, '$gameVersion.json'),
    );
    final bool installedVanilla = !await vanillaFile.exists();
    // The loader steps below report relative 0..1 fractions. Map them high
    // enough to sit above a vanilla phase that just ran, but near zero when
    // the vanilla version was already on disk.
    final double base = installedVanilla ? 0.58 : 0.03;
    void loaderReport(String stage, double fraction, [String detail = '']) {
      report(stage, base + fraction.clamp(0.0, 1.0) * (1 - base), detail);
    }

    if (installedVanilla) {
      report('安装原版 $gameVersion', 0.01);
      await vanilla.installVanilla(
        gameVersion,
        onProgress: (InstallProgress progress) {
          report('安装原版 $gameVersion', progress.fraction * 0.5, progress.detail);
        },
      );
    }

    switch (loader) {
      case LoaderKind.fabric:
        return _installFabric(gameVersion, loaderVersion, loaderReport);
      case LoaderKind.forge:
      case LoaderKind.neoforge:
        return _installForge(
          loader,
          gameVersion,
          loaderVersion,
          loaderReport,
          javaExecutable,
        );
      case LoaderKind.optifine:
        throw const InstallException('OptiFine 需要手动导入安装文件。');
    }
  }

  Future<LoaderInstallResult> _installFabric(
    String gameVersion,
    String loaderVersion,
    void Function(String, double, [String]) report,
  ) async {
    report('获取 Fabric 版本信息', 0.05);
    final Map<String, dynamic> json = await downloader.fetchJson(
      '$fabricMeta/versions/loader/$gameVersion/$loaderVersion/profile/json',
    );
    final String id = 'fabric-loader-$loaderVersion-$gameVersion';
    json['id'] = id;
    json['inheritsFrom'] = gameVersion;
    json['type'] = 'release';

    report('下载 Fabric 库文件', 0.15);
    final List<DownloadRequest> libraries = <DownloadRequest>[];
    for (final Map<String, dynamic> library
        in (json['libraries'] as List? ?? <Object?>[])
            .whereType<Map<String, dynamic>>()) {
      final String name = '${library['name']}';
      Map<String, dynamic> downloads = <String, dynamic>{};
      if (library['downloads'] is Map) {
        downloads = Map<String, dynamic>.from(library['downloads'] as Map);
      }
      final Map<String, dynamic> artifact = downloads['artifact'] is Map
          ? Map<String, dynamic>.from(downloads['artifact'] as Map)
          : <String, dynamic>{};
      final String url = artifact['url'] is String
          ? artifact['url'] as String
          : '${library['url'] ?? 'https://maven.fabricmc.net/'}'
                '${_mavenPath(name)}';
      final String path = artifact['path'] is String
          ? artifact['path'] as String
          : _mavenPath(name);
      if (!downloads.containsKey('artifact')) {
        downloads['artifact'] = <String, dynamic>{'url': url, 'path': path};
        library['downloads'] = downloads;
      }
      libraries.add(
        DownloadRequest(
          url: mirror.rewrite(url),
          destination: p.join(root, 'libraries', path),
          sha1: artifact['sha1'] is String ? artifact['sha1'] as String : null,
        ),
      );
    }
    final DownloadBatchResult result = await downloader.run(
      libraries,
      onProgress: (DownloadProgress progress) {
        report(
          '下载 Fabric 库文件',
          0.15 + progress.fraction * 0.8,
          progress.currentFile,
        );
      },
    );
    if (!result.ok) {
      throw InstallException('Fabric 库下载失败：${result.failures.first.error}');
    }

    final Directory dir = Directory(p.join(root, 'versions', id));
    await dir.create(recursive: true);
    final File file = File(p.join(dir.path, '$id.json'));
    await file.writeAsString(jsonEncode(json));
    report('完成', 1);
    return LoaderInstallResult(
      versionId: id,
      loaderVersion: loaderVersion,
      gameVersion: gameVersion,
      loader: LoaderKind.fabric,
    );
  }

  Future<LoaderInstallResult> _installForge(
    LoaderKind loader,
    String gameVersion,
    String loaderVersion,
    void Function(String, double, [String]) report,
    String? javaExecutable,
  ) async {
    final String java = javaExecutable ?? '';
    if (java.isEmpty) {
      throw const InstallException(
        '安装 Forge/NeoForge 需要可用的 Java，请先在 Java 设置中选择。',
      );
    }
    final bool neo = loader == LoaderKind.neoforge;
    final String fullVersion = neo
        ? loaderVersion
        : '$gameVersion-$loaderVersion';
    final String fileName = neo
        ? 'neoforge-$loaderVersion-installer.jar'
        : 'forge-$fullVersion-installer.jar';
    final String base = neo ? neoforgeMaven : forgeMaven;
    final String url = neo
        ? '$base/$loaderVersion/$fileName'
        : '$base/$gameVersion-$loaderVersion/$fileName';
    final String id = neo ? 'neoforge-$loaderVersion' : 'forge-$fullVersion';

    final Directory versionDir = Directory(p.join(root, 'versions', id));
    await versionDir.create(recursive: true);
    final File installerFile = File(p.join(versionDir.path, fileName));

    report('下载 ${loader.label} 安装器', 0.1);
    final DownloadBatchResult install = await downloader.run(<DownloadRequest>[
      DownloadRequest(url: url, destination: installerFile.path),
    ]);
    if (!install.ok) {
      throw InstallException(
        '${loader.label} 安装器下载失败（$url）：${install.failures.first.error}',
      );
    }

    // Forge/NeoForge refuse --installClient unless the root looks like a
    // launcher directory; create a minimal profile file if one is missing.
    final File profiles = File(p.join(root, 'launcher_profiles.json'));
    if (!await profiles.exists()) {
      await profiles.writeAsString(
        jsonEncode(<String, dynamic>{
          'profiles': <String, dynamic>{},
          'settings': <String, dynamic>{'enableSnapshots': false},
          'version': 3,
        }),
      );
    }

    // The installer jar drives its own output; hold a labelled plateau here
    // rather than a stale fraction.
    report('运行 ${loader.label} 安装器', 0.5);
    final DateTime installedSince = DateTime.now().subtract(
      const Duration(minutes: 5),
    );
    final Set<String> before = await _versionIds();
    final ProcessResult result = await Process.run(java, <String>[
      '-jar',
      installerFile.path,
      '--installClient',
      root,
    ], workingDirectory: root);
    final String output = '${result.stdout}\n${result.stderr}';
    if (result.exitCode != 0) {
      // Keep the installer's own log next to the version for support.
      final File installerLog = File(p.join(versionDir.path, 'installer.log'));
      await installerLog.writeAsString(output);
      final List<String> lines = output
          .split('\n')
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList(growable: false);
      throw InstallException(
        '${loader.label} 安装器退出码 ${result.exitCode}：'
        '${lines.skip(lines.length > 8 ? lines.length - 8 : 0).join(' | ')}'
        '（完整日志：${installerLog.path}）',
      );
    }

    report('读取安装结果', 0.92);
    final Set<String> after = await _versionIds();
    final Set<String> created = after.difference(before);
    final String? installedId = await _findInstalledForgeId(
      id,
      fullVersion,
      since: installedSince,
      preferred: created,
    );
    final List<String> warnings = <String>[];
    if (installedId == null) {
      warnings.add('安装器没有生成版本 JSON，请检查日志。');
    }

    report('完成', 1);
    return LoaderInstallResult(
      versionId: installedId ?? id,
      loaderVersion: loaderVersion,
      gameVersion: gameVersion,
      loader: loader,
      warnings: warnings,
    );
  }

  /// Version folder names currently on disk.
  Future<Set<String>> _versionIds() async {
    final Directory versions = Directory(p.join(root, 'versions'));
    if (!await versions.exists()) return <String>{};
    return <String>{
      for (final FileSystemEntity entity in versions.listSync())
        if (entity is Directory) p.basename(entity.path),
    };
  }

  Future<String?> _findInstalledForgeId(
    String expected,
    String fullVersion, {
    DateTime? since,
    Set<String> preferred = const <String>{},
  }) async {
    final Directory versions = Directory(p.join(root, 'versions'));
    if (!await versions.exists()) return null;
    final File exact = File(p.join(versions.path, expected, '$expected.json'));
    if (await exact.exists()) return expected;
    final List<String> matches = <String>[];
    for (final FileSystemEntity entity in versions.listSync()) {
      if (entity is! Directory) continue;
      final String name = p.basename(entity.path);
      if (!name.contains(fullVersion) && !name.contains(expected)) continue;
      final File json = File(p.join(entity.path, '$name.json'));
      if (!await json.exists()) continue;
      // Ignore stale versions from earlier attempts.
      if (since != null) {
        final DateTime modified = (await json.stat()).modified;
        if (modified.isBefore(since)) continue;
      }
      matches.add(name);
    }
    if (matches.isEmpty) return null;
    // Prefer folders that did not exist before the installer ran.
    final List<String> fresh = matches
        .where(preferred.contains)
        .toList(growable: false);
    if (fresh.isNotEmpty) {
      fresh.sort();
      return fresh.last;
    }
    matches.sort();
    return matches.last;
  }

  /// Installs OptiFine from a user-supplied jar. The jar is copied into
  /// `versions/<id>/` and its version JSON is extracted and re-pointed at the
  /// vanilla version.
  Future<LoaderInstallResult> installOptifineFromJar(
    File jar,
    String gameVersion, {
    void Function(InstallProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const InstallProgress(stage: '读取 OptiFine 安装文件', fraction: 0.3),
    );
    final List<int> bytes = await jar.readAsBytes();
    final Map<String, dynamic>? raw = readVersionJsonFromJar(bytes);
    if (raw == null) {
      throw const InstallException('无法在 jar 中找到版本 JSON，可能不是 OptiFine 安装文件。');
    }
    final String id = 'OptiFine-${'${raw['id']}'.replaceAll(' ', '-')}';
    raw['id'] = id;
    raw['inheritsFrom'] = gameVersion;
    final Directory dir = Directory(p.join(root, 'versions', id));
    await dir.create(recursive: true);
    await File(p.join(dir.path, '$id.json')).writeAsString(jsonEncode(raw));
    await jar.copy(p.join(dir.path, '$id.jar'));
    onProgress?.call(const InstallProgress(stage: '完成', fraction: 1));
    return LoaderInstallResult(
      versionId: id,
      loaderVersion: '${raw['id']}',
      gameVersion: gameVersion,
      loader: LoaderKind.optifine,
    );
  }

  static String _mavenPath(String coordinates) {
    final List<String> parts = coordinates.split(':');
    if (parts.length < 3) return coordinates;
    final String group = parts[0].replaceAll('.', '/');
    final String artifact = parts[1];
    final String version = parts[2];
    final String classifier = parts.length > 3 ? parts[3] : '';
    final String file = classifier.isEmpty
        ? '$artifact-$version.jar'
        : '$artifact-$version-$classifier.jar';
    return '$group/$artifact/$version/$file';
  }

  static int _compareVersions(String a, String b) {
    final List<int> left = a
        .split(RegExp('[.-]'))
        .map((String s) => int.tryParse(s) ?? 0)
        .toList();
    final List<int> right = b
        .split(RegExp('[.-]'))
        .map((String s) => int.tryParse(s) ?? 0)
        .toList();
    for (int i = 0; i < left.length && i < right.length; i++) {
      final int diff = left[i] - right[i];
      if (diff != 0) return diff;
    }
    return left.length - right.length;
  }
}

/// Extracts `version.json` (or the first version-shaped JSON) from an
/// installer jar. OptiFine stores it as `version.json` at the root.
Map<String, dynamic>? readVersionJsonFromJar(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on ArchiveException {
    return null;
  }
  Iterable<ArchiveFile> candidates() => archive.files.where(
    (ArchiveFile file) => file.isFile && file.name.endsWith('.json'),
  );
  final List<ArchiveFile> ordered = <ArchiveFile>[
    ...candidates().where((ArchiveFile file) => file.name == 'version.json'),
    ...candidates().where((ArchiveFile file) => file.name != 'version.json'),
  ];
  for (final ArchiveFile file in ordered) {
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(file.content as List<int>),
      );
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('mainClass') &&
          decoded.containsKey('libraries')) {
        return decoded;
      }
    } on Object {
      continue;
    }
  }
  return null;
}
