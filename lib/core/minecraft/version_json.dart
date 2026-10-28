import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/json_utils.dart';

/// A downloadable artifact with its hash metadata.
class DownloadInfo {
  const DownloadInfo({
    required this.url,
    required this.path,
    required this.sha1,
    required this.size,
  });

  factory DownloadInfo.fromJson(Map<String, dynamic> json) {
    return DownloadInfo(
      url: asString(json['url']),
      path: asString(json['path']),
      sha1: asString(json['sha1']),
      size: asInt(json['size'], 0),
    );
  }

  final String url;

  /// Relative path inside the Minecraft root (Mojang `path` field).
  final String path;
  final String sha1;
  final int size;

  bool get isValid => url.isNotEmpty;
}

/// `rules` block attached to a library or argument. Mojang semantics: the
/// entry is allowed by default only if there is no rule, and each rule that
/// matches the current platform flips the verdict to its `action`.
class RuleSet {
  const RuleSet(this.rules);

  static const Set<String> knownFeatures = <String>{
    'has_custom_resolution',
    'is_demo_user',
    'has_quick_plays_support',
    'is_quick_play_singleplayer',
    'is_quick_play_multiplayer',
    'is_quick_play_realms',
  };

  factory RuleSet.fromJson(List<Map<String, dynamic>> json) {
    return RuleSet(
      json
          .map((Map<String, dynamic> rule) => Rule.fromJson(rule))
          .toList(growable: false),
    );
  }

  final List<Rule> rules;

  /// Mojang's OS names: windows, osx, linux.
  static String platformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'osx';
    return 'linux';
  }

  static String platformArch() {
    if (Platform.version.contains('arm64') ||
        Platform.environment['HOSTTYPE'] == 'aarch64') {
      return 'arm64';
    }
    return 'x86_64';
  }

  /// Evaluates against the current OS and the given feature flags.
  bool matches({Map<String, bool> features = const <String, bool>{}}) {
    bool allowed = rules.isEmpty;
    for (final Rule rule in rules) {
      if (rule.matches(features)) allowed = rule.allow;
    }
    return allowed;
  }
}

class Rule {
  const Rule({
    required this.allow,
    this.osName,
    this.osVersion,
    this.osArch,
    this.features,
    this.hasOsConstraint = false,
  });

  factory Rule.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> os = asMap(json['os']);
    final Map<String, dynamic> features = asMap(json['features']);
    return Rule(
      allow: asString(json['action'], 'allow') == 'allow',
      osName: asStringOrNull(os['name']),
      osVersion: asStringOrNull(os['version']),
      osArch: asStringOrNull(os['arch']),
      features: features.isEmpty
          ? null
          : features.map(
              (String key, dynamic value) =>
                  MapEntry(key, asBool(value, false)),
            ),
      hasOsConstraint: os.isNotEmpty || json['features'] != null,
    );
  }

  final bool allow;
  final String? osName;
  final String? osVersion;
  final String? osArch;
  final Map<String, bool>? features;
  final bool hasOsConstraint;

  bool matches(Map<String, bool> availableFeatures) {
    if (!hasOsConstraint) return true;
    if (osName != null && osName != RuleSet.platformName()) return false;
    if (osArch != null && !Platform.version.contains(osArch!)) return false;
    if (osVersion != null) {
      final RegExp exp = RegExp(osVersion!);
      final String osRelease = Platform.operatingSystemVersion;
      if (!exp.hasMatch(osRelease)) return false;
    }
    final Map<String, bool>? required = features;
    if (required != null) {
      for (final MapEntry<String, bool> entry in required.entries) {
        if ((availableFeatures[entry.key] ?? false) != entry.value) {
          return false;
        }
      }
    }
    return true;
  }
}

/// Generic rule list entry used by `arguments` blocks.
class ArgumentEntry {
  const ArgumentEntry({required this.value, this.rules});

  factory ArgumentEntry.fromJson(Map<String, dynamic> json) {
    final Object? rawRules = json['rules'];
    return ArgumentEntry(
      value: asString(json['value']),
      rules: rawRules is List ? RuleSet.fromJson(asMapList(rawRules)) : null,
    );
  }

  /// A plain string argument.
  const ArgumentEntry.plain(this.value) : rules = null;

  final String value;
  final RuleSet? rules;

  bool matches({Map<String, bool> features = const <String, bool>{}}) {
    final RuleSet? rule = rules;
    return rule == null || rule.matches(features: features);
  }
}

