import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/models/play_session.dart';
import 'package:hydrogen_chloride_launcher/core/services/stats_service.dart';

void main() {
  test(
    'aggregates sessions and filters by demo, kind, loader and era',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-stats-');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final AppPaths paths = AppPaths.forTesting(root);
      await paths.ensure();
      final DateTime now = DateTime.now();
      final List<Map<String, dynamic>> sessions = <Map<String, dynamic>>[
        <String, dynamic>{
          'appId': 'vanilla',
          'appName': 'Minecraft 1.21.1',
          'kind': 'minecraft',
          'startedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          'durationSeconds': 3600,
          'loader': 'Fabric',
          'minecraftVersion': '1.21.1',
          'isDemo': false,
        },
        <String, dynamic>{
          'appId': 'utility',
          'appName': 'Konsole',
          'kind': 'utility',
          'startedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'durationSeconds': 1800,
          'isDemo': true,
        },
        <String, dynamic>{
          'appId': 'legacy',
          'appName': 'RLCraft',
          'kind': 'modpack',
          'startedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
          'durationSeconds': 7200,
          'loader': 'Forge',
          'minecraftVersion': '1.12.2',
          'isDemo': true,
        },
      ];
      File(paths.sessionsFile.path).writeAsStringSync(jsonEncode(sessions));

      final StatsService service = StatsService(paths);
      addTearDown(service.dispose);
      await service.load();

      final StatsSummary all = service.summary();
      expect(all.total, const Duration(seconds: 12600));
      expect(all.weekTotal, const Duration(seconds: 12600));
      expect(all.sessionCount, 3);
      expect(all.averageSession, const Duration(seconds: 4200));
      expect(all.byCategory['游戏'], const Duration(seconds: 10800));
      expect(all.byCategory['实用软件'], const Duration(seconds: 1800));
      expect(all.byApp['RLCraft'], const Duration(seconds: 7200));
      expect(all.byLoader['Fabric'], const Duration(seconds: 3600));
      expect(all.byLoader['Forge'], const Duration(seconds: 7200));
      expect(all.byDay, hasLength(14));

      final StatsSummary realOnly = service.summary(includeDemo: false);
      expect(realOnly.total, const Duration(seconds: 3600));
      expect(realOnly.sessionCount, 1);

      expect(
        service
            .summary(filter: const StatsFilter(kind: StatsKindFilter.games))
            .total,
        const Duration(seconds: 10800),
      );
      expect(
        service
            .summary(filter: const StatsFilter(kind: StatsKindFilter.utilities))
            .total,
        const Duration(seconds: 1800),
      );
      expect(
        service.summary(filter: const StatsFilter(loader: 'Fabric')).total,
        const Duration(seconds: 3600),
      );
      expect(
        service
            .summary(filter: const StatsFilter(era: StatsEraFilter.legacy))
            .total,
        const Duration(seconds: 7200),
      );
      expect(
        service
            .summary(filter: const StatsFilter(era: StatsEraFilter.modern))
            .total,
        const Duration(seconds: 3600),
      );
    },
  );

  test('records a new session and persists it', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-stats-record-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();
    File(paths.sessionsFile.path).writeAsStringSync('[]');

    final StatsService service = StatsService(paths);
    addTearDown(service.dispose);
    await service.load();
    await service.record(
      PlaySession(
        appId: 'custom',
        appName: 'Blockbench',
        kind: 'custom',
        startedAt: DateTime.now(),
        durationSeconds: 90,
      ),
    );

    expect(service.sessions, hasLength(1));
    expect(service.summary().total, const Duration(seconds: 90));
    expect(paths.sessionsFile.existsSync(), isTrue);
  });
}
