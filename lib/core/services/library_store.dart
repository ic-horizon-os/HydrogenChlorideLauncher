import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_paths.dart';
import '../config/json_store.dart';
import '../demo/demo_data.dart';
import '../models/app_entry.dart';

/// Persisted library entries.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this.paths, {JsonStore? jsonStore})
    : _json = jsonStore ?? const JsonStore();

  final AppPaths paths;
  final JsonStore _json;
  final List<AppEntry> _entries = <AppEntry>[];

  List<AppEntry> get entries => List<AppEntry>.unmodifiable(_entries);

  Future<void> load() async {
    final List<Object?>? raw = await _json.readList(paths.libraryFile);
    if (raw == null) {
      notifyListeners();
      return;
    }
    _entries
      ..clear()
      ..addAll(
        raw.whereType<Map>().map(
          (Map item) => AppEntry.fromJson(
            item.map((Object? key, Object? value) => MapEntry('$key', value)),
          ),
        ),
      );
    notifyListeners();
  }

  AppEntry? byId(String id) {
    for (final AppEntry entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> add(AppEntry entry) async {
    _entries.add(entry);
    notifyListeners();
    await save();
  }

  Future<void> update(AppEntry entry) async {
    final int index = _entries.indexWhere(
      (AppEntry item) => item.id == entry.id,
    );
    if (index < 0) return;
    _entries[index] = entry;
    notifyListeners();
    await save();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((AppEntry entry) => entry.id == id);
    notifyListeners();
    await save();
  }

  Future<void> recordPlaytime(
    String id, {
    required Duration duration,
    required DateTime startedAt,
  }) async {
    final AppEntry? entry = byId(id);
    if (entry == null) return;
    entry.totalPlayMs += duration.inMilliseconds;
    entry.lastPlayed = DateTime.now();
    notifyListeners();
    await save();
  }

  /// Adds the built-in sample entries, keeping anything the user installed.
  Future<void> addDemoEntries() async {
    final Set<String> existing = _entries.map((AppEntry e) => e.id).toSet();
    final List<AppEntry> samples = DemoData.buildEntries();
    final List<AppEntry> missing = samples
        .where((AppEntry e) => !existing.contains(e.id))
        .toList(growable: false);
    if (missing.isEmpty) return;
    _entries.addAll(missing);
    notifyListeners();
    await save();
  }

  /// Removes every entry flagged as sample data.
  Future<void> removeDemoEntries() async {
    final int before = _entries.length;
    _entries.removeWhere((AppEntry entry) => entry.isDemo);
    if (_entries.length == before) return;
    notifyListeners();
    await save();
  }

  Future<void> save() {
    return _json.write(
      paths.libraryFile,
      _entries.map((AppEntry entry) => entry.toJson()).toList(),
    );
  }

  /// Convenience for tests and diagnostics.
  String toDebugJson() =>
      jsonEncode(_entries.map((AppEntry entry) => entry.toJson()).toList());
}
