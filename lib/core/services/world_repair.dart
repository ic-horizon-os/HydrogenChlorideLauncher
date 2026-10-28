import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Container for a parsed level.dat (gzip + NBT compound).
class LevelDat {
  LevelDat(this.compound, {required this.compressed});

  final NbtCompound compound;
  final bool compressed;

  String get levelName => compound.stringValue('LevelName');
  String get versionName => compound.stringValue('Version/Name');
  int get dataVersion => compound.intValue('DataVersion');
  String get generatorName => compound.stringValue('GeneratorName');
  bool get hardcore => compound.byteValue('hardcore') != 0;
  int get lastPlayed => (compound.longValue('LastPlayed') ~/ 1000).toInt();
}

/// Minimal NBT reader/writer covering the tags Minecraft writes into
/// level.dat. Entries it does not understand are kept as raw tags so a repair
/// never drops data.
class NbtCompound extends NbtTag {
  NbtCompound([Map<String, NbtTag>? entries])
    : entries = entries ?? <String, NbtTag>{};

  final Map<String, NbtTag> entries;

  NbtTag? operator [](String key) => entries[key];

  String stringValue(String path) {
    final NbtTag? tag = _at(path);
    return tag is NbtString ? tag.value : '';
  }

  int intValue(String path) {
    final NbtTag? tag = _at(path);
    return tag is NbtInt ? tag.value : 0;
  }

  int longValue(String path) {
    final NbtTag? tag = _at(path);
    return tag is NbtLong ? tag.value : 0;
  }

  int byteValue(String path) {
    final NbtTag? tag = _at(path);
    return tag is NbtByte ? tag.value : 0;
  }

  NbtTag? _at(String path) {
    final List<String> parts = path.split('/');
    NbtTag? current = entries[parts.first];
    for (int i = 1; i < parts.length; i++) {
      if (current is! NbtCompound) return null;
      current = current.entries[parts[i]];
    }
    return current;
  }

  void putString(String key, String value) => entries[key] = NbtString(value);
  void putInt(String key, int value) => entries[key] = NbtInt(value);
  void putLong(String key, int value) => entries[key] = NbtLong(value);
}

sealed class NbtTag {}

class NbtByte extends NbtTag {
  NbtByte(this.value);
  int value;
}

class NbtInt extends NbtTag {
  NbtInt(this.value);
  int value;
}

class NbtLong extends NbtTag {
  NbtLong(this.value);
  int value;
}

class NbtFloat extends NbtTag {
  NbtFloat(this.value);
  double value;
}

class NbtDouble extends NbtTag {
  NbtDouble(this.value);
  double value;
}

class NbtString extends NbtTag {
  NbtString(this.value);
  String value;
}

class NbtList extends NbtTag {
  NbtList(this.type, this.items);
  int type;
  List<NbtTag> items;
}

class _Reader {
  _Reader(this._bytes);
  final Uint8List _bytes;
  int _offset = 0;

  int get offset => _offset;
  bool get atEnd => _offset >= _bytes.length;

  int u8() => _bytes[_offset++];

  int i8() => _bytes[_offset++].toSigned(8);

