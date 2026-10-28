/// Where launcher metadata and game files come from. Mirrors rewrite the
/// official Mojang URLs by scheme/host; each side can be switched separately.
enum DownloadSource { official, bmclapi, mcim }

extension DownloadSourceLabel on DownloadSource {
  String get label {
    switch (this) {
      case DownloadSource.official:
        return '官方 Mojang';
      case DownloadSource.bmclapi:
        return 'BMCLAPI';
      case DownloadSource.mcim:
        return 'MCIM';
    }
  }

  String get description {
    switch (this) {
      case DownloadSource.official:
        return '所有文件直接从 Mojang 服务器下载。';
      case DownloadSource.bmclapi:
        return '版本清单与资源走 BMCLAPI 镜像，适合中国大陆网络。';
      case DownloadSource.mcim:
        return '走 MCIM 镜像，资源与库文件由镜像缓存。';
    }
  }
}

/// Splits a source choice into the two independent switches the settings
/// expose: 版本元数据与 Java 运行时（meta）和游戏资源（files）。
class DownloadMirror {
  const DownloadMirror({required this.metaSource, required this.fileSource});

  static const DownloadMirror official = DownloadMirror(
    metaSource: DownloadSource.official,
    fileSource: DownloadSource.official,
  );

  final DownloadSource metaSource;
  final DownloadSource fileSource;

  static const String officialManifest =
      'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';
  static const String officialJavaRuntimes =
      'https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json';

  /// URL used for the version manifest and Java runtime metadata.
  String get manifestUrl {
    switch (metaSource) {
      case DownloadSource.official:
        return officialManifest;
      case DownloadSource.bmclapi:
        return 'https://bmclapi2.bangbang93.com/mc/game/version_manifest_v2.json';
      case DownloadSource.mcim:
        return 'https://launcher.mcimirror.top/mc/game/version_manifest_v2.json';
    }
  }

  String get javaRuntimesUrl {
    switch (metaSource) {
      case DownloadSource.official:
        return officialJavaRuntimes;
      case DownloadSource.bmclapi:
        return 'https://bmclapi2.bangbang93.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json';
      case DownloadSource.mcim:
        return 'https://launcher.mcimirror.top/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json';
    }
  }

  /// Rewrites a download URL from a version/asset JSON so it points at the
  /// configured mirror. Unknown hosts pass through untouched.
  String rewrite(String url) {
    switch (fileSource) {
      case DownloadSource.official:
        return url;
      case DownloadSource.bmclapi:
        return url
            .replaceFirst(
              'https://launcher.mojang.com/',
              'https://bmclapi2.bangbang93.com/',
            )
            .replaceFirst(
              'https://piston-data.mojang.com/',
              'https://bmclapi2.bangbang93.com/',
            )
            .replaceFirst(
              'https://piston-meta.mojang.com/',
              'https://bmclapi2.bangbang93.com/',
            )
            .replaceFirst(
              'https://resources.download.minecraft.net/',
              'https://bmclapi2.bangbang93.com/assets/',
            );
      case DownloadSource.mcim:
        return url
            .replaceFirst(
              'https://launcher.mojang.com/',
              'https://launcher.mcimirror.top/',
            )
            .replaceFirst(
              'https://piston-data.mojang.com/',
              'https://launcher.mcimirror.top/',
            )
            .replaceFirst(
              'https://piston-meta.mojang.com/',
              'https://launcher.mcimirror.top/',
            )
            .replaceFirst(
              'https://resources.download.minecraft.net/',
              'https://resources.mcimirror.top/',
            );
    }
  }

  /// The official asset object URL for a two-character hash prefix.
  static String assetObjectUrl(String hash) =>
      'https://resources.download.minecraft.net/${hash.substring(0, 2)}/$hash';
}
