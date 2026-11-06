import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/java_runtime.dart';

/// Pure-Dart Java discovery.
class JavaScanner {
  JavaScanner._();

  static Future<List<JavaRuntime>> scan() async {
    final Map<String, String> candidates = <String, String>{};
    final String executable = Platform.isWindows ? 'java.exe' : 'java';

    void addCandidate(String? path, String source) {
      if (path == null || path.isEmpty) return;
      final String normalized = p.normalize(p.absolute(path));
      candidates.putIfAbsent(normalized, () => source);
    }

    final String? javaHome = Platform.environment['JAVA_HOME'];
    if (javaHome != null && javaHome.isNotEmpty) {
      addCandidate(p.join(javaHome, 'bin', executable), 'JAVA_HOME');
    }

    final String pathVariable = Platform.environment['PATH'] ?? '';
    final String separator = Platform.isWindows ? ';' : ':';
    for (final String entry in pathVariable.split(separator)) {
      if (entry.trim().isEmpty) continue;
      addCandidate(p.join(entry, executable), 'PATH');
    }

    for (final String directory in _commonRoots()) {
      await _addRoot(directory, executable, addCandidate);
    }

    final List<JavaRuntime> runtimes = <JavaRuntime>[];
    final Set<String> seen = <String>{};
    for (final MapEntry<String, String> candidate in candidates.entries) {
      final File file = File(candidate.key);
      if (!await file.exists()) continue;
      String identity = candidate.key;
      try {
        identity = await file.resolveSymbolicLinks();
      } on FileSystemException {
        // Keep the normalized path; the executable may be a broken link.
      }
      if (!seen.add(identity)) continue;
      final JavaRuntime? runtime = await _probe(
        candidate.key,
        source: candidate.value,
      );
      if (runtime != null) runtimes.add(runtime);
    }

    runtimes.sort((JavaRuntime a, JavaRuntime b) {
      final int byMajor = b.major.compareTo(a.major);
      if (byMajor != 0) return byMajor;
      return a.path.compareTo(b.path);
    });
    return runtimes;
  }

  static List<String> _commonRoots() {
    final Map<String, String> env = Platform.environment;
    final String home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    if (Platform.isWindows) {
      return <String>[
        if (env['ProgramFiles'] != null) env['ProgramFiles']!,
        if (env['ProgramFiles(x86)'] != null) env['ProgramFiles(x86)']!,
        if (env['ProgramW6432'] != null) env['ProgramW6432']!,
        p.join(home, '.jdks'),
      ];
    }
    return <String>[
      '/usr/lib/jvm',
      '/usr/java',
      '/opt/java',
      '/opt/jdk',
      p.join(home, '.jdks'),
      p.join(home, '.sdkman', 'candidates', 'java'),
      p.join(home, '.asdf', 'installs', 'java'),
    ];
  }

  static Future<void> _addRoot(
    String root,
    String executable,
    void Function(String?, String) addCandidate,
  ) async {
    final Directory directory = Directory(root);
    if (!await directory.exists()) return;
    addCandidate(p.join(root, 'bin', executable), 'common');
    try {
      await for (final FileSystemEntity entity in directory.list(
        followLinks: false,
      )) {
        if (entity is! Directory) continue;
        addCandidate(p.join(entity.path, 'bin', executable), 'common');
      }
    } on FileSystemException {
      // Unreadable roots are skipped; the user can add a JDK manually.
    }
  }

  static Future<JavaRuntime?> _probe(
    String executable, {
    required String source,
  }) async {
    try {
      final ProcessResult result = await Process.run(
        executable,
        <String>['-version'],
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      ).timeout(const Duration(seconds: 5));
      final String output = '${result.stdout}\n${result.stderr}';
      return parseVersionOutput(output, path: executable, source: source);
    } on ProcessException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// Parses the combined stdout/stderr of `java -version`.
  static JavaRuntime? parseVersionOutput(
    String output, {
    required String path,
    String source = 'manual',
  }) {
    final RegExpMatch? match =
        RegExp(
          r'(?:openjdk|java)\s+version\s+"([^"]+)"',
          caseSensitive: false,
        ).firstMatch(output) ??
        RegExp(r'version\s+"([^"]+)"', caseSensitive: false).firstMatch(output);
    final String? rawVersion = match?.group(1);
    if (rawVersion == null || rawVersion.isEmpty) return null;

    final String lower = output.toLowerCase();
    String vendor = 'Unknown';
    if (lower.contains('temurin') || lower.contains('adoptium')) {
      vendor = 'Eclipse Temurin';
    } else if (lower.contains('corretto')) {
      vendor = 'Amazon Corretto';
    } else if (lower.contains('zulu')) {
      vendor = 'Azul Zulu';
    } else if (lower.contains('microsoft')) {
      vendor = 'Microsoft';
    } else if (lower.contains('graalvm')) {
      vendor = 'GraalVM';
    } else if (lower.contains('liberica')) {
      vendor = 'BellSoft Liberica';
    } else if (lower.contains('semeru')) {
      vendor = 'IBM Semeru';
    } else if (lower.contains('oracle') ||
        lower.contains('java(tm)') ||
        lower.contains('java hotspot')) {
      vendor = 'Oracle';
    } else if (lower.contains('openjdk')) {
      vendor = 'OpenJDK';
    }

    final String arch;
    if (lower.contains('64-bit')) {
      arch = 'x64';
    } else if (lower.contains('32-bit')) {
      arch = 'x86';
    } else if (lower.contains('aarch64') || lower.contains('arm64')) {
      arch = 'arm64';
    } else {
      arch = 'x64';
    }

    return JavaRuntime(
      path: path,
      version: rawVersion,
      major: _majorFromVersion(rawVersion),
      vendor: vendor,
      arch: arch,
      source: source,
    );
  }

  static int _majorFromVersion(String version) {
    final String normalized = version.startsWith('1.')
        ? version.substring(2)
        : version;
    final RegExpMatch? match = RegExp(r'^\d+').firstMatch(normalized);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }
}
