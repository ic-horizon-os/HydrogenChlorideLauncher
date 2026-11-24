import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/app_paths.dart';
import '../minecraft/download_manager.dart';

/// Downloads and caches the official Minecraft key art used as the library
/// banner instead of drawing a placeholder.
///
/// The source is the "Minecraft: Java & Bedrock" cover published by
/// minecraft.net's content DAM, the same file the official site serves.
class CoverArtService {
  CoverArtService({required this.paths, DownloadManager? downloader})
    : _downloader = downloader ?? DownloadManager();

  static const String officialKeyArtUrl =
      'https://www.minecraft.net/content/dam/minecraftnet/games/minecraft/key-art/'
      'Homepage_Discover-our-games_MC-Vanilla-KeyArt_864x864.jpg';

  final AppPaths paths;
  final DownloadManager _downloader;

  Future<String>? _pending;
  String? _path;
  bool _probed = false;

  File get cacheFile =>
      File(p.join(paths.dataDir.path, 'covers', 'java-bedrock.jpg'));

  /// Path of the cached key art, or null while it is not on disk. Kept in
  /// memory on purpose: hero builds read this every frame, and probing the
  /// filesystem from build used to put sync disk I/O on the UI thread.
  String? get cachedPath => _path;

  /// Downloads the cover the first time it is missing. Repeated calls share
  /// one in-flight request; a failed download throws so callers can fall back.
  Future<String> ensure() {
    final String? resolved = _path;
    if (resolved != null) return Future<String>.value(resolved);
    return _pending ??= _probeAndDownload().whenComplete(() => _pending = null);
  }

  Future<String> _probeAndDownload() async {
    if (!_probed) {
      _probed = true;
      if (await cacheFile.exists()) {
        _path = cacheFile.path;
        return _path!;
      }
    }
    return _download();
  }

  Future<String> _download() async {
    await cacheFile.parent.create(recursive: true);
    final DownloadBatchResult result = await _downloader.run(<DownloadRequest>[
      DownloadRequest(url: officialKeyArtUrl, destination: cacheFile.path),
    ]);
    if (!result.ok) {
      throw result.failures.first.error;
    }
    _path = cacheFile.path;
    return _path!;
  }

  /// Path from the most recent successful [ensure], if any.
  String? get resolvedPath => _path;
}
