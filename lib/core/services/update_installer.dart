import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Replaces the installed bundle with a downloaded archive.
///
/// Layout assumptions match the release packages: tar.gz for Linux contains a
/// top-level `bundle/` directory, and the Windows zip contains the release
/// runner at its root.
///
/// A running executable cannot be overwritten on Windows, so there the new
/// files are staged and swapped by a short-lived helper before the app
/// restarts. On Linux the swap happens in place.
class UpdateInstaller {
  const UpdateInstaller();

  Future<void> install(
    File archive, {
    String? executableName,
    void Function(String stage, double fraction)? onProgress,
  }) async {
    final Directory appDir = File(Platform.resolvedExecutable).parent;
    final String exeName =
        executableName ?? p.basename(Platform.resolvedExecutable);
    final Directory staging = Directory('${appDir.path}.update-tmp');
    final Directory backup = Directory('${appDir.path}.update-backup');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    onProgress?.call('解压更新包', 0.1);
    await _extract(archive, staging, onProgress);

    final Directory root = await _findBundleRoot(staging, exeName);
    onProgress?.call('备份当前版本', 0.6);
    if (await backup.exists()) await backup.delete(recursive: true);
    await _copyInto(appDir, backup);

    onProgress?.call('替换文件', 0.75);
    if (Platform.isWindows) {
      await _stageWindowsSwap(appDir, root, exeName);
    } else {
      await _copyInto(root, appDir);
    }
    onProgress?.call('完成', 1);
  }

  Future<void> _extract(
    File archive,
    Directory target,
    void Function(String, double)? onProgress,
  ) async {
    final List<int> bytes = await archive.readAsBytes();
    final String name = archive.path.toLowerCase();
    final Archive content;
    try {
      content = name.endsWith('.tar.gz') || name.endsWith('.tgz')
          ? TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes))
          : ZipDecoder().decodeBytes(bytes);
    } on ArchiveException {
      throw FormatException('无法解压更新包：${p.basename(name)}');
    }
    final int total = content.files.length;
    int done = 0;
    for (final ArchiveFile file in content.files) {
      if (file.isFile) {
        final File out = File(
          p.joinAll(<String>[target.path, ...file.name.split('/')]),
        );
        await out.parent.create(recursive: true);
        await out.writeAsBytes(file.content as List<int>);
      }
      done++;
      if (done % 50 == 0) {
        onProgress?.call(
          '解压更新包',
          0.1 + (done / (total == 0 ? 1 : total)) * 0.45,
        );
      }
    }
  }

  Future<Directory> _findBundleRoot(Directory staging, String exeName) async {
    final File direct = File(p.join(staging.path, exeName));
    if (await direct.exists()) return staging;
    await for (final FileSystemEntity entity in staging.list()) {
      if (entity is Directory) {
        if (await File(p.join(entity.path, exeName)).exists()) {
          return entity;
        }
        final File nested = File(p.join(entity.path, 'bundle', exeName));
        if (await nested.exists()) return nested.parent;
      }
    }
    throw StateError('更新包中找不到 $exeName。');
  }

  Future<void> _copyInto(Directory source, Directory target) async {
    await for (final FileSystemEntity entity in source.list(recursive: true)) {
      final String relative = p.relative(entity.path, from: source.path);
      final String destination = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        final File out = File(destination);
        await out.parent.create(recursive: true);
        await entity.copy(out.path);
        // Preserve the executable bit for binaries.
        if (!Platform.isWindows && p.extension(out.path).isEmpty) {
          await Process.run('chmod', <String>['755', out.path]);
        }
      }
    }
  }

  /// Windows: write a helper script that waits for this process to exit,
  /// copies the staged files over the install directory, and starts the app.
  Future<void> _stageWindowsSwap(
    Directory appDir,
    Directory source,
    String exeName,
  ) async {
    final File script = File(p.join(appDir.parent.path, 'hcl-update.ps1'));
    await script.writeAsString('''
\$ErrorActionPreference = 'Stop'
Wait-Process -Id $pid -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Copy-Item -Recurse -Force -Path '${source.path}\\*' -Destination '${appDir.path}'
Start-Process -FilePath '${p.join(appDir.path, exeName)}'
Remove-Item -Force '\$PSCommandPath'
''');
    await Process.start('powershell', <String>[
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
    ], mode: ProcessStartMode.detached);
  }
}
