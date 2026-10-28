import '../utils/json_utils.dart';

/// Tokens returned by the Microsoft -> Xbox Live -> XSTS -> Minecraft chain.
class MinecraftAccount {
  const MinecraftAccount({
    required this.accessToken,
    required this.refreshToken,
    required this.uuid,
    required this.name,
    required this.gamertag,
    required this.xuid,
    required this.expiresAt,
    required this.ownsMinecraft,
  });

  factory MinecraftAccount.fromJson(Map<String, dynamic> json) {
    return MinecraftAccount(
      accessToken: asString(json['accessToken']),
      refreshToken: asStringOrNull(json['refreshToken']),
      uuid: asString(json['uuid']),
      name: asString(json['name'], 'Minecraft 玩家'),
      gamertag: asStringOrNull(json['gamertag']),
      xuid: asStringOrNull(json['xuid']),
      expiresAt: asDateTime(json['expiresAt']),
      ownsMinecraft: asBool(json['ownsMinecraft'], true),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final String uuid;
  final String name;
  final String? gamertag;
  final String? xuid;
  final DateTime? expiresAt;

  /// False when the account authenticated but has no Minecraft profile.
  final bool ownsMinecraft;

  bool get isExpired {
    final DateTime? expires = expiresAt;
    if (expires == null) return false;
    return DateTime.now().isAfter(expires.subtract(const Duration(minutes: 5)));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'uuid': uuid,
    'name': name,
    'gamertag': gamertag,
    'xuid': xuid,
    'expiresAt': expiresAt?.toIso8601String(),
    'ownsMinecraft': ownsMinecraft,
  };

  MinecraftAccount copyWith({
    String? accessToken,
    String? refreshToken,
    String? uuid,
    String? name,
    String? gamertag,
    String? xuid,
    DateTime? expiresAt,
    bool? ownsMinecraft,
  }) {
    return MinecraftAccount(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      gamertag: gamertag ?? this.gamertag,
      xuid: xuid ?? this.xuid,
      expiresAt: expiresAt ?? this.expiresAt,
      ownsMinecraft: ownsMinecraft ?? this.ownsMinecraft,
    );
  }
}