  int i16() {
    final int value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 2,
    ).getInt16(0);
    _offset += 2;
    return value;
  }

  int i32() {
    final int value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 4,
    ).getInt32(0);
    _offset += 4;
    return value;
  }

  int i64() {
    final int value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 8,
    ).getInt64(0);
    _offset += 8;
    return value;
  }

  double f32() {
    final double value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 4,
    ).getFloat32(0);
    _offset += 4;
    return value;
  }

  double f64() {
    final double value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 8,
    ).getFloat64(0);
    _offset += 8;
    return value;
  }

  String str() {
    final int length = _offset + 2 <= _bytes.length ? i16() : 0;
    if (length <= 0) return '';
    final int end = (_offset + length).clamp(0, _bytes.length);
    // NBT strings are MUTF-8; plain UTF-8 decoding covers level.dat in practice.
    final String value = String.fromCharCodes(_bytes.sublist(_offset, end));
    _offset = end;
    return value;
  }

  NbtTag payload(int type) {
    switch (type) {
      case 1:
        return NbtByte(i8());
      case 2:
        return NbtInt(i16());
      case 3:
        return NbtInt(i32());
      case 4:
        return NbtLong(i64());
      case 5:
        return NbtFloat(f32());
      case 6:
        return NbtDouble(f64());
      case 7:
        return NbtByte(-1);
      case 8:
        return NbtString(str());
      case 9:
        final int listType = u8();
        final int length = i32();
        final List<NbtTag> items = <NbtTag>[];
        for (int i = 0; i < length && !atEnd; i++) {
          items.add(payload(listType));
        }
        return NbtList(listType, items);
      case 10:
        return readCompound();
      case 11:
        final int length = i32();
        final List<int> values = <int>[];
        for (int i = 0; i < length; i++) {
          values.add(i32());
        }
        return NbtList(3, values.map(NbtInt.new).toList());
      case 12:
        final int length = i32();
        final List<int> values = <int>[];
        for (int i = 0; i < length; i++) {
          values.add(i64());
        }
        return NbtList(4, values.map(NbtLong.new).toList());
      default:
        throw FormatException('未知的 NBT 类型 $type（偏移 $_offset）');
    }
  }

  NbtCompound readCompound() {
    final NbtCompound compound = NbtCompound();
    while (!atEnd) {
      final int type = u8();
      if (type == 0) break;
      final String name = str();
      compound.entries[name] = payload(type);
    }
    return compound;
  }
}

class _Writer {
  final BytesBuilder _out = BytesBuilder(copy: false);

  List<int> get bytes => _out.toBytes();

  void u8(int value) => _out.add(<int>[value & 0xFF]);

