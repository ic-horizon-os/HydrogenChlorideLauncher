import 'dart:io';

import 'package:path/path.dart' as p;

/// Platform-specific locations for configuration, user data and plugins.
class AppPaths {
  const AppPaths({required this.configDir, required this.dataDir});

  factory AppPaths.platform() {
    final Map<String, String> env = Platform.environment;
    final String home =
        env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
    if (Platform.isWindows) {
      final String roaming =
          env['APPDATA'] ?? p.join(home, 'AppData', 'Roaming');
      final String local =
          env['LOCALAPPDATA'] ?? p.join(home, 'AppData', 'Local');
      return AppPaths(
        configDir: Directory(
          p.join(roaming, 'HyaLab', 'HydrogenChlorideLauncher'),
        ),
        dataDir: Directory(p.join(local, 'HyaLab', 'HydrogenChlorideLauncher')),
      );
    }
    final String configHome = env['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
    final String dataHome =
        env['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
    return AppPaths(
      configDir: Directory(
        p.join(configHome, 'hyalab', 'hydrogen-chloride-launcher'),
      ),
      dataDir: Directory(
        p.join(dataHome, 'hyalab', 'hydrogen-chloride-launcher'),
      ),
    );
  }

  /// Isolated layout used by tests and portable previews.
  factory AppPaths.forTesting(Directory root) {
    return AppPaths(
      configDir: Directory(p.join(root.path, 'config')),
      dataDir: Directory(p.join(root.path, 'data')),
    );
  }

  final Directory configDir;
  final Directory dataDir;

  Directory get pluginsDir => Directory(p.join(dataDir.path, 'plugins'));
  Directory get logsDir => Directory(p.join(dataDir.path, 'logs'));
  Directory get backgroundsDir =>
      Directory(p.join(dataDir.path, 'backgrounds'));

  File get settingsFile => File(p.join(configDir.path, 'settings.json'));
  File get accountFile => File(p.join(configDir.path, 'account.json'));
  File get libraryFile => File(p.join(configDir.path, 'library.json'));
  File get sessionsFile => File(p.join(configDir.path, 'sessions.json'));
  File get feedsFile => File(p.join(configDir.path, 'feeds.json'));
  File get pluginStateFile => File(p.join(configDir.path, 'plugin_state.json'));
  File get installModuleStateFile =>
      File(p.join(configDir.path, 'install_modules.json'));

  Future<void> ensure() async {
    await configDir.create(recursive: true);
    await dataDir.create(recursive: true);
    await pluginsDir.create(recursive: true);
    await logsDir.create(recursive: true);
    await backgroundsDir.create(recursive: true);
  }

  static String defaultMinecraftDir() {
    final Map<String, String> env = Platform.environment;
    final String home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    if (Platform.isWindows) {
      final String roaming =
          env['APPDATA'] ?? p.join(home, 'AppData', 'Roaming');
      return p.join(roaming, '.minecraft');
    }
    return p.join(home, '.minecraft');
  }
}
