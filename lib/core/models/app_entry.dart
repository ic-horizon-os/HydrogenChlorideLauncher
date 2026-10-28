import '../utils/json_utils.dart';

enum AppKind { minecraft, modpack, custom, utility }

const Object _unset = Object();

/// An entry shown in the launcher library.
class AppEntry {
  AppEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.kind,
    this.isDemo = false,
    this.versionId,
    this.loader,
    this.minecraftVersion,
    this.executablePath,
    this.workingDir,
    this.arguments,
    this.iconColorValue = 0xFF4C8DFF,
    this.totalPlayMs = 0,
    this.lastPlayed,
    this.trackPlaytime = true,
    this.isolated = false,
    this.javaPathOverride,
    this.memoryMbOverride,
    this.jvmArgsOverride,
  });

  factory AppEntry.fromJson(Map<String, dynamic> json) {
    return AppEntry(
      id: asString(json['id']),
      name: asString(json['name'], '未命名项'),
      subtitle: asString(json['subtitle']),
      description: asString(json['description']),
      kind: AppKind.values.firstWhere(
        (AppKind kind) => kind.name == asString(json['kind']),
        orElse: () => AppKind.custom,
      ),
      isDemo: asBool(json['isDemo'], false),
      versionId: asStringOrNull(json['versionId']),
      loader: asStringOrNull(json['loader']),
      minecraftVersion: asStringOrNull(json['minecraftVersion']),
      executablePath: asStringOrNull(json['executablePath']),
      workingDir: asStringOrNull(json['workingDir']),
      arguments: asStringOrNull(json['arguments']),
      iconColorValue: asInt(json['iconColorValue'], 0xFF4C8DFF),
      totalPlayMs: asInt(json['totalPlayMs'], 0),
      lastPlayed: asDateTime(json['lastPlayed']),
      trackPlaytime: asBool(json['trackPlaytime'], true),
      isolated: asBool(json['isolated'], false),
      javaPathOverride: asStringOrNull(json['javaPathOverride']),
      memoryMbOverride: json['memoryMbOverride'] == null
          ? null
          : asInt(json['memoryMbOverride'], 4096),
      jvmArgsOverride: asStringOrNull(json['jvmArgsOverride']),
    );
  }

  final String id;
  String name;
  String subtitle;
  String description;
  AppKind kind;
  bool isDemo;
  String? versionId;
  String? loader;
  String? minecraftVersion;
  String? executablePath;
  String? workingDir;
  String? arguments;
  int iconColorValue;
  int totalPlayMs;
  DateTime? lastPlayed;
  bool trackPlaytime;
  bool isolated;
  String? javaPathOverride;
  int? memoryMbOverride;
  String? jvmArgsOverride;

  bool get isMinecraft => kind == AppKind.minecraft || kind == AppKind.modpack;

  bool get isGame => kind == AppKind.minecraft || kind == AppKind.modpack;

  Duration get totalPlayed => Duration(milliseconds: totalPlayMs);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'description': description,
    'kind': kind.name,
    'isDemo': isDemo,
    'versionId': versionId,
    'loader': loader,
    'minecraftVersion': minecraftVersion,
    'executablePath': executablePath,
    'workingDir': workingDir,
    'arguments': arguments,
    'iconColorValue': iconColorValue,
    'totalPlayMs': totalPlayMs,
    'lastPlayed': lastPlayed?.toIso8601String(),
    'trackPlaytime': trackPlaytime,
    'javaPathOverride': javaPathOverride,
    'memoryMbOverride': memoryMbOverride,
    'jvmArgsOverride': jvmArgsOverride,
  };

  AppEntry copyWith({
    String? name,
    String? subtitle,
    String? description,
    AppKind? kind,
    bool? isDemo,
    Object? versionId = _unset,
    Object? loader = _unset,
    Object? minecraftVersion = _unset,
    Object? executablePath = _unset,
    Object? workingDir = _unset,
    Object? arguments = _unset,
    int? iconColorValue,
    int? totalPlayMs,
    Object? lastPlayed = _unset,
    bool? trackPlaytime,
    bool? isolated,
    Object? javaPathOverride = _unset,
    Object? memoryMbOverride = _unset,
    Object? jvmArgsOverride = _unset,
  }) {
    return AppEntry(
      id: id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      isDemo: isDemo ?? this.isDemo,
      versionId: identical(versionId, _unset)
          ? this.versionId
          : versionId as String?,
      loader: identical(loader, _unset) ? this.loader : loader as String?,
      minecraftVersion: identical(minecraftVersion, _unset)
          ? this.minecraftVersion
          : minecraftVersion as String?,
      executablePath: identical(executablePath, _unset)
          ? this.executablePath
          : executablePath as String?,
      workingDir: identical(workingDir, _unset)
          ? this.workingDir
          : workingDir as String?,
      arguments: identical(arguments, _unset)
          ? this.arguments
          : arguments as String?,
      iconColorValue: iconColorValue ?? this.iconColorValue,
      totalPlayMs: totalPlayMs ?? this.totalPlayMs,
      lastPlayed: identical(lastPlayed, _unset)
          ? this.lastPlayed
          : lastPlayed as DateTime?,
      trackPlaytime: trackPlaytime ?? this.trackPlaytime,
      isolated: isolated ?? this.isolated,
      javaPathOverride: identical(javaPathOverride, _unset)
          ? this.javaPathOverride
          : javaPathOverride as String?,
      memoryMbOverride: identical(memoryMbOverride, _unset)
          ? this.memoryMbOverride
          : memoryMbOverride as int?,
      jvmArgsOverride: identical(jvmArgsOverride, _unset)
          ? this.jvmArgsOverride
          : jvmArgsOverride as String?,
    );
  }
}
