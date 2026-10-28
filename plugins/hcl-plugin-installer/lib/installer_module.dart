/// Install module: vanilla versions, mod loaders and modpacks.
///
/// Self-contained: it only talks to the host through [InstallContext], so the
/// launcher can keep or drop this folder without changing its own code.
library;

import 'contract.dart';

export 'contract.dart';

const String moduleId = 'hcl-installer';
const String moduleName = '安装器';
const String moduleDescription =
    '安装 Minecraft 版本、Fabric / Forge / NeoForge 加载器与 .mrpack 整合包。';
const String moduleVersion = '1.0.0';

/// Argument bundle describing one install, filled by the host.
class InstallRequest {
  const InstallRequest({
    required this.capability,
    this.version,
    this.loader,
    this.loaderVersion,
    this.packPath,
    this.gameDirectory,
  });

  final InstallCapability capability;

  /// Vanilla game version, e.g. "1.21.1".
  final String? version;

  /// `fabric` | `forge` | `neoforge`.
  final String? loader;
  final String? loaderVersion;

  /// Modpack file on disk.
  final String? packPath;

  /// Where a modpack installs to.
  final String? gameDirectory;
}

/// Runs [request] and returns an error message, or null on success.
///
/// The module owns the *sequence* (vanilla first, then loader) and reports
/// each phase through [InstallContext.report].
Future<String?> runInstall(
  InstallRequest request,
  InstallContext context,
) async {
  try {
    switch (request.capability) {
      case InstallCapability.vanilla:
        return await _installVanilla(context, request.version!);
      case InstallCapability.loader:
        // Loaders need the vanilla version present first.
        final String? vanillaError = await _installVanilla(
          context,
          request.version!,
          skipIfPresent: true,
        );
        if (vanillaError != null) return vanillaError;
        return await _installLoader(
          context,
          request.loader!,
          request.version!,
          request.loaderVersion!,
        );
      case InstallCapability.modpack:
        return await _installModpack(
          context,
          request.packPath!,
          request.gameDirectory!,
        );
    }
  } on Object catch (error) {
    return error.toString();
  }
}

// ---------------------------------------------------------------- vanilla

Future<String?> _installVanilla(
  InstallContext context,
  String version, {
  bool skipIfPresent = false,
}) async {
  final String jsonPath = context.join(<String>[
    'versions',
    version,
    '$version.json',
  ]);
  if (skipIfPresent && await context.exists(jsonPath)) {
    context.report('原版 $version 已安装', 1);
    return null;
  }
  context.report('获取版本清单', 0.02);
  // The host resolves the actual download; the module only sequences phases
  // and reports progress, keeping network policy in one place.
  final String? error = await context.fetchVersion(version);
  if (error != null) return error;
  context.report('下载完成', 1);
  return null;
}

// ---------------------------------------------------------------- loader

Future<String?> _installLoader(
  InstallContext context,
  String loader,
  String gameVersion,
  String loaderVersion,
) async {
  final String? error = await context.fetchLoader(
    loader,
    gameVersion,
    loaderVersion,
  );
  return error;
}

// ---------------------------------------------------------------- modpack

Future<String?> _installModpack(
  InstallContext context,
  String packPath,
  String gameDirectory,
) async {
  return context.installModpack(packPath, gameDirectory);
}
