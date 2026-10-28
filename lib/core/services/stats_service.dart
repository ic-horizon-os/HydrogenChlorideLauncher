import 'package:flutter/foundation.dart';

import '../config/app_paths.dart';
import '../config/json_store.dart';
import '../demo/demo_data.dart';
import '../models/play_session.dart';

enum StatsKindFilter { all, games, utilities }

enum StatsEraFilter { all, legacy, modern }

class StatsFilter {
  const StatsFilter({
    this.kind = StatsKindFilter.all,
    this.loader,
    this.era = StatsEraFilter.all,
  });

  final StatsKindFilter kind;

  /// `null` = any, `Vanilla` = no loader, otherwise Fabric/Forge/NeoForge.
  final String? loader;
  final StatsEraFilter era;

  StatsFilter copyWith({
    StatsKindFilter? kind,
    Object? loader = _unset,
    StatsEraFilter? era,
  }) {
    return StatsFilter(
      kind: kind ?? this.kind,
      loader: identical(loader, _unset) ? this.loader : loader as String?,
      era: era ?? this.era,
    );
  }

  static const Object _unset = Object();
}

class StatsSummary {
  const StatsSummary({
    required this.total,
    required this.weekTotal,
    required this.sessionCount,
    required this.byCategory,
    required this.byApp,
    required this.byLoader,
    required this.byDay,
  });

  factory StatsSummary.empty() {
    return const StatsSummary(
      total: Duration.zero,
      weekTotal: Duration.zero,
      sessionCount: 0,
      byCategory: <String, Duration>{},
      byApp: <String, Duration>{},
      byLoader: <String, Duration>{},
      byDay: <DateTime, Duration>{},
    );
  }

  final Duration total;
  final Duration weekTotal;
  final int sessionCount;
  final Map<String, Duration> byCategory;
  final Map<String, Duration> byApp;
  final Map<String, Duration> byLoader;
  final Map<DateTime, Duration> byDay;

  Duration get averageSession {
    if (sessionCount == 0) return Duration.zero;
    return Duration(seconds: total.inSeconds ~/ sessionCount);
  }
}

class StatsService extends ChangeNotifier {
  StatsService(this.paths, {JsonStore? jsonStore})
    : _json = jsonStore ?? const JsonStore();

  final AppPaths paths;
  final JsonStore _json;
  final List<PlaySession> _sessions = <PlaySession>[];

  List<PlaySession> get sessions => List<PlaySession>.unmodifiable(_sessions);

  /// Adds the built-in sample sessions without touching real ones.
  Future<void> addDemoSessions() async {
    String key(PlaySession s) =>
        '${s.appId}|${s.startedAt.toIso8601String()}|${s.durationSeconds}';
    final Set<String> existing = _sessions.map(key).toSet();
    final List<PlaySession> samples = DemoData.buildSessions();
    final List<PlaySession> missing = samples
        .where((PlaySession s) => !existing.contains(key(s)))
        .toList(growable: false);
    if (missing.isEmpty) return;
    _sessions.addAll(missing);
    _sessions.sort(
      (PlaySession a, PlaySession b) => b.startedAt.compareTo(a.startedAt),
    );
    notifyListeners();
    await save();
  }

  Future<void> removeDemoSessions() async {
    final int before = _sessions.length;
    _sessions.removeWhere((PlaySession s) => s.isDemo);
    if (_sessions.length == before) return;
    notifyListeners();
    await save();
  }

  Future<void> load() async {
    final List<Object?>? raw = await _json.readList(paths.sessionsFile);
    if (raw == null) {
      notifyListeners();
      return;
    }
    _sessions
      ..clear()
      ..addAll(
        raw.whereType<Map>().map(
          (Map item) => PlaySession.fromJson(
            item.map((Object? key, Object? value) => MapEntry('$key', value)),
          ),
        ),
      );
    _sessions.sort(
      (PlaySession a, PlaySession b) => b.startedAt.compareTo(a.startedAt),
    );
    notifyListeners();
  }

  Future<void> record(PlaySession session) async {
    if (session.durationSeconds <= 0) return;
    _sessions.add(session);
    _sessions.sort(
      (PlaySession a, PlaySession b) => a.startedAt.compareTo(b.startedAt),
    );
    if (_sessions.length > 5000) {
      _sessions.removeRange(0, _sessions.length - 5000);
    }
    notifyListeners();
    await save();
  }

