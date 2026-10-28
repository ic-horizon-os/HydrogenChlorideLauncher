import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves a version and the vanilla parents it inherits from.
///
/// Fabric/Forge/NeoForge versions only ship a JSON: the game classes come from
/// the parent's client jar, so the launch classpath must include every jar in
/// the `inheritsFrom` chain, not just `versions/<id>/<id>.jar`.
class VersionChain {
  const VersionChain({required this.versionIds, required this.file});

  /// Loader id first, then each parent, ending with the vanilla version.
  final List<String> versionIds;
  final File file;

  static Future<VersionChain?> load(String root, String versionId) async {
    final List<String> ids = <String>[];
    String? current = versionId;
    final Set<String> seen = <String>{};
    File? firstFile;
    while (current != null && seen.add(current)) {
      final File json = File(
        p.join(root, 'versions', current, '$current.json'),
      );
      if (!await json.exists()) break;
      firstFile ??= json;
      ids.add(current);
      final String? next = await _inheritsFrom(json);
      if (next == null || next == current) break;
      current = next;
    }
    if (firstFile == null) return null;
    return VersionChain(versionIds: ids, file: firstFile);
  }

  /// Client jars that exist on disk, loader first, vanilla last.
  List<String> clientJars(String root) {
    final List<String> jars = <String>[];
    for (final String id in versionIds) {
      final String jar = p.join(root, 'versions', id, '$id.jar');
      if (File(jar).existsSync()) jars.add(jar);
    }
    return jars;
  }

  static Future<String?> _inheritsFrom(File json) async {
    try {
      final String text = (await json.readAsString()).replaceFirst(
        RegExp('^\\uFEFF'),
        '',
      );
      final Object? decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final Object? parent = decoded['inheritsFrom'];
        return parent is String && parent.isNotEmpty ? parent : null;
      }
    } on Object {
      // A broken parent JSON simply ends the chain.
    }
    return null;
  }
}