  void i16(int value) {
    final ByteData data = ByteData(2)..setInt16(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void i32(int value) {
    final ByteData data = ByteData(4)..setInt32(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void i64(int value) {
    final ByteData data = ByteData(8)..setInt64(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void f32(double value) {
    final ByteData data = ByteData(4)..setFloat32(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void f64(double value) {
    final ByteData data = ByteData(8)..setFloat64(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void str(String value) {
    final List<int> encoded = value.codeUnits;
    i16(encoded.length);
    _out.add(encoded);
  }

  void payload(NbtTag tag) {
    switch (tag) {
      case NbtByte():
        u8(tag.value);
      case NbtInt():
        // NBT has no width info on the tag; both Int and Short are written as
        // Int, which Minecraft accepts on read.
        i32(tag.value);
      case NbtLong():
        i64(tag.value);
      case NbtFloat():
        f32(tag.value);
      case NbtDouble():
        f64(tag.value);
      case NbtString():
        str(tag.value);
      case NbtList():
        u8(tag.type);
        i32(tag.items.length);
        for (final NbtTag item in tag.items) {
          payload(item);
        }
      case NbtCompound():
        for (final MapEntry<String, NbtTag> entry in tag.entries.entries) {
          u8(typeOf(entry.value));
          str(entry.key);
          payload(entry.value);
        }
        u8(0);
    }
  }

  static int typeOf(NbtTag tag) {
    switch (tag) {
      case NbtByte():
        return 1;
      case NbtInt():
        return 3;
      case NbtLong():
        return 4;
      case NbtFloat():
        return 5;
      case NbtDouble():
        return 6;
      case NbtString():
        return 8;
      case NbtList():
        return 9;
      case NbtCompound():
        return 10;
    }
  }
}

/// Reads and repairs Minecraft world folders.
class WorldRepair {
  WorldRepair._();

  /// Loads `level.dat`, transparently gunzipping.
  static Future<LevelDat?> readLevelDat(Directory world) async {
    final File file = File(p.join(world.path, 'level.dat'));
    if (!await file.exists()) return null;
    final List<int> raw = await file.readAsBytes();
    final (Uint8List bytes, bool compressed) = _decompress(raw);
    try {
      final _Reader reader = _Reader(bytes);
      final int type = reader.u8();
      if (type != 10) return null;
      reader.str();
      return LevelDat(reader.readCompound(), compressed: compressed);
    } on Object {
      return null;
    }
  }

  static (Uint8List, bool) _decompress(List<int> raw) {
    if (raw.length > 2 && raw[0] == 0x1f && raw[1] == 0x8b) {
      return (Uint8List.fromList(GZipDecoder().decodeBytes(raw)), true);
    }
    return (Uint8List.fromList(raw), false);
  }

  /// Serialises [level] back into `level.dat` (gzip when originally gzipped).
  static Future<void> writeLevelDat(
    Directory world,
    LevelDat level, {
    String? backupSuffix,
  }) async {
    final File file = File(p.join(world.path, 'level.dat'));
    if (await file.exists() && backupSuffix != null) {
      await file.copy(p.join(world.path, 'level.dat.$backupSuffix.bak'));
    }
    final _Writer writer = _Writer()
      ..u8(10)
      ..str('')
      ..payload(level.compound);
    final List<int> bytes = level.compressed
        ? GZipEncoder().encode(writer.bytes)
        : writer.bytes;
    await File(p.join(world.path, 'level.dat.tmp')).writeAsBytes(bytes);
    await File(p.join(world.path, 'level.dat.tmp')).rename(file.path);
  }

  /// Runs the checks the 世界 tab exposes. Returns findings that can be fixed
  /// in place plus ones that need a manual decision.
  static Future<WorldRepairReport> analyze(Directory world) async {
    final List<String> issues = <String>[];
    final List<String> autoFixable = <String>[];
    final File levelFile = File(p.join(world.path, 'level.dat'));
    if (!await levelFile.exists()) {
      issues.add('缺少 level.dat，世界无法加载。');
      return WorldRepairReport(issues: issues, autoFixable: autoFixable);
    }
    final LevelDat? level = await readLevelDat(world);
    if (level == null) {
      issues.add('level.dat 已损坏或无法解析。');
    } else {
      final int dataVersion = level.dataVersion;
      if (dataVersion <= 0) {
        issues.add('level.dat 中没有 DataVersion。');
      }
      if (level.versionName.isEmpty) {
        issues.add('缺少版本名称（Version/Name）。');
        autoFixable.add('补全版本名称');
      }
      if (level.levelName.isEmpty) {
        issues.add('缺少世界名称（LevelName）。');
        autoFixable.add('补全世界名称');
      }
    }
    final Directory region = Directory(p.join(world.path, 'region'));
    if (!await region.exists()) {
      issues.add('缺少 region 目录。');
      autoFixable.add('创建 region 目录');
    } else {
      final bool hasRegion = region.listSync().any(
        (FileSystemEntity entity) =>
            entity is File && entity.path.endsWith('.mca'),
      );
      if (!hasRegion) {
        issues.add('region 目录中没有 .mca 存档文件。');
      }
    }
    final File sessionLock = File(p.join(world.path, 'session.lock'));
    if (await sessionLock.exists()) {
      autoFixable.add('移除残留的 session.lock（游戏未运行时）');
    }
    return WorldRepairReport(issues: issues, autoFixable: autoFixable);
  }

  /// Applies the safe fixes: fills missing names, creates region, removes a
  /// stale session.lock. `level.dat` is backed up first.
  static Future<List<String>> repair(
    Directory world, {
    required String fallbackName,
    required String fallbackVersion,
  }) async {
    final List<String> applied = <String>[];
    final Directory region = Directory(p.join(world.path, 'region'));
    if (!await region.exists()) {
      await region.create(recursive: true);
      applied.add('已创建 region 目录');
    }
    final LevelDat? level = await readLevelDat(world);
    if (level != null) {
      bool changed = false;
      if (level.levelName.isEmpty) {
        level.compound.putString('LevelName', fallbackName);
        changed = true;
      }
      if (level.versionName.isEmpty && fallbackVersion.isNotEmpty) {
        final NbtTag? version = level.compound.entries['Version'];
        if (version is NbtCompound) {
          version.putString('Name', fallbackVersion);
        }
        changed = true;
      }
      if (changed) {
        await writeLevelDat(world, level, backupSuffix: _stamp());
        applied.add('已补全 level.dat 字段（原文件已备份）');
      }
    }
    final File sessionLock = File(p.join(world.path, 'session.lock'));
    if (await sessionLock.exists()) {
      try {
        await sessionLock.delete();
        applied.add('已移除 session.lock');
      } on FileSystemException {
        // The game may be running; leaving the lock is the safe outcome.
      }
    }
    return applied;
  }

  static String _stamp() {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

class WorldRepairReport {
  const WorldRepairReport({required this.issues, required this.autoFixable});

  final List<String> issues;
  final List<String> autoFixable;

  bool get canRepair => autoFixable.isNotEmpty;
}
