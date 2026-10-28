import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/app_paths.dart';
import '../models/app_entry.dart';
import '../models/app_settings.dart';

/// HMCL-style version isolation. When enabled, mods/config/saves live under
/// `versions/<version>/` instead of the shared `.minecraft` directories.
class VersionIsolation {
  VersionIsolation._();

  static String versionFolderName(AppEntry entry) {
    final String raw = entry.versionId ?? entry.name;
    return raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static String gameDir(AppEntry entry, AppSettings settings) {
    return instanceDir(entry, settings);
  }

  /// The effective game directory: isolated version folder or the shared
  /// `.minecraft` root.
  static String instanceDir(AppEntry entry, AppSettings settings) {
    final String base = settings.minecraftDirs.isNotEmpty
        ? settings.minecraftDirs.first
        : AppPaths.defaultMinecraftDir();
    if (!entry.isolated) return base;
    return p.join(base, 'versions', versionFolderName(entry));
  }

  static Future<void> ensure(AppEntry entry, AppSettings settings) async {
    if (!entry.isolated || !entry.isMinecraft) return;
    final Directory root = Directory(gameDir(entry, settings));
    for (final String name in <String>[
      'mods',
      'config',
      'saves',
      'resourcepacks',
      'shaderpacks',
    ]) {
      await Directory(p.join(root.path, name)).create(recursive: true);
    }
  }
}
