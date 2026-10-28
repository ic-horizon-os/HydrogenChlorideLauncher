import 'dart:convert';
import 'dart:io';

/// Length-prefixed JSON persistence with atomic writes.
///
/// Tokens are written with mode 0600 on POSIX systems. Alpha does not use an
/// OS keychain; this is documented as a known limitation.
class JsonStore {
  const JsonStore();

  Future<Object?> read(File file) async {
    try {
      if (!await file.exists()) return null;
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readMap(File file) async {
    final Object? value = await read(file);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((Object? key, Object? item) => MapEntry('$key', item));
    }
    return null;
  }

  Future<List<Object?>?> readList(File file) async {
    final Object? value = await read(file);
    if (value is List) return value;
    return null;
  }

  Future<void> write(File file, Object value, {bool private = false}) async {
    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (private && !Platform.isWindows) {
      await Process.run('chmod', <String>['600', temp.path]);
    }
    await temp.rename(file.path);
  }
}
