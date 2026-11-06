import 'package:path/path.dart' as p;

import '../utils/json_utils.dart';

/// A Java runtime discovered by the Dart scanner.
class JavaRuntime {
  const JavaRuntime({
    required this.path,
    required this.version,
    required this.major,
    required this.vendor,
    required this.arch,
    required this.source,
  });

  factory JavaRuntime.fromJson(Map<String, dynamic> json) {
    final String path = asString(json['path']);
    final String version = asString(json['version'], 'unknown');
    return JavaRuntime(
      path: path,
      version: version,
      major: asInt(json['major'], _majorFromVersion(version)),
      vendor: asString(json['vendor'], 'Unknown'),
      arch: asString(json['arch'], 'x64'),
      source: asString(json['source'], 'manual'),
    );
  }

  /// Absolute path to the `java` executable.
  final String path;
  final String version;
  final int major;
  final String vendor;
  final String arch;
  final String source;

  String get home => p.dirname(p.dirname(path));

  String get label => 'Java $major · $vendor';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'version': version,
    'major': major,
    'vendor': vendor,
    'arch': arch,
    'source': source,
  };

  static int _majorFromVersion(String version) {
    final String normalized = version.startsWith('1.')
        ? version.substring(2)
        : version;
    return int.tryParse(RegExp(r'^\d+').stringMatch(normalized) ?? '') ?? 0;
  }
}
