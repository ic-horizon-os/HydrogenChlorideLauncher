import 'dart:io';

import 'package:hcl_plugin_installer/contract.dart' as plugin;
import 'package:path/path.dart' as p;

/// Implements the module contract with the launcher's own services.
///
/// This is the only place that knows both sides, so the module folder stays
/// free of host imports and can be removed without touching anything else.
class InstallHostAdapter implements plugin.InstallContext {
  InstallHostAdapter({
    required this.root,
    required this.onProgress,
    required this.downloadVanilla,
    required this.installLoader,
    required this.installModpackHandler,
    bool Function()? isCancelled,
  }) : _cancelled = isCancelled;

  final bool Function()? _cancelled;

  @override
  final String root;

  final void Function(String stage, double fraction, String detail) onProgress;
  final Future<String?> Function(String version) downloadVanilla;
  final Future<String?> Function(
    String loader,
    String gameVersion,
    String loaderVersion,
  )
  installLoader;
  final Future<String?> Function(String packPath, String gameDirectory)
  installModpackHandler;

  @override
  bool get isCancelled => _cancelled?.call() ?? false;

  @override
  String join(List<String> parts) => p.joinAll(<String>[root, ...parts]);

  @override
  void report(String stage, double fraction, [String detail = '']) =>
      onProgress(stage, fraction, detail);

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<String?> readText(String path) async {
    final File file = File(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> writeText(String path, String contents) async {
    final File file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  @override
  Future<({int code, String output})> runProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final ProcessResult result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    return (
      code: result.exitCode,
      output: '${result.stdout}\n${result.stderr}',
    );
  }

  @override
  Future<String?> fetchVersion(String version) => downloadVanilla(version);

  @override
  Future<String?> fetchLoader(
    String loader,
    String gameVersion,
    String loaderVersion,
  ) => installLoader(loader, gameVersion, loaderVersion);

  @override
  Future<String?> installModpack(String packPath, String gameDirectory) =>
      installModpackHandler(packPath, gameDirectory);
}

/// The built-in module instance, described for the settings UI.
class BuiltinInstallerModule implements plugin.InstallModule {
  const BuiltinInstallerModule();

  @override
  String get id => 'hcl-installer';

  @override
  String get name => '安装器';

  @override
  String get description => '安装 Minecraft 版本、Fabric / Forge / NeoForge 加载器与 .mrpack 整合包。';

  @override
  Set<plugin.InstallCapability> get capabilities => <plugin.InstallCapability>{
    plugin.InstallCapability.vanilla,
    plugin.InstallCapability.loader,
    plugin.InstallCapability.modpack,
  };

  @override
  String actionLabel(plugin.InstallCapability capability) =>
      switch (capability) {
        plugin.InstallCapability.vanilla => '安装版本',
        plugin.InstallCapability.loader => '安装加载器',
        plugin.InstallCapability.modpack => '安装整合包',
      };

  @override
  Future<String?> run(
    plugin.InstallCapability capability,
    plugin.InstallContext context,
  ) async {
    // The host performs the work through the adapter; running here would need
    // the request payload, which the launcher builds per call.
    return null;
  }
}
