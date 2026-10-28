enum BrowseCategory { mod, modpack, shader, loader }

extension BrowseCategoryLabel on BrowseCategory {
  String get label {
    switch (this) {
      case BrowseCategory.mod:
        return '模组';
      case BrowseCategory.modpack:
        return '整合包';
      case BrowseCategory.shader:
        return '光影';
      case BrowseCategory.loader:
        return '加载器';
    }
  }

  String get description {
    switch (this) {
      case BrowseCategory.mod:
        return '玩法、性能与界面模组。';
      case BrowseCategory.modpack:
        return '预配置的模组组合。';
      case BrowseCategory.shader:
        return '光照与画面效果。';
      case BrowseCategory.loader:
        return 'Forge、NeoForge、Fabric 与 OptiFine。';
    }
  }
}

/// A project shown in the Browse tab. Demo data comes from
/// [DemoData]; real results are mapped from Modrinth through
/// [ModrinthClient.mapSearch].
class BrowseItem {
  const BrowseItem({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.author,
    required this.category,
    required this.loaders,
    required this.downloads,
    required this.followers,
    required this.updatedAt,
    required this.accentStartValue,
    required this.accentEndValue,
    required this.tags,
    required this.versions,
    this.featured = false,
    this.loaderId,
    this.iconUrl,
    this.slug,
  });

  final String id;
  final String name;
  final String summary;
  final String description;
  final String author;
  final BrowseCategory category;
  final List<String> loaders;
  final int downloads;
  final int followers;
  final DateTime updatedAt;
  final int accentStartValue;
  final int accentEndValue;
  final List<String> tags;
  final List<String> versions;
  final bool featured;
  final String? loaderId;

  /// Modrinth icon (null for demo items, which use the gradient header).
  final String? iconUrl;

  /// Modrinth slug used to build the project page URL.
  final String? slug;

  bool get isOnline => iconUrl != null || slug != null;
}
