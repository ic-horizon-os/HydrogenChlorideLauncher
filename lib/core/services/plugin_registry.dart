import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../config/app_paths.dart';
import '../config/json_store.dart';
import '../constants.dart';
import '../demo/demo_data.dart';
import '../models/plugin_manifest.dart';

class PluginRegistry extends ChangeNotifier {
  PluginRegistry(this.paths, {JsonStore? jsonStore})
    : _json = jsonStore ?? const JsonStore();

  final AppPaths paths;
  final JsonStore _json;
  final List<PluginManifest> _plugins = <PluginManifest>[];
  final List<PluginLoadResult> _invalid = <PluginLoadResult>[];
  Map<String, dynamic> _enabledState = <String, dynamic>{};
  bool _includeDemo = true;

  List<PluginManifest> get plugins =>
      List<PluginManifest>.unmodifiable(_plugins);
  List<PluginLoadResult> get invalid =>
      List<PluginLoadResult>.unmodifiable(_invalid);
  String get pluginsPath => paths.pluginsDir.path;

  Future<void> load({bool includeDemo = true}) async {
    _includeDemo = includeDemo;
    _plugins.clear();
    _invalid.clear();
    _enabledState =
        await _json.readMap(paths.pluginStateFile) ?? <String, dynamic>{};
    await paths.pluginsDir.create(recursive: true);

    List<FileSystemEntity> entries = <FileSystemEntity>[];
    try {
      entries = await paths.pluginsDir.list().toList();
    } on FileSystemException {
      entries = <FileSystemEntity>[];
    }

    for (final FileSystemEntity entity in entries) {
      if (entity is! Directory) continue;
      final PluginLoadResult result = await _loadDirectory(entity);
      if (result.manifest == null) {
        _invalid.add(result);
      } else {
        final PluginManifest manifest = result.manifest!;
        manifest.enabled = _enabledState[manifest.id] is bool
            ? _enabledState[manifest.id] as bool
            : true;
        _plugins.add(manifest);
      }
    }

    if (includeDemo) {
      final PluginManifest demo = DemoData.buildDemoPlugin();
      demo.enabled = _enabledState[demo.id] is bool
          ? _enabledState[demo.id] as bool
          : true;
      _plugins.insert(0, demo);
    }

    _plugins.sort((PluginManifest a, PluginManifest b) {
      if (a.isDemo != b.isDemo) return a.isDemo ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    notifyListeners();
  }

  Future<PluginLoadResult> _loadDirectory(Directory directory) async {
    final File manifestFile = File(p.join(directory.path, 'plugin.json'));
    if (!await manifestFile.exists()) {
      return PluginLoadResult(
        directory: directory.path,
        error: '缺少 plugin.json',
      );
    }
    try {
      final Map<String, dynamic>? json = await _json.readMap(manifestFile);
      if (json == null) {
        return PluginLoadResult(
          directory: directory.path,
          error: 'plugin.json 不是有效的 JSON 对象',
        );
      }
      final PluginManifest manifest = PluginManifest.fromJson(
        json,
        directory: directory.path,
      );
      final String? minVersion = manifest.minLauncherVersion;
      if (minVersion != null &&
          _compareVersions(minVersion, AppInfo.version) > 0) {
        return PluginLoadResult(
          directory: directory.path,
          error: '需要启动器版本 $minVersion 或更高',
        );
      }
      return PluginLoadResult(directory: directory.path, manifest: manifest);
    } on FormatException catch (error) {
      return PluginLoadResult(directory: directory.path, error: error.message);
    } on FileSystemException catch (error) {
      return PluginLoadResult(directory: directory.path, error: error.message);
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    for (final PluginManifest plugin in _plugins) {
      if (plugin.id != id) continue;
      plugin.enabled = enabled;
      _enabledState[id] = enabled;
      await _saveState();
      notifyListeners();
      return;
    }
  }

  Future<PluginManifest> installFromDirectory(Directory source) async {
    final PluginLoadResult result = await _loadDirectory(source);
    final PluginManifest? manifest = result.manifest;
    if (manifest == null) {
      throw FormatException(result.error ?? '插件清单无效');
    }
    if (_plugins.any(
      (PluginManifest plugin) => plugin.id == manifest.id && !plugin.isDemo,
    )) {
      throw FormatException('插件 ${manifest.id} 已安装');
    }
    final Directory destination = Directory(
      p.join(paths.pluginsDir.path, manifest.id),
    );
    if (await destination.exists()) {
      throw FormatException('插件目录已存在：${destination.path}');
    }
    await _copyDirectory(source, destination);
    _enabledState[manifest.id] = true;
    await _saveState();
    await load(includeDemo: _includeDemo);
    return manifest;
  }

  Future<void> uninstall(String id) async {
    PluginManifest? plugin;
    for (final PluginManifest item in _plugins) {
      if (item.id == id) {
        plugin = item;
        break;
      }
    }
    if (plugin == null) return;
    if (plugin.isDemo) {
      throw const FormatException('内置示例插件不能卸载，只能在演示数据开关中隐藏');
    }
    final Directory directory = Directory(plugin.directory);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _enabledState.remove(id);
    await _saveState();
    await load(includeDemo: _includeDemo);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final FileSystemEntity entity in source.list()) {
      final String name = p.basename(entity.path);
      if (entity is File) {
        await entity.copy(p.join(destination.path, name));
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(destination.path, name)));
      }
    }
  }

  Future<void> _saveState() async {
    final Map<String, dynamic> state = <String, dynamic>{
      ..._enabledState,
      for (final PluginManifest plugin in _plugins)
        if (!plugin.isDemo) plugin.id: plugin.enabled,
    };
    await _json.write(paths.pluginStateFile, state);
  }

  static int _compareVersions(String a, String b) {
    final List<int> left = _versionParts(a);
    final List<int> right = _versionParts(b);
    final int length = left.length > right.length ? left.length : right.length;
    for (int i = 0; i < length; i++) {
      final int l = i < left.length ? left[i] : 0;
      final int r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    final String core = version.split('-').first.split('+').first;
    return core
        .split('.')
        .map((String part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }
}
