/// Contract a host launcher implements and a module consumes.
///
/// Kept inside the module so the module never imports the host package.
library;

/// What a module knows how to install.
enum InstallCapability { vanilla, loader, modpack }

/// Everything a module may use. Deliberately narrow: no UI, no global state.
abstract class InstallContext {
  /// Absolute `.minecraft` root downloads go into.
  String get root;

  /// The host's `.minecraft` path separator conventions (usually `/`).
  String join(List<String> parts);

  /// Reports progress; the host forwards it to its own task bar.
  void report(String stage, double fraction, [String detail]);

  /// Whether the user cancelled.
  bool get isCancelled;

  /// Whether a file already exists.
  Future<bool> exists(String path);

  /// Reads a UTF-8 text file, or null when missing.
  Future<String?> readText(String path);

  /// Writes a UTF-8 text file, creating parent folders.
  Future<void> writeText(String path, String contents);

  /// Runs a process and returns (exitCode, merged output).
  Future<({int code, String output})> runProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });

  /// Downloads a vanilla version. Implemented by the host so download policy
  /// (mirrors, retries, hashing) stays in one place.
  Future<String?> fetchVersion(String version);

  /// Installs a loader on top of an installed vanilla version.
  Future<String?> fetchLoader(
    String loader,
    String gameVersion,
    String loaderVersion,
  );

  /// Installs a modpack file into [gameDirectory].
  Future<String?> installModpack(String packPath, String gameDirectory);
}

/// A loaded, runnable install module.
abstract class InstallModule {
  String get id;
  String get name;
  String get description;
  Set<InstallCapability> get capabilities;
  String actionLabel(InstallCapability capability);
  Future<String?> run(InstallCapability capability, InstallContext context);
}
