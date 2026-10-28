import '../utils/json_utils.dart';

/// One entry of Mojang's `version_manifest_v2.json`.
class VersionManifestEntry {
  const VersionManifestEntry({
    required this.id,
    required this.type,
    required this.url,
    required this.releaseTime,
    required this.sha1,
  });

  factory VersionManifestEntry.fromJson(Map<String, dynamic> json) {
    return VersionManifestEntry(
      id: asString(json['id']),
      type: asString(json['type'], 'release'),
      url: asString(json['url']),
      releaseTime: asDateTime(json['releaseTime']) ?? DateTime(1970),
      sha1: asString(json['sha1']),
    );
  }

  final String id;
  final String type;
  final String url;
  final DateTime releaseTime;
  final String sha1;

  bool get isRelease => type == 'release';
}

class VersionManifest {
  const VersionManifest({required this.latestRelease, required this.versions});

  factory VersionManifest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> latest = asMap(json['latest']);
    return VersionManifest(
      latestRelease: asString(latest['release']),
      versions: asMapList(json['versions'])
          .map(VersionManifestEntry.fromJson)
          .where((VersionManifestEntry entry) => entry.id.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String latestRelease;
  final List<VersionManifestEntry> versions;

  List<VersionManifestEntry> get releases => versions
      .where((VersionManifestEntry entry) => entry.isRelease)
      .toList(growable: false);

  VersionManifestEntry? find(String id) {
    for (final VersionManifestEntry entry in versions) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
