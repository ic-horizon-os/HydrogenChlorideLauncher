import '../utils/json_utils.dart';

/// Result of scanning one `plugin.json` file.
class PluginLoadResult {
  const PluginLoadResult({required this.directory, this.manifest, this.error});

  final String directory;
  final PluginManifest? manifest;
  final String? error;

  bool get isValid => manifest != null;
}

class PluginManifest {
  PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.minLauncherVersion,
    required this.permissions,
    required this.pages,
    required this.directory,
    this.enabled = true,
    this.isDemo = false,
  });

  /// Parses a manifest and throws [FormatException] with a user-readable
  /// message when a required field is missing or malformed.
  factory PluginManifest.fromJson(
    Map<String, dynamic> json, {
    required String directory,
  }) {
    final String id = asString(json['id']).trim();
    final String name = asString(json['name']).trim();
    final String version = asString(json['version']).trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{1,63}$').hasMatch(id)) {
      throw const FormatException('id 必须为 2-64 位小写字母、数字、点、下划线或连字符');
    }
    if (name.isEmpty) {
      throw const FormatException('缺少 name');
    }
    if (version.isEmpty) {
      throw const FormatException('缺少 version');
    }

    final Map<String, dynamic> contributes = asMap(json['contributes']);
    final List<PluginPage> pages = asMapList(contributes['pages'])
        .map((Map<String, dynamic> page) => PluginPage.fromJson(page))
        .where((PluginPage page) => page.id.isNotEmpty)
        .toList(growable: false);

    return PluginManifest(
      id: id,
      name: name,
      version: version,
      author: asString(json['author'], '未知作者'),
      description: asString(json['description']),
      minLauncherVersion: asStringOrNull(json['minLauncherVersion']),
      permissions: asStringList(json['permissions']),
      pages: pages,
      directory: directory,
    );
  }

  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String? minLauncherVersion;
  final List<String> permissions;
  final List<PluginPage> pages;
  final String directory;
  bool enabled;
  bool isDemo;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'minLauncherVersion': minLauncherVersion,
    'permissions': permissions,
    'pages': pages.map((PluginPage page) => page.toJson()).toList(),
  };
}

/// A declarative page contributed by a plugin.
class PluginPage {
  const PluginPage({
    required this.id,
    required this.title,
    required this.icon,
    required this.widgets,
  });

  factory PluginPage.fromJson(Map<String, dynamic> json) {
    return PluginPage(
      id: asString(json['id']),
      title: asString(json['title'], '插件页面'),
      icon: asString(json['icon'], 'extension'),
      widgets: asMapList(json['widgets']),
    );
  }

  final String id;
  final String title;
  final String icon;

  /// Declarative widget tree, see docs/plugin-development.md.
  final List<Map<String, dynamic>> widgets;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'icon': icon,
    'widgets': widgets,
  };
}
