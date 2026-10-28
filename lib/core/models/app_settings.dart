import 'package:fluent_ui/fluent_ui.dart';

import '../minecraft/download_source.dart';
import '../constants.dart';
import '../utils/json_utils.dart';

enum AppThemeMode { system, light, dark }

enum BackgroundBlurMode { acrylic, gaussian }

const Object _unset = Object();

/// User-facing settings persisted as `settings.json`.
class AppSettings {
  AppSettings({
    required this.themeMode,
    required this.accentColorValue,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
    required this.backgroundBlurMode,
    required this.backgroundBlurSigma,
    required this.demoData,
    required this.microsoftClientId,
    required this.defaultJavaPath,
    required this.defaultMemoryMb,
    required this.defaultJvmArgs,
    required this.minecraftDirs,
    required this.windowTransparency,
    required this.metaDownloadSource,
    required this.fileDownloadSource,
    required this.autoDownloadJava,
    required this.updateManifestUrl,
    required this.checkUpdatesOnStart,
  });

  factory AppSettings.defaults({String? minecraftDir}) {
    return AppSettings(
      themeMode: AppThemeMode.system,
      accentColorValue: 0xFF0078D4,
      backgroundImagePath: null,
      backgroundOpacity: 0.36,
      backgroundBlur: true,
      backgroundBlurMode: BackgroundBlurMode.acrylic,
      backgroundBlurSigma: 28,
      demoData: false,
      microsoftClientId: AppInfo.defaultMicrosoftClientId,
      defaultJavaPath: null,
      defaultMemoryMb: 4096,
      defaultJvmArgs: '-XX:+UseG1GC',
      minecraftDirs: <String>[?minecraftDir],
      windowTransparency: true,
      metaDownloadSource: DownloadSource.official,
      fileDownloadSource: DownloadSource.official,
      autoDownloadJava: true,
      updateManifestUrl: '',
      checkUpdatesOnStart: true,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final AppSettings defaults = AppSettings.defaults();
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (AppThemeMode mode) => mode.name == asString(json['themeMode']),
        orElse: () => defaults.themeMode,
      ),
      accentColorValue: asInt(
        json['accentColorValue'],
        defaults.accentColorValue,
      ),
      backgroundImagePath: asStringOrNull(json['backgroundImagePath']),
      backgroundOpacity: asDouble(
        json['backgroundOpacity'],
        defaults.backgroundOpacity,
      ).clamp(0.0, 1.0).toDouble(),
      backgroundBlur: asBool(json['backgroundBlur'], defaults.backgroundBlur),
      backgroundBlurMode: BackgroundBlurMode.values.firstWhere(
        (BackgroundBlurMode mode) =>
            mode.name == asString(json['backgroundBlurMode']),
        orElse: () => defaults.backgroundBlurMode,
      ),
      backgroundBlurSigma: asDouble(
        json['backgroundBlurSigma'],
        defaults.backgroundBlurSigma,
      ).clamp(0.0, 80.0).toDouble(),
      demoData: asBool(json['demoData'], defaults.demoData),
      microsoftClientId:
          asStringOrNull(json['microsoftClientId']) ??
          defaults.microsoftClientId,
      defaultJavaPath: asStringOrNull(json['defaultJavaPath']),
      defaultMemoryMb: asInt(
        json['defaultMemoryMb'],
        defaults.defaultMemoryMb,
      ).clamp(1024, 32768).toInt(),
      defaultJvmArgs: asString(json['defaultJvmArgs'], defaults.defaultJvmArgs),
      minecraftDirs: asStringList(json['minecraftDirs']),
      windowTransparency: asBool(
        json['windowTransparency'],
        defaults.windowTransparency,
      ),
      metaDownloadSource: DownloadSource.values.firstWhere(
        (DownloadSource source) =>
            source.name == asString(json['metaDownloadSource']),
        orElse: () => defaults.metaDownloadSource,
      ),
      fileDownloadSource: DownloadSource.values.firstWhere(
        (DownloadSource source) =>
            source.name == asString(json['fileDownloadSource']),
        orElse: () => defaults.fileDownloadSource,
      ),
      autoDownloadJava: asBool(
        json['autoDownloadJava'],
        defaults.autoDownloadJava,
      ),
      updateManifestUrl: asString(
        json['updateManifestUrl'],
        defaults.updateManifestUrl,
      ),
      checkUpdatesOnStart: asBool(
        json['checkUpdatesOnStart'],
        defaults.checkUpdatesOnStart,
      ),
    );
  }

  AppThemeMode themeMode;
  int accentColorValue;
  String? backgroundImagePath;
  double backgroundOpacity;
  bool backgroundBlur;
  BackgroundBlurMode backgroundBlurMode;
  double backgroundBlurSigma;
  bool demoData;
  String? microsoftClientId;
  String? defaultJavaPath;
  int defaultMemoryMb;
  String defaultJvmArgs;
  List<String> minecraftDirs;
  bool windowTransparency;
  DownloadSource metaDownloadSource;
  DownloadSource fileDownloadSource;
  bool autoDownloadJava;
  String updateManifestUrl;
  bool checkUpdatesOnStart;

  Color get accentColor => Color(accentColorValue);

  DownloadMirror get mirror => DownloadMirror(
    metaSource: metaDownloadSource,
    fileSource: fileDownloadSource,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themeMode': themeMode.name,
    'accentColorValue': accentColorValue,
    'backgroundImagePath': backgroundImagePath,
    'backgroundOpacity': backgroundOpacity,
    'backgroundBlur': backgroundBlur,
    'backgroundBlurMode': backgroundBlurMode.name,
    'backgroundBlurSigma': backgroundBlurSigma,
    'demoData': demoData,
    'microsoftClientId': microsoftClientId,
    'defaultJavaPath': defaultJavaPath,
    'defaultMemoryMb': defaultMemoryMb,
    'defaultJvmArgs': defaultJvmArgs,
    'minecraftDirs': minecraftDirs,
    'windowTransparency': windowTransparency,
    'metaDownloadSource': metaDownloadSource.name,
    'fileDownloadSource': fileDownloadSource.name,
    'autoDownloadJava': autoDownloadJava,
    'updateManifestUrl': updateManifestUrl,
    'checkUpdatesOnStart': checkUpdatesOnStart,
  };

  AppSettings copyWith({
    AppThemeMode? themeMode,
    int? accentColorValue,
    Object? backgroundImagePath = _unset,
    double? backgroundOpacity,
    bool? backgroundBlur,
    BackgroundBlurMode? backgroundBlurMode,
    double? backgroundBlurSigma,
    bool? demoData,
    Object? microsoftClientId = _unset,
    Object? defaultJavaPath = _unset,
    int? defaultMemoryMb,
    String? defaultJvmArgs,
    List<String>? minecraftDirs,
    bool? windowTransparency,
    DownloadSource? metaDownloadSource,
    DownloadSource? fileDownloadSource,
    bool? autoDownloadJava,
    String? updateManifestUrl,
    bool? checkUpdatesOnStart,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      backgroundImagePath: identical(backgroundImagePath, _unset)
          ? this.backgroundImagePath
          : backgroundImagePath as String?,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      backgroundBlurMode: backgroundBlurMode ?? this.backgroundBlurMode,
      backgroundBlurSigma: backgroundBlurSigma ?? this.backgroundBlurSigma,
      demoData: demoData ?? this.demoData,
      microsoftClientId: identical(microsoftClientId, _unset)
          ? this.microsoftClientId
          : microsoftClientId as String?,
      defaultJavaPath: identical(defaultJavaPath, _unset)
          ? this.defaultJavaPath
          : defaultJavaPath as String?,
      defaultMemoryMb: defaultMemoryMb ?? this.defaultMemoryMb,
      defaultJvmArgs: defaultJvmArgs ?? this.defaultJvmArgs,
      minecraftDirs: minecraftDirs ?? this.minecraftDirs,
      windowTransparency: windowTransparency ?? this.windowTransparency,
      metaDownloadSource: metaDownloadSource ?? this.metaDownloadSource,
      fileDownloadSource: fileDownloadSource ?? this.fileDownloadSource,
      autoDownloadJava: autoDownloadJava ?? this.autoDownloadJava,
      updateManifestUrl: updateManifestUrl ?? this.updateManifestUrl,
      checkUpdatesOnStart: checkUpdatesOnStart ?? this.checkUpdatesOnStart,
    );
  }
}
