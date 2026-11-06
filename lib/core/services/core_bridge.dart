import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/java_runtime.dart';
import 'java_scanner.dart';

class JavaScanResult {
  const JavaScanResult({required this.runtimes, required this.backend});

  final List<JavaRuntime> runtimes;
  final String backend;
}

/// Platform helpers implemented in pure Dart: Java discovery, directory
/// size, hashing and credential storage. The launcher ships a single binary
/// and no extra toolchain is needed to build it.
class CoreBridge {
  CoreBridge({this.explicitPath});

  /// Kept for source compatibility with older callers; unused.
  final String? explicitPath;

  /// Always false: tokens currently persist in the 0600 file; the
  /// secretGet/Set calls remain available for keychain-aware callers.
  bool get isAvailable => false;

  String get backendLabel => 'Dart';

  Future<JavaScanResult> scanJava() async {
    return JavaScanResult(runtimes: await JavaScanner.scan(), backend: 'Dart');
  }

  Future<int> directorySize(String path) async {
    final Directory directory = Directory(path);
    int bytes = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final FileSystemEntity entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        try {
          bytes += await entity.length();
        } on FileSystemException {
          // Skip files that disappear during the walk.
        }
      }
    } on FileSystemException {
      return bytes;
    }
    return bytes;
  }

  /// Streaming SHA-256 of a file. Returns null when the file cannot be read.
  Future<String?> hashFile(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return null;
      return (await sha256.bind(file.openRead()).first).toString();
    } on Object {
      return null;
    }
  }

  // ------------------------------------------------------------------ secrets

  static const String _service = 'hydrogen-chloride-launcher';

  /// Reads a stored credential from the OS keychain, or reports that no
  /// backend is available so callers can fall back to their own file.
  Future<SecretReadResult> secretGet(String account) async {
    if (Platform.isWindows) {
      return const SecretReadResult(backend: 'unavailable', value: null);
    }
    final ProcessResult result = await _secretTool(<String>[
      'lookup',
      'service',
      _service,
      'account',
      account,
    ]);
    if (result.exitCode != 0) {
      // Distinguish "missing entry" from "no secret-tool at all".
      return SecretReadResult(
        backend: result.exitCode == _toolMissing
            ? 'unavailable'
            : 'secret-service',
        value: null,
      );
    }
    final String raw = (result.stdout as String).trim();
    if (raw.isEmpty) {
      return const SecretReadResult(backend: 'secret-service', value: null);
    }
    try {
      final Object? decoded = jsonDecode(raw);
      return SecretReadResult(
        backend: 'secret-service',
        value: decoded is Map<String, dynamic> ? decoded : null,
      );
    } on FormatException {
      return const SecretReadResult(backend: 'secret-service', value: null);
    }
  }

  Future<bool> secretSet(String account, String secret) async {
    if (Platform.isWindows) return false;
    final ProcessResult result = await _secretTool(<String>[
      'store',
      '--label',
      'Hydrogen Chloride Launcher',
      'service',
      _service,
      'account',
      account,
    ], stdinText: secret);
    return result.exitCode == 0;
  }

  Future<bool> secretDelete(String account) async {
    if (Platform.isWindows) return false;
    final ProcessResult result = await _secretTool(<String>[
      'clear',
      'service',
      _service,
      'account',
      account,
    ]);
    // `clear` exits non-zero when the entry does not exist; treat that as done.
    return result.exitCode == 0 || result.exitCode == 1;
  }

  static const int _toolMissing = 127;

  Future<ProcessResult> _secretTool(
    List<String> arguments, {
    String? stdinText,
  }) async {
    try {
      final Process process = await Process.start('secret-tool', arguments);
      if (stdinText != null) {
        process.stdin.write(stdinText);
      }
      await process.stdin.close();
      final String out = await process.stdout.transform(utf8.decoder).join();
      await process.stderr.drain<void>();
      return ProcessResult(process.pid, await process.exitCode, out, '');
    } on ProcessException {
      return ProcessResult(0, _toolMissing, '', '');
    }
  }

  /// Whether the Linux Secret Service is reachable through `secret-tool`.
  static Future<bool> secretBackendAvailable() async {
    if (Platform.isWindows) return false;
    try {
      final Process process = await Process.start('secret-tool', <String>[
        '--version',
      ]);
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      return await process.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

class SecretReadResult {
  const SecretReadResult({required this.backend, required this.value});

  /// `secret-service` or `unavailable`.
  final String backend;
  final Map<String, dynamic>? value;

  bool get present => value != null;
}

/// Exposed for callers that need a path-independent identity.
String secretServiceName() => 'hydrogen-chloride-launcher';

/// Convenience used by the settings pane to show where data lives.
String describeSecretBackend() =>
    Platform.isWindows ? 'Windows 凭据存储' : 'Linux Secret Service';