/// One library entry; a library may provide several downloads (artifact plus
/// platform-specific classifiers such as natives).
class LibraryEntry {
  const LibraryEntry({
    required this.name,
    required this.artifact,
    required this.classifiers,
    required this.natives,
    required this.rules,
    required this.extractExclude,
    required this.url,
  });

  factory LibraryEntry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> downloads = asMap(json['downloads']);
    final Map<String, dynamic> classifiersJson = asMap(
      downloads['classifiers'],
    );
    final Map<String, DownloadInfo> classifiers = <String, DownloadInfo>{
      for (final MapEntry<String, dynamic> entry in classifiersJson.entries)
        entry.key: DownloadInfo.fromJson(asMap(entry.value)),
    };
    final Map<String, dynamic> nativesJson = asMap(json['natives']);
    final Map<String, String> natives = <String, String>{
      for (final MapEntry<String, dynamic> entry in nativesJson.entries)
        if (entry.value is String)
          entry.key: (entry.value as String).replaceAll(r'${arch}', '64'),
    };
    final Map<String, dynamic> extract = asMap(json['extract']);
    return LibraryEntry(
      name: asString(json['name']),
      artifact: downloads['artifact'] == null
          ? null
          : DownloadInfo.fromJson(asMap(downloads['artifact'])),
      classifiers: classifiers,
      natives: natives,
      rules: json['rules'] == null
          ? null
          : RuleSet.fromJson(asMapList(json['rules'])),
      extractExclude: asStringList(extract['exclude']),
      url: asString(json['url']),
    );
  }

  final String name;
  final DownloadInfo? artifact;
  final Map<String, DownloadInfo> classifiers;
  final Map<String, String> natives;
  final RuleSet? rules;
  final List<String> extractExclude;
  final String url;

  bool applies() {
    final RuleSet? rule = rules;
    return rule == null || rule.matches();
  }

  /// Native classifier key for the current platform, e.g. `natives-linux`.
  String? nativeClassifier() => natives[RuleSet.platformName()];

  /// Maven-style path used by loaders that publish only `name` + `url`:
  /// `group:artifact:version` -> `group/path/artifact/version/artifact-version.jar`.
  String get inferredPath {
    final List<String> parts = name.split(':');
    if (parts.length < 3) return name;
    final String group = parts[0].replaceAll('.', '/');
    final String artifact = parts[1];
    final String version = parts[2];
    final String? classifier = parts.length > 3 ? parts[3] : null;
    final String file = classifier == null
        ? '$artifact-$version.jar'
        : '$artifact-$version-$classifier.jar';
    return '$group/$artifact/$version/$file';
  }
}

/// A fully parsed `versions/<id>/<id>.json` (after inheritance merge).
class VersionJson {
  VersionJson({
    required this.id,
    required this.type,
    required this.mainClass,
    required this.assets,
    required this.assetIndex,
    required this.client,
    required this.libraries,
    required this.jvmArguments,
    required this.gameArguments,
    required this.legacyArguments,
    required this.inheritsFrom,
    required this.javaVersion,
    required this.releaseTime,
    required this.raw,
  });

  factory VersionJson.fromJson(Map<String, dynamic> json) {
    final List<ArgumentEntry> jvm = <ArgumentEntry>[];
    final List<ArgumentEntry> game = <ArgumentEntry>[];
    final Object? arguments = json['arguments'];
    if (arguments is Map) {
      jvm.addAll(parseArguments(arguments['jvm']));
      game.addAll(parseArguments(arguments['game']));
    }
    final Map<String, dynamic> assetIndexJson = asMap(json['assetIndex']);
    return VersionJson(
      id: asString(json['id']),
      type: asString(json['type'], 'release'),
      mainClass: asString(json['mainClass']),
      assets: asString(json['assets']),
      assetIndex: assetIndexJson.isEmpty
          ? null
          : DownloadInfo.fromJson(assetIndexJson),
      client:
          json['downloads'] is Map && asMap(json['downloads'])['client'] != null
          ? DownloadInfo.fromJson(asMap(asMap(json['downloads'])['client']))
          : null,
      libraries: asMapList(json['libraries'])
          .map(LibraryEntry.fromJson)
          .toList(growable: false),
      jvmArguments: jvm,
      gameArguments: game,
      legacyArguments: asStringOrNull(json['minecraftArguments']),
      inheritsFrom: asStringOrNull(json['inheritsFrom']),
      javaVersion: json['javaVersion'] == null
          ? null
          : asInt(asMap(json['javaVersion'])['majorVersion'], 0),
      releaseTime: asDateTime(json['releaseTime']),
      raw: json,
    );
  }

