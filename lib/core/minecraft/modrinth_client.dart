import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/browse_item.dart';
import '../services/browse_repository.dart';
import '../utils/json_utils.dart';
import 'download_manager.dart';

/// A downloadable project version from Modrinth.
class ModrinthVersion {
  const ModrinthVersion({
    required this.id,
    required this.projectId,
    required this.name,
    required this.versionNumber,
    required this.gameVersions,
    required this.loaders,
    required this.downloadUrl,
    required this.fileName,
    required this.versionType,
    required this.datePublished,
    this.sha1,
  });

  factory ModrinthVersion.fromJson(Map<String, dynamic> json) {
    final List<Map<String, dynamic>> files = asMapList(json['files']);
    final Map<String, dynamic> primary = files.isEmpty
        ? <String, dynamic>{}
        : files.firstWhere(
            (Map<String, dynamic> file) => asBool(file['primary'], false),
            orElse: () => files.first,
          );
    final Map<String, dynamic> hashes = asMap(primary['hashes']);
    return ModrinthVersion(
      id: asString(json['id']),
      projectId: asString(json['project_id']),
      name: asString(json['name']),
      versionNumber: asString(json['version_number']),
      gameVersions: asStringList(json['game_versions']),
      loaders: asStringList(json['loaders']),
      downloadUrl: asString(primary['url']),
      fileName: asString(primary['filename']),
      versionType: asString(json['version_type'], 'release'),
      datePublished: asDateTime(json['date_published']),
      sha1: asStringOrNull(hashes['sha1']),
    );
  }

  final String id;
  final String projectId;
  final String name;
  final String versionNumber;
  final List<String> gameVersions;
  final List<String> loaders;
  final String downloadUrl;
  final String fileName;
  final String versionType;
  final DateTime? datePublished;
  final String? sha1;
}

/// Minimal Modrinth v2 API client with the required User-Agent (supplied by
/// [DownloadManager]) and paging through `offset`.
class ModrinthClient {
  ModrinthClient({DownloadManager? downloader})
    : _downloader = downloader ?? DownloadManager();

  static const String apiBase = 'https://api.modrinth.com/v2';
  static const String searchUrl = '$apiBase/search';

  final DownloadManager _downloader;

  static const Map<BrowseCategory, String> _projectType =
      <BrowseCategory, String>{
        BrowseCategory.mod: 'mod',
        BrowseCategory.modpack: 'modpack',
        BrowseCategory.shader: 'shader',
        // The loader tab lists loader-related mods through the mod index.
        BrowseCategory.loader: 'mod',
      };

  /// Maps a Modrinth search response onto [BrowseItem]s.
  List<BrowseItem> mapSearch(
    Map<String, dynamic> json,
    BrowseCategory category,
  ) {
    return asList(json['hits'])
        .whereType<Map>()
        .map((Map hit) => _mapHit(asMap(hit), category))
        .toList(growable: false);
  }

  Future<List<BrowseItem>> search({
    required BrowseCategory category,
    String query = '',
    String? loader,
    BrowseSort sort = BrowseSort.popular,
    int limit = 30,
    int offset = 0,
  }) async {
    final List<String> facets = <String>[
      'project_type:${_projectType[category] ?? 'mod'}',
    ];
    final String normalized = (loader ?? '').toLowerCase();
    if (const <String>[
      'fabric',
      'forge',
      'neoforge',
      'quilt',
      'optifine',
    ].contains(normalized)) {
      facets.add('categories:$normalized');
    }
    if (category == BrowseCategory.shader) facets.add('categories:iris');
    final String index = switch (sort) {
      BrowseSort.popular => 'downloads',
      BrowseSort.recent => 'newest',
      BrowseSort.name => 'relevance',
    };
    final Uri uri = Uri.https(
      'api.modrinth.com',
      '/v2/search',
      <String, String>{
        'query': query,
        'limit': '$limit',
        'offset': '$offset',
        'index': index,
        'facets': jsonEncode(<List<String>>[
          for (final String facet in facets) <String>[facet],
        ]),
      },
    );
    final Map<String, dynamic> json = await _downloader.fetchJson(
      uri.toString(),
    );
    return mapSearch(json, category);
  }

