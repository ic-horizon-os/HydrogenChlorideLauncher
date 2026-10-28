import 'package:flutter/foundation.dart';

import '../config/app_paths.dart';
import '../config/json_store.dart';
import 'install_module.dart';

/// Registers the install modules shipped with the launcher and keeps their
/// on/off state in `install_modules.json`.
///
/// Modules are compiled in (they live under `HCL-Plugins/` and are linked via a
/// path dependency), so "disabling" one means the launcher stops offering its
/// capabilities rather than unloading code.
class InstallModuleRegistry extends ChangeNotifier {
  InstallModuleRegistry(this.paths, {JsonStore? jsonStore})
    : _json = jsonStore ?? const JsonStore();

  final AppPaths paths;
  final JsonStore _json;
  final List<InstallModule> _modules = <InstallModule>[];
  final Set<String> _disabled = <String>{};

  List<InstallModule> get modules => List<InstallModule>.unmodifiable(_modules);

  bool isEnabled(InstallModule module) => !_disabled.contains(module.id);

  void register(InstallModule module) {
    if (_modules.any((InstallModule m) => m.id == module.id)) return;
    _modules.add(module);
  }

  /// Modules that currently provide [capability].
  List<InstallModule> providersOf(InstallCapability capability) => _modules
      .where(
        (InstallModule m) =>
            isEnabled(m) && m.capabilities.contains(capability),
      )
      .toList(growable: false);

  bool get supportsVanilla => providersOf(InstallCapability.vanilla).isNotEmpty;
  bool get supportsLoader => providersOf(InstallCapability.loader).isNotEmpty;
  bool get supportsModpack => providersOf(InstallCapability.modpack).isNotEmpty;

  Future<void> load() async {
    final Map<String, dynamic>? state = await _json.readMap(
      paths.installModuleStateFile,
    );
    _disabled
      ..clear()
      ..addAll(
        (state?['disabled'] is List
                ? state!['disabled'] as List
                : const <Object?>[])
            .whereType<String>(),
      );
    notifyListeners();
  }

  Future<void> setEnabled(InstallModule module, bool enabled) async {
    if (enabled) {
      _disabled.remove(module.id);
    } else {
      _disabled.add(module.id);
    }
    notifyListeners();
    await _json.write(paths.installModuleStateFile, <String, dynamic>{
      'disabled': _disabled.toList(),
    });
  }
}

/// Describes one install request in capability-neutral terms.
class InstallRequest {
  const InstallRequest({
    required this.capability,
    this.version,
    this.loader,
    this.loaderBuild,
    this.gameVersion,
    this.javaExecutable,
    this.packPath,
    this.gameDirectory,
  });

  final InstallCapability capability;
  final String? version;
  final String? loader;
  final String? loaderBuild;
  final String? gameVersion;
  final String? javaExecutable;
  final String? packPath;
  final String? gameDirectory;
}

/// Runs requests against whichever enabled module advertises the capability.
///
/// The actual install code lives in the sibling module folder; this class only
/// decides *whether* an install may run.
class ModuleRunner {
  ModuleRunner(this._modules);

  final List<InstallModule> _modules;

  Future<String?> run(
    InstallCapability capability,
    InstallContext context, {
    required Future<String?> Function() executor,
  }) async {
    final bool allowed = _modules.any(
      (InstallModule m) => m.capabilities.contains(capability),
    );
    if (!allowed) {
      return '安装模块已停用，请在「插件管理」中启用。';
    }
    return executor();
  }
}
