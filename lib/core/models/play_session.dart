import '../utils/json_utils.dart';

/// One completed play session. Metadata is denormalised so statistics keep
/// working after a library entry is removed.
class PlaySession {
  const PlaySession({
    required this.appId,
    required this.appName,
    required this.kind,
    required this.startedAt,
    required this.durationSeconds,
    this.loader,
    this.minecraftVersion,
    this.isDemo = false,
  });

  factory PlaySession.fromJson(Map<String, dynamic> json) {
    return PlaySession(
      appId: asString(json['appId']),
      appName: asString(json['appName'], '未知应用'),
      kind: asString(json['kind'], 'custom'),
      startedAt: asDateTime(json['startedAt']) ?? DateTime.now(),
      durationSeconds: asInt(json['durationSeconds'], 0),
      loader: asStringOrNull(json['loader']),
      minecraftVersion: asStringOrNull(json['minecraftVersion']),
      isDemo: asBool(json['isDemo'], false),
    );
  }

  final String appId;
  final String appName;
  final String kind;
  final DateTime startedAt;
  final int durationSeconds;
  final String? loader;
  final String? minecraftVersion;
  final bool isDemo;

  Duration get duration => Duration(seconds: durationSeconds);

  bool get isGame => kind == 'minecraft' || kind == 'modpack';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'appId': appId,
    'appName': appName,
    'kind': kind,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'loader': loader,
    'minecraftVersion': minecraftVersion,
    'isDemo': isDemo,
  };
}