  BrowseItem _mapHit(Map<String, dynamic> json, BrowseCategory category) {
    final List<String> categories = asStringList(json['categories']);
    final List<String> loaders = categories
        .where(
          (String category) => const <String>[
            'fabric',
            'forge',
            'neoforge',
            'quilt',
            'optifine',
          ].contains(category),
        )
        .toList(growable: false);
    final int accent = _hashColor(asString(json['project_id']), 0xFF2E7D32);
    return BrowseItem(
      id: asString(json['project_id']),
      name: asString(json['title']),
      summary: asString(json['description']),
      description: asString(json['description']),
      author: asString(json['author']),
      category: category,
      loaders: loaders,
      downloads: asInt(json['downloads'], 0),
      followers: asInt(json['follows'], 0),
      updatedAt: asDateTime(json['date_modified']) ?? DateTime(1970),
      accentStartValue: accent,
      accentEndValue: _darken(accent),
      tags: categories
          .where((String tag) => !loaders.contains(tag))
          .take(3)
          .toList(growable: false),
      versions: asStringList(json['versions']).take(4).toList(growable: false),
      iconUrl: asStringOrNull(json['icon_url']),
      slug: asStringOrNull(json['slug']),
    );
  }

  /// Lists the project's versions, newest first, optionally filtered.
  Future<List<ModrinthVersion>> versions(
    String projectId, {
    String? gameVersion,
    String? loader,
  }) async {
    final Uri uri = Uri.https(
      'api.modrinth.com',
      '/v2/project/$projectId/version',
      <String, String>{
        if (gameVersion != null)
          'game_versions': jsonEncode(<String>[gameVersion]),
        if (loader != null && loader.isNotEmpty)
          'loaders': jsonEncode(<String>[loader.toLowerCase()]),
      },
    );
    final Object? decoded = jsonDecode(
      utf8.decode(await _downloader.fetchBytes(uri.toString())),
    );
    if (decoded is! List) return const <ModrinthVersion>[];
    return decoded
        .whereType<Map>()
        .map((Map item) => ModrinthVersion.fromJson(asMap(item)))
        .where((ModrinthVersion version) => version.downloadUrl.isNotEmpty)
        .toList(growable: false);
  }

  /// Picks the newest version that matches the instance; falls back to the
  /// newest overall so the caller can warn about a mismatch.
  static ModrinthVersion? pick(
    List<ModrinthVersion> versions, {
    String? gameVersion,
    String? loader,
  }) {
    if (versions.isEmpty) return null;
    for (final ModrinthVersion version in versions) {
      final bool gameOk =
          gameVersion == null ||
          gameVersion.isEmpty ||
          version.gameVersions.contains(gameVersion);
      final bool loaderOk =
          loader == null ||
          loader.isEmpty ||
          version.loaders.contains(loader.toLowerCase());
      if (gameOk && loaderOk) return version;
    }
    return versions.first;
  }

  /// Downloads [version] into [directory]. Returns the written file.
  Future<File> download(
    ModrinthVersion version,
    String directory, {
    void Function(String stage, double fraction)? onProgress,
  }) async {
    await Directory(directory).create(recursive: true);
    final DownloadRequest request = DownloadRequest(
      url: version.downloadUrl,
      destination: p.join(directory, version.fileName),
      sha1: version.sha1,
    );
    final DownloadBatchResult result = await _downloader.run(
      <DownloadRequest>[request],
      onProgress: (DownloadProgress progress) {
        onProgress?.call('下载 ${version.fileName}', progress.fraction);
      },
    );
    if (!result.ok) {
      throw Exception('下载失败：${result.failures.first.error}');
    }
    return File(request.destination);
  }

  static int _hashColor(String seed, int fallback) {
    if (seed.isEmpty) return fallback;
    int hash = 0;
    for (final int code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0xFFFFFF;
    }
    return 0xFF000000 |
        (((hash & 0xFF) * 0.5 + 60).round() << 16) |
        ((((hash >> 8) & 0xFF) * 0.5 + 60).round() << 8) |
        (((hash >> 16) & 0xFF) * 0.5 + 60).round();
  }

  static int _darken(int color) {
    final int r = (color >> 16) & 0xFF;
    final int g = (color >> 8) & 0xFF;
    final int b = color & 0xFF;
    return 0xFF000000 |
        (((r * 0.5).round() & 0xFF) << 16) |
        (((g * 0.5).round() & 0xFF) << 8) |
        ((b * 0.5).round() & 0xFF);
  }
}