  StatsSummary summary({
    bool includeDemo = true,
    StatsFilter filter = const StatsFilter(),
  }) {
    final List<PlaySession> filtered = _sessions
        .where((PlaySession session) => includeDemo || !session.isDemo)
        .where((PlaySession session) => _matches(session, filter))
        .toList(growable: false);

    if (filtered.isEmpty) {
      final StatsSummary empty = StatsSummary.empty();
      return StatsSummary(
        total: empty.total,
        weekTotal: empty.weekTotal,
        sessionCount: 0,
        byCategory: empty.byCategory,
        byApp: empty.byApp,
        byLoader: empty.byLoader,
        byDay: _emptyDays(),
      );
    }

    int totalSeconds = 0;
    int weekSeconds = 0;
    final DateTime now = DateTime.now();
    final DateTime weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final Map<String, int> categorySeconds = <String, int>{};
    final Map<String, int> appSeconds = <String, int>{};
    final Map<String, int> loaderSeconds = <String, int>{};
    final Map<DateTime, int> daySeconds = _emptyDays().map(
      (DateTime day, Duration value) => MapEntry(day, 0),
    );

    for (final PlaySession session in filtered) {
      final int seconds = session.durationSeconds;
      totalSeconds += seconds;
      if (!session.startedAt.isBefore(weekStart)) {
        weekSeconds += seconds;
      }
      final String category = session.isGame ? '游戏' : '实用软件';
      categorySeconds.update(
        category,
        (int value) => value + seconds,
        ifAbsent: () => seconds,
      );
      appSeconds.update(
        session.appName,
        (int value) => value + seconds,
        ifAbsent: () => seconds,
      );
      if (session.isGame) {
        final String loader =
            (session.loader == null || session.loader!.isEmpty)
            ? 'Vanilla'
            : session.loader!;
        loaderSeconds.update(
          loader,
          (int value) => value + seconds,
          ifAbsent: () => seconds,
        );
      }
      final DateTime day = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      if (daySeconds.containsKey(day)) {
        daySeconds[day] = daySeconds[day]! + seconds;
      }
    }

    final List<MapEntry<String, int>> sortedApps = appSeconds.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    return StatsSummary(
      total: Duration(seconds: totalSeconds),
      weekTotal: Duration(seconds: weekSeconds),
      sessionCount: filtered.length,
      byCategory: categorySeconds.map(
        (String key, int value) => MapEntry(key, Duration(seconds: value)),
      ),
      byApp: <String, Duration>{
        for (final MapEntry<String, int> entry in sortedApps.take(8))
          entry.key: Duration(seconds: entry.value),
      },
      byLoader: loaderSeconds.map(
        (String key, int value) => MapEntry(key, Duration(seconds: value)),
      ),
      byDay: daySeconds.map(
        (DateTime key, int value) => MapEntry(key, Duration(seconds: value)),
      ),
    );
  }

  bool _matches(PlaySession session, StatsFilter filter) {
    switch (filter.kind) {
      case StatsKindFilter.all:
        break;
      case StatsKindFilter.games:
        if (!session.isGame) return false;
        break;
      case StatsKindFilter.utilities:
        if (session.isGame) return false;
        break;
    }

    final String? loaderFilter = filter.loader;
    if (loaderFilter != null) {
      if (!session.isGame) return false;
      if (loaderFilter == 'Vanilla') {
        if (session.loader != null && session.loader!.isNotEmpty) return false;
      } else if (session.loader != loaderFilter) {
        return false;
      }
    }

    if (filter.era != StatsEraFilter.all) {
      final int? major = _majorVersion(session.minecraftVersion);
      if (major == null) return false;
      final bool legacy = major <= 12;
      if (filter.era == StatsEraFilter.legacy && !legacy) return false;
      if (filter.era == StatsEraFilter.modern && legacy) return false;
    }
    return true;
  }

  static int? _majorVersion(String? version) {
    if (version == null || version.isEmpty) return null;
    final List<String> parts = version.split('.');
    if (parts.length < 2) return null;
    final int? major = int.tryParse(parts[0]);
    final int? minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return null;
    if (major == 1) return minor;
    return major;
  }

  Map<DateTime, Duration> _emptyDays() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return <DateTime, Duration>{
      for (int i = 13; i >= 0; i--)
        today.subtract(Duration(days: i)): Duration.zero,
    };
  }

  Future<void> save() {
    return _json.write(
      paths.sessionsFile,
      _sessions.map((PlaySession session) => session.toJson()).toList(),
    );
  }
}
