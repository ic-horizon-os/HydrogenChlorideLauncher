import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One installed version found inside a `.minecraft` directory.
class InstalledVersion {
  const InstalledVersion({
    required this.id,
    required this.minecraftVersion,
    required this.loader,
    required this.directory,
    required this.rootDir,
    required this.hasJson,
  });

  /// Folder name under `versions/`, which is also the version id.
  final String id;

  /// The game version this is built for (from `inheritsFrom` when present).
  final String minecraftVersion;

  /// Vanilla / Fabric / Forge / NeoForge / OptiFine.
  final String loader;

  final Directory directory;

  /// The `.minecraft` root this version belongs to.
  final String rootDir;

  /// False when `versions/<id>/<id>.json` is missing or unreadable.
  final bool hasJson;

  /// Label shown in lists, e.g. "Fabric 1.21.1".
  String get label => loader == 'Vanilla'
      ? 'Minecraft $minecraftVersion'
      : '$loader · $minecraftVersion';
}

/// Scans every configured `.minecraft` directory so versions from different
/// roots are shown together, the way HMCL lists them.
class VersionScanner {
  VersionScanner._();

  static Future<List<InstalledVersion>> scan(List<String> roots) async {
    final List<InstalledVersion> found = <InstalledVersion>[];
    final Set<String> seen = <String>{};
    for (final String root in roots) {
      final Directory versionsDir = Directory(p.join(root, 'versions'));
      if (!await versionsDir.exists()) continue;
      List<FileSystemEntity> entries;
      try {
        entries = await versionsDir.list().toList();
      } on FileSystemException {
        continue;
      }
      for (final FileSystemEntity entity in entries) {
        if (entity is! Directory) continue;
        final String id = p.basename(entity.path);
        // Same id in two roots stays distinguishable.
        final String key = '$root::$id';
        if (!seen.add(key)) continue;
        final File json = File(p.join(entity.path, '$id.json'));
        final String? inherits = await _inheritsFrom(json);
        found.add(
          InstalledVersion(
            id: id,
            minecraftVersion: inherits ?? id,
            loader: _loaderOf(id),
            directory: entity,
            rootDir: root,
            hasJson: json.existsSync(),
          ),
        );
      }
    }
    found.sort((InstalledVersion a, InstalledVersion b) {
      final int byVersion = _compareVersions(
        b.minecraftVersion,
        a.minecraftVersion,
      );
      return byVersion != 0 ? byVersion : a.id.compareTo(b.id);
    });
    return found;
  }

  static String _loaderOf(String id) {
    final String lower = id.toLowerCase();
    if (lower.contains('neoforge')) return 'NeoForge';
    if (lower.contains('forge')) return 'Forge';
    if (lower.contains('fabric')) return 'Fabric';
    if (lower.contains('optifine')) return 'OptiFine';
    if (lower.contains('quilt')) return 'Quilt';
    return 'Vanilla';
  }

  static Future<String?> _inheritsFrom(File json) async {
    if (!await json.exists()) return null;
    try {
      final Object? decoded = jsonDecode(
        (await json.readAsString()).replaceFirst(RegExp('^\\uFEFF'), ''),
      );
      if (decoded is Map<String, dynamic>) {
        final Object? parent = decoded['inheritsFrom'];
        if (parent is String && parent.isNotEmpty) return parent;
      }
    } on Object {
      return null;
    }
    return null;
  }

  /// Numeric-aware comparison so 1.21.1 sorts above 1.21.
  static int _compareVersions(String a, String b) {
    List<int> parts(String value) =>
        RegExp(r'\d+')
            .allMatches(value)
            .map((RegExpMatch m) => int.parse(m.group(0)!))
            .toList(growable: false);
    final List<int> left = parts(a);
    final List<int> right = parts(b);
    for (int i = 0; i < left.length && i < right.length; i++) {
      final int diff = left[i] - right[i];
      if (diff != 0) return diff;
    }
    return left.length - right.length;
  }
}
