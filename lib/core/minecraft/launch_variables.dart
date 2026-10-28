import 'dart:io';

/// Argument variables filled in by the launcher, matching Mojang's
/// `${...}` placeholders in modern version JSON.
class LaunchVariables {
  LaunchVariables({
    required this.authPlayerName,
    required this.authUuid,
    required this.authAccessToken,
    required this.xuid,
    required this.userType,
    required this.versionType,
    required this.gameDirectory,
    required this.assetsRoot,
    required this.assetsIndexName,
    required this.gameAssets,
    required this.libraryDirectory,
    required this.versionName,
    required this.nativesDirectory,
    required this.launcherName,
    required this.launcherVersion,
    required this.classpath,
    this.clientId,
    this.resolutionWidth,
    this.resolutionHeight,
  });

  final String authPlayerName;
  final String authUuid;
  final String authAccessToken;
  final String xuid;
  final String userType;
  final String versionType;
  final String gameDirectory;
  final String assetsRoot;
  final String assetsIndexName;
  final String gameAssets;
  final String libraryDirectory;
  final String versionName;
  final String nativesDirectory;
  final String launcherName;
  final String launcherVersion;
  final String classpath;
  final String? clientId;
  final int? resolutionWidth;
  final int? resolutionHeight;

  static String get pathSeparator => Platform.isWindows ? ';' : ':';

  /// Feature flags passed to game argument rules.
  Map<String, bool> get features => <String, bool>{
    'has_custom_resolution':
        resolutionWidth != null && resolutionHeight != null,
  };

  Map<String, String> get values => <String, String>{
    'auth_player_name': authPlayerName,
    'auth_uuid': authUuid,
    'auth_access_token': authAccessToken,
    'auth_session': authAccessToken,
    'auth_xuid': xuid,
    'xuid': xuid,
    'clientid': clientId ?? '',
    'user_type': userType,
    'user_properties': '{}',
    'version_name': versionName,
    'version_type': versionType,
    'game_directory': gameDirectory,
    'assets_root': assetsRoot,
    'assets_index_name': assetsIndexName,
    'game_assets': gameAssets,
    'library_directory': libraryDirectory,
    'classpath_separator': pathSeparator,
    'classpath': classpath,
    'launcher_name': launcherName,
    'launcher_version': launcherVersion,
    'natives_directory': nativesDirectory,
    'resolution_width': resolutionWidth?.toString() ?? '',
    'resolution_height': resolutionHeight?.toString() ?? '',
    'quickPlayPath': '',
  };
}

/// Replaces every `${name}` in [text] that [variables] knows about.
String substituteVariables(String text, Map<String, String> variables) {
  return text.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (Match match) {
    final String key = match.group(1)!;
    return variables[key] ?? match.group(0)!;
  });
}
