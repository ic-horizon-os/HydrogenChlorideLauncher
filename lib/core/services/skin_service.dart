import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../minecraft/download_manager.dart';

/// A skin texture pulled from Mojang, plus the arm model it declares.
class FetchedSkin {
  const FetchedSkin({required this.file, required this.model});

  final File file;

  /// `classic` (4px arms) or `slim` (3px arms), from the texture metadata.
  final String model;
}

/// Fetches player skins from the public Mojang endpoints and caches the
/// PNGs under `<data>/skins/remote/`. Applying a skin goes through
/// [MicrosoftAuthService.uploadSkin]; this service only resolves textures.
class SkinService {
  SkinService({required this.downloader, required this.dataDir});

  final DownloadManager downloader;
  final Directory dataDir;

  static const String _profileByNameUrl =
      'https://api.mojang.com/users/profiles/minecraft';
  static const String _sessionProfileUrl =
      'https://sessionserver.mojang.com/session/minecraft/profile';

  Directory get _remoteDir => Directory(p.join(dataDir.path, 'skins', 'remote'));

  /// The locally cached texture for [uuid], or null when never fetched.
  File? cachedSkin(String uuid) {
    final File file = File(p.join(_remoteDir.path, '${_flat(uuid)}.png'));
    return file.existsSync() ? file : null;
  }

  /// The logged-in player's current profile skin.
  Future<FetchedSkin> fetchOwnSkin({
    required String uuid,
    required String name,
  }) => fetchPlayerSkin(uuid: uuid, fallbackName: name);

  /// The active skin of the player named [username].
  Future<FetchedSkin> fetchUserSkin(String username) async {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) {
      throw const SkinException('请输入玩家名。');
    }
    if (!RegExp(r'^[A-Za-z0-9_]{3,16}$').hasMatch(trimmed)) {
      throw const SkinException('玩家名格式不正确。');
    }
    final List<int> raw = await downloader.fetchBytes(
      '$_profileByNameUrl/$trimmed',
    );
    final Object? decoded = raw.isEmpty
        ? null
        : jsonDecode(utf8.decode(raw));
    if (decoded is! Map || decoded['id'] is! String) {
      throw SkinException('没有找到玩家 $trimmed。');
    }
    return fetchPlayerSkin(uuid: decoded['id'] as String, fallbackName: trimmed);
  }

  /// Resolves [uuid] through the session server and downloads the SKIN
  /// texture it declares.
  Future<FetchedSkin> fetchPlayerSkin({
    required String uuid,
    required String fallbackName,
  }) async {
    final String flat = _flat(uuid);
    final List<int> raw = await downloader.fetchBytes('$_sessionProfileUrl/$flat');
    final Object? decoded = raw.isEmpty ? null : jsonDecode(utf8.decode(raw));
    if (decoded is! Map) {
      throw SkinException('Mojang 没有返回 $fallbackName 的档案。');
    }
    final Object? properties = decoded['properties'];
    String? textureUrl;
    String model = 'classic';
    if (properties is List) {
      for (final Object? property in properties) {
        if (property is! Map || property['name'] != 'textures') continue;
        final Object? value = property['value'];
        if (value is! String) continue;
        final Object? textureJson;
        try {
          textureJson = jsonDecode(utf8.decode(base64Decode(value)));
        } on FormatException {
          continue;
        }
        if (textureJson is! Map) continue;
        final Object? textures = textureJson['textures'];
        if (textures is! Map) continue;
        final Object? skin = textures['SKIN'];
        if (skin is! Map) continue;
        textureUrl = skin['url'] is String ? skin['url'] as String : null;
        final Object? metadata = skin['metadata'];
        if (metadata is Map && metadata['model'] == 'slim') model = 'slim';
      }
    }
    if (textureUrl == null || textureUrl.isEmpty) {
      throw SkinException('$fallbackName 没有公开的自定义皮肤。');
    }
    await _remoteDir.create(recursive: true);
    final File target = File(p.join(_remoteDir.path, '$flat.png'));
    final DownloadBatchResult result = await downloader.run(<DownloadRequest>[
      DownloadRequest(url: textureUrl, destination: target.path),
    ]);
    if (!result.ok) {
      throw SkinException('皮肤纹理下载失败：${result.failures.first.error}');
    }
    return FetchedSkin(file: target, model: model);
  }

  static String _flat(String uuid) => uuid.replaceAll('-', '');
}

class SkinException implements Exception {
  const SkinException(this.message);

  final String message;

  @override
  String toString() => message;
}
