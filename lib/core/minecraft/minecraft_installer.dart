import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'download_manager.dart';
import 'download_source.dart';
import 'version_json.dart';
import 'version_manifest.dart';

/// Progress reported by [MinecraftInstaller]. [stage] is a short Chinese
/// label shown under the progress bar.
class InstallProgress {
  const InstallProgress({
    required this.stage,
    required this.fraction,
    this.detail = '',
  });

  final String stage;
  final double fraction;
  final String detail;
}

class InstallException implements Exception {
  const InstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads and lays out a vanilla Minecraft version under a `.minecraft`
/// root: version JSON + client jar, libraries, natives and asset objects.
class MinecraftInstaller {
  MinecraftInstaller({
    required this.root,
    required this.mirror,
    DownloadManager? downloader,
  }) : downloader = downloader ?? DownloadManager();

  final String root;
  final DownloadMirror mirror;
  final DownloadManager downloader;

  /// Manifest cache keeps the versions pane from hammering Mojang.
  VersionManifest? _manifestCache;
  DateTime? _manifestFetchedAt;
  static const Duration _manifestTtl = Duration(minutes: 30);

  Future<VersionManifest> fetchManifest({bool force = false}) async {
    final VersionManifest? cached = _manifestCache;
    final DateTime? fetched = _manifestFetchedAt;
    if (!force &&
        cached != null &&
        fetched != null &&
        DateTime.now().difference(fetched) < _manifestTtl) {
      return cached;
    }
    final Map<String, dynamic> json = await downloader.fetchJson(
      mirror.manifestUrl,
    );
    final VersionManifest manifest = VersionManifest.fromJson(json);
    _manifestCache = manifest;
    _manifestFetchedAt = DateTime.now();
    return manifest;
  }

