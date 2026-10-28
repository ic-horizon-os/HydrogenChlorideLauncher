import '../config/app_paths.dart';
import '../config/json_store.dart';
import '../models/app_settings.dart';

class SettingsStore {
  SettingsStore(this.paths, {JsonStore? jsonStore})
    : _json = jsonStore ?? const JsonStore();

  final AppPaths paths;
  final JsonStore _json;

  Future<AppSettings> load() async {
    final AppSettings defaults = AppSettings.defaults(
      minecraftDir: AppPaths.defaultMinecraftDir(),
    );
    final Map<String, dynamic>? map = await _json.readMap(paths.settingsFile);
    if (map == null) return defaults;
    final AppSettings settings = AppSettings.fromJson(map);
    if (settings.minecraftDirs.isEmpty) {
      settings.minecraftDirs = defaults.minecraftDirs;
    }
    return settings;
  }

  Future<void> save(AppSettings settings) {
    return _json.write(paths.settingsFile, settings.toJson());
  }
}