  final String id;
  final String type;
  final String mainClass;
  final String assets;
  final DownloadInfo? assetIndex;
  final DownloadInfo? client;
  final List<LibraryEntry> libraries;
  final List<ArgumentEntry> jvmArguments;
  final List<ArgumentEntry> gameArguments;
  final String? legacyArguments;
  final String? inheritsFrom;
  final int? javaVersion;
  final DateTime? releaseTime;
  final Map<String, dynamic> raw;
}

/// Parses an `arguments.jvm` / `arguments.game` list, which mixes plain
/// strings with rule objects, preserving their order.
List<ArgumentEntry> parseArguments(Object? raw) {
  if (raw is! List) return const <ArgumentEntry>[];
  final List<ArgumentEntry> entries = <ArgumentEntry>[];
  for (final Object? item in raw) {
    if (item is String) {
      entries.add(ArgumentEntry.plain(item));
    } else if (item is Map) {
      final Object? value = item['value'];
      final List<String> values = value is String
          ? <String>[value]
          : value is List
          ? value.whereType<String>().toList(growable: false)
          : const <String>[];
      final Object? rules = item['rules'];
      for (final String single in values) {
        entries.add(
          ArgumentEntry(
            value: single,
            rules: rules is List ? RuleSet.fromJson(asMapList(rules)) : null,
          ),
        );
      }
    }
  }
  return entries;
}

/// Merges descendant loader versions with their vanilla parent the same way
/// Mojang's launcher does: children override scalars, libraries are
/// concatenated, and child argument lists come first.
VersionJson mergeVersionJson(VersionJson parent, VersionJson child) {
  final Set<String> childLibraryNames = child.libraries
      .map((LibraryEntry library) => library.name)
      .toSet();
  final List<LibraryEntry> libraries = <LibraryEntry>[
    ...child.libraries,
    ...parent.libraries.where(
      (LibraryEntry library) => !childLibraryNames.contains(library.name),
    ),
  ];
  final List<ArgumentEntry> jvm = <ArgumentEntry>[
    ...child.jvmArguments,
    ...parent.jvmArguments,
  ];
  final List<ArgumentEntry> game = <ArgumentEntry>[
    ...child.gameArguments,
    ...parent.gameArguments,
  ];
  final Map<String, dynamic> raw = <String, dynamic>{
    ...parent.raw,
    ...child.raw,
  };
  return VersionJson(
    id: child.id,
    type: child.type,
    mainClass: child.mainClass.isNotEmpty ? child.mainClass : parent.mainClass,
    assets: child.assets.isNotEmpty ? child.assets : parent.assets,
    assetIndex: child.assetIndex ?? parent.assetIndex,
    client: child.client ?? parent.client,
    libraries: libraries,
    jvmArguments: jvm,
    gameArguments: game,
    legacyArguments: child.legacyArguments ?? parent.legacyArguments,
    inheritsFrom: null,
    javaVersion: child.javaVersion ?? parent.javaVersion,
    releaseTime: child.releaseTime ?? parent.releaseTime,
    raw: raw,
  );
}

/// Loads `versions/<id>/<id>.json`, following `inheritsFrom` up to the vanilla
/// version. Returns null when the version file is missing.
Future<VersionJson?> loadVersionJson(
  String minecraftRoot,
  String versionId,
) async {
  final Set<String> visited = <String>{};
  VersionJson? result;
  String? current = versionId;
  while (current != null) {
    if (!visited.add(current)) break;
    final File file = File(
      p.join(minecraftRoot, 'versions', current, '$current.json'),
    );
    if (!await file.exists()) {
      if (result == null) return null;
      break;
    }
    final Object? decoded;
    try {
      // Version JSON is UTF-8 with occasional BOMs.
      final String text = (await file.readAsString()).replaceFirst(
        RegExp('^\\uFEFF'),
        '',
      );
      decoded = _tryDecode(text);
    } on FileSystemException {
      return result;
    }
    if (decoded is! Map<String, dynamic>) return result;
    final VersionJson parsed = VersionJson.fromJson(decoded);
    result = result == null ? parsed : mergeVersionJson(parsed, result);
    final String? next = parsed.inheritsFrom;
    if (next == null || next == current) break;
    current = next;
  }
  return result;
}

Object? _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