  /// Installs [versionId] and returns the path of the written version JSON.
  Future<String> installVanilla(
    String versionId, {
    void Function(InstallProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    void report(String stage, double fraction, [String detail = '']) {
      onProgress?.call(
        InstallProgress(stage: stage, fraction: fraction, detail: detail),
      );
    }

    report('获取版本清单', 0.02);
    final VersionManifest manifest = await fetchManifest();
    final VersionManifestEntry? entry = manifest.find(versionId);
    if (entry == null) {
      throw InstallException('版本清单中没有 $versionId。');
    }

    report('读取版本 JSON', 0.05);
    final Map<String, dynamic> versionRaw = await downloader.fetchJson(
      mirror.rewrite(entry.url),
    );
    final VersionJson version = VersionJson.fromJson(versionRaw);
    if (version.mainClass.isEmpty) {
      throw InstallException('$versionId 的版本 JSON 缺少 mainClass。');
    }

    final Directory versionDir = Directory(p.join(root, 'versions', versionId));
    await versionDir.create(recursive: true);
    final File versionFile = File(p.join(versionDir.path, '$versionId.json'));
    await versionFile.writeAsString(jsonEncode(versionRaw));

    final List<DownloadRequest> libraryRequests = <DownloadRequest>[];
    final List<DownloadRequest> nativeRequests = <DownloadRequest>[];
    final String librariesRoot = p.join(root, 'libraries');

    for (final LibraryEntry library in version.libraries) {
      if (!library.applies()) continue;
      final DownloadInfo? artifact = library.artifact;
      if (artifact != null && artifact.isValid) {
        libraryRequests.add(
          DownloadRequest(
            url: mirror.rewrite(artifact.url),
            destination: p.join(
              librariesRoot,
              artifact.path.isNotEmpty ? artifact.path : library.inferredPath,
            ),
            sha1: artifact.sha1,
            size: artifact.size,
          ),
        );
      } else if (artifact == null && library.url.isNotEmpty) {
        // Fabric/NeoForge style: only a maven base URL + coordinates.
        libraryRequests.add(
          DownloadRequest(
            url:
                '${library.url.endsWith('/') ? library.url : '${library.url}/'}'
                '${library.inferredPath}',
            destination: p.join(librariesRoot, library.inferredPath),
          ),
        );
      }
      final String? classifierKey = library.nativeClassifier();
      if (classifierKey != null) {
        final DownloadInfo? native = library.classifiers[classifierKey];
        if (native != null && native.isValid) {
          nativeRequests.add(
            DownloadRequest(
              url: mirror.rewrite(native.url),
              destination: p.join(
                librariesRoot,
                native.path.isNotEmpty ? native.path : library.inferredPath,
              ),
              sha1: native.sha1,
              size: native.size,
            ),
          );
        }
      }
    }

    final DownloadInfo? client = version.client;
    if (client != null && client.isValid) {
      libraryRequests.add(
        DownloadRequest(
          url: mirror.rewrite(client.url),
          destination: p.join(versionDir.path, '$versionId.jar'),
          sha1: client.sha1,
          size: client.size,
        ),
      );
    }

    report('下载客户端与库文件', 0.1, '${libraryRequests.length} 个文件');
    final DownloadBatchResult libraryResult = await downloader.run(
      libraryRequests,
      isCancelled: isCancelled,
      onProgress: (DownloadProgress progress) {
        report(
          '下载客户端与库文件',
          0.1 + progress.fraction * 0.45,
          '${progress.completed}/${progress.total} · ${progress.currentFile}',
        );
      },
    );
    if (!libraryResult.ok) {
      throw InstallException('下载失败：${libraryResult.failures.first.error}');
    }

    if (nativeRequests.isNotEmpty) {
      report('解压 natives', 0.56, '${nativeRequests.length} 个压缩包');
      final DownloadBatchResult nativeResult = await downloader.run(
        nativeRequests,
        isCancelled: isCancelled,
        onProgress: (DownloadProgress progress) {
          report(
            '下载 natives',
            0.55 + progress.fraction * 0.05,
            progress.currentFile,
          );
        },
      );
      if (!nativeResult.ok) {
        throw InstallException(
          'natives 下载失败：${nativeResult.failures.first.error}',
        );
      }
      final Directory nativesDir = Directory(
        p.join(versionDir.path, 'natives'),
      );
      await nativesDir.create(recursive: true);
      for (final DownloadRequest request in nativeRequests) {
        await extractNatives(
          File(request.destination),
          nativesDir,
          excluded: <String>['META-INF/'],
        );
      }
    }

    final DownloadInfo? assetIndex = version.assetIndex;
    if (assetIndex != null && assetIndex.isValid) {
      report('下载资源索引', 0.62);
      final File indexFile = File(
        p.join(root, 'assets', 'indexes', '${version.assets}.json'),
      );
      await indexFile.parent.create(recursive: true);
      await downloader.run(<DownloadRequest>[
        DownloadRequest(
          url: mirror.rewrite(assetIndex.url),
          destination: indexFile.path,
          sha1: assetIndex.sha1,
        ),
      ], isCancelled: isCancelled);
      final Map<String, dynamic> indexJson = await readJsonFile(indexFile);
      final List<DownloadRequest> assets = <DownloadRequest>[];
      final Directory objectsDir = Directory(p.join(root, 'assets', 'objects'));
      final Object? objects = indexJson['objects'];
      if (objects is Map) {
        for (final Object? value in objects.values) {
          if (value is! Map) continue;
          final String hash = '${value['hash']}';
          if (hash.length < 3) continue;
          assets.add(
            DownloadRequest(
              url: mirror.rewrite(DownloadMirror.assetObjectUrl(hash)),
              destination: p.join(objectsDir.path, hash.substring(0, 2), hash),
              sha1: hash,
              size: (value['size'] as num?)?.toInt(),
            ),
          );
        }
      }
      report('下载资源文件', 0.64, '${assets.length} 个对象');
      final DownloadBatchResult assetResult = await downloader.run(
        assets,
        isCancelled: isCancelled,
        onProgress: (DownloadProgress progress) {
          report(
            '下载资源文件',
            0.64 + progress.fraction * 0.34,
            '${progress.completed}/${progress.total}',
          );
        },
      );
      if (!assetResult.ok) {
        throw InstallException('资源下载失败：${assetResult.failures.first.error}');
      }
      await writeLegacyAssetsIfNeeded(
        root: root,
        assetsIndexName: version.assets,
        indexJson: indexJson,
      );
    }

    report('完成', 1);
    return versionFile.path;
  }
}

/// Extracts jar-style archives, skipping directory entries and META-INF.
Future<void> extractNatives(
  File archive,
  Directory target, {
  List<String> excluded = const <String>[],
}) async {
  final List<int> bytes = await archive.readAsBytes();
  final Archive content;
  try {
    content = ZipDecoder().decodeBytes(bytes);
  } on ArchiveException {
    return;
  }
  for (final ArchiveFile file in content.files) {
    if (!file.isFile) continue;
    final String name = file.name.replaceAll(r'\', '/');
    if (excluded.any(name.startsWith)) continue;
    if (name.endsWith('.dll') ||
        name.endsWith('.so') ||
        name.endsWith('.dylib') ||
        name.endsWith('.jnilib') ||
        name.endsWith('.exe')) {
      final File out = File(p.join(target.path, p.basename(name)));
      await out.writeAsBytes(file.content);
    }
  }
}

Future<Map<String, dynamic>> readJsonFile(File file) async {
  final Object? decoded = jsonDecode(await file.readAsString());
  if (decoded is Map<String, dynamic>) return decoded;
  throw InstallException('${file.path} 不是 JSON 对象。');
}

/// Some pre-1.6 versions (and a few resource index names) expect a
/// `assets/<assetName>/` tree with hashed subfolders. Modern versions ignore
/// this; we only materialise it for indexes flagged `virtual`.
Future<void> writeLegacyAssetsIfNeeded({
  required String root,
  required String assetsIndexName,
  required Map<String, dynamic> indexJson,
}) async {
  if (indexJson['virtual'] != true) return;
  final Directory virtualDir = Directory(
    p.join(root, 'assets', 'virtual', 'legacy', assetsIndexName),
  );
  await virtualDir.create(recursive: true);
  final Object? objects = indexJson['objects'];
  if (objects is! Map) return;
  for (final MapEntry<Object?, Object?> entry in objects.entries) {
    if (entry.value is! Map) continue;
    final String hash = '${(entry.value as Map)['hash']}';
    final File source = File(
      p.join(root, 'assets', 'objects', hash.substring(0, 2), hash),
    );
    if (!await source.exists()) continue;
    final File target = File(p.join(virtualDir.path, '${entry.key}'));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }
}

/// Convenience for launch: resolves the classpath entries for [version].
List<String> classpathFor(VersionJson version, String root) {
  final List<String> entries = <String>[];
  for (final LibraryEntry library in version.libraries) {
    if (!library.applies()) continue;
    if (library.natives.keys.isNotEmpty) continue;
    final DownloadInfo? artifact = library.artifact;
    final String relative = artifact != null && artifact.path.isNotEmpty
        ? artifact.path
        : library.inferredPath;
    entries.add(p.join(root, 'libraries', relative));
  }
  return entries;
}

/// Small alignment helper so the install UI can show the resolved main class.
String describeVersion(VersionJson version) =>
    '${version.id} · ${version.mainClass}';