/// Installs a `.mrpack` (Modrinth modpack) into a game directory.
class ModpackInstaller {
  ModpackInstaller({required this.downloader});

  final DownloadManager downloader;

  Future<ModpackManifest> readManifest(File pack) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await pack.readAsBytes());
    } on ArchiveException {
      throw const FormatException('无法解压整合包。');
    }
    final ArchiveFile? index = archive.findFile('modrinth.index.json');
    if (index == null) {
      throw const FormatException('整合包缺少 modrinth.index.json。');
    }
    final Object? decoded = jsonDecode(utf8.decode(index.content as List<int>));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('modrinth.index.json 格式错误。');
    }
    return ModpackManifest.fromJson(decoded, archive);
  }

  Future<ModpackManifest> install(
    File pack,
    String gameDirectory, {
    void Function(String stage, double fraction, String detail)? onProgress,
  }) async {
    onProgress?.call('读取整合包', 0.02, p.basename(pack.path));
    final ModpackManifest manifest = await readManifest(pack);
    final List<DownloadRequest> requests = manifest.files
        .map(
          (ModpackFile file) => DownloadRequest(
            url: file.downloads.first,
            destination: p.joinAll(<String>[
              gameDirectory,
              ...file.path.split('/'),
            ]),
            sha1: file.sha1,
          ),
        )
        .toList(growable: false);
    onProgress?.call('下载整合包内容', 0.1, '${requests.length} 个文件');
    final DownloadBatchResult result = await downloader.run(
      requests,
      onProgress: (DownloadProgress progress) {
        onProgress?.call(
          '下载整合包内容',
          0.1 + progress.fraction * 0.85,
          '${progress.completed}/${progress.total}',
        );
      },
    );
    if (!result.ok) {
      throw Exception('整合包文件下载失败：${result.failures.first.error}');
    }
    onProgress?.call('写入覆盖文件', 0.96, '');
    for (final ArchiveFile file in manifest.overrides) {
      if (!file.isFile) continue;
      final String relative = file.name
          .replaceFirst('overrides/', '')
          .replaceFirst('client-overrides/', '');
      if (relative.isEmpty) continue;
      final File target = File(p.join(gameDirectory, relative));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
    }
    onProgress?.call('完成', 1, '');
    return manifest;
  }
}

class ModpackManifest {
  const ModpackManifest({
    required this.name,
    required this.versionId,
    required this.minecraftVersion,
    required this.loaderId,
    required this.loaderKind,
    required this.files,
    required this.overrides,
  });

  factory ModpackManifest.fromJson(Map<String, dynamic> json, Archive archive) {
    final Map<String, dynamic> dependencies = asMap(json['dependencies']);
    final String? fabric = asStringOrNull(dependencies['fabric-loader']);
    final String? neo = asStringOrNull(dependencies['neoforge']);
    final String? forge = asStringOrNull(dependencies['forge']);
    return ModpackManifest(
      name: asString(json['name']),
      versionId: asString(json['versionId']),
      minecraftVersion: asString(dependencies['minecraft']),
      loaderId: fabric ?? neo ?? forge ?? '',
      loaderKind: fabric != null
          ? 'fabric'
          : neo != null
          ? 'neoforge'
          : forge != null
          ? 'forge'
          : '',
      files: asMapList(json['files'])
          .map(
            (Map<String, dynamic> file) => ModpackFile(
              path: asString(file['path']),
              downloads: asStringList(file['downloads']),
              sha1: asStringOrNull(asMap(file['hashes'])['sha1']),
            ),
          )
          .where(
            (ModpackFile file) =>
                file.path.isNotEmpty && file.downloads.isNotEmpty,
          )
          .toList(growable: false),
      overrides: archive.files
          .where(
            (ArchiveFile file) =>
                file.name.startsWith('overrides/') ||
                file.name.startsWith('client-overrides/'),
          )
          .toList(growable: false),
    );
  }

  final String name;
  final String versionId;
  final String minecraftVersion;
  final String loaderId;
  final String loaderKind;
  final List<ModpackFile> files;
  final List<ArchiveFile> overrides;
}

class ModpackFile {
  const ModpackFile({required this.path, required this.downloads, this.sha1});

  final String path;
  final List<String> downloads;
  final String? sha1;
}
