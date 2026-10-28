import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/modrinth_client.dart';
import 'package:hydrogen_chloride_launcher/core/models/account.dart';
import 'package:hydrogen_chloride_launcher/core/models/browse_item.dart';
import 'package:hydrogen_chloride_launcher/core/services/browse_repository.dart';
import 'package:hydrogen_chloride_launcher/core/services/core_bridge.dart';
import 'package:hydrogen_chloride_launcher/core/services/token_vault.dart';
import 'package:hydrogen_chloride_launcher/core/services/update_service.dart';

void main() {
  group('token vault fallback', () {
    test('writes and reads the 0600 file without a sidecar', () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-vault-');
      addTearDown(() => root.deleteSync(recursive: true));
      final AppPaths paths = AppPaths.forTesting(root);
      await paths.ensure();
      final TokenVault vault = TokenVault(
        paths: paths,
        core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
      );
      const MinecraftAccount account = MinecraftAccount(
        accessToken: 'mc-token',
        refreshToken: 'ms-token',
        uuid: 'uuid',
        name: 'Steve',
        gamertag: null,
        xuid: null,
        expiresAt: null,
        ownsMinecraft: true,
      );

      await vault.write(account);
      expect(vault.backend, 'file');
      expect(await paths.accountFile.exists(), isTrue);
      if (!Platform.isWindows) {
        final String mode = await File(paths.accountFile.path)
            .stat()
            .then((FileStat stat) => stat.mode.toRadixString(8));
        expect(mode.endsWith('600'), isTrue);
      }

      final MinecraftAccount? restored = await vault.read();
      expect(restored?.accessToken, 'mc-token');
      expect(restored?.name, 'Steve');

      await vault.delete();
      expect(await paths.accountFile.exists(), isFalse);
      expect(await vault.read(), isNull);
    });

    test('masks tokens for diagnostics', () {
      expect(maskToken('abcdefghijklmnop'), 'abcd…mnop');
      expect(maskToken('short'), '*****');
      expect(maskToken(''), '—');
    });
  });

  group('modrinth mapping', () {
    final ModrinthClient client = ModrinthClient();

    test('maps search hits to browse items', () {
      final List<BrowseItem> items = client.mapSearch(<String, dynamic>{
        'hits': <Map<String, dynamic>>[
          <String, dynamic>{
            'project_id': 'abc123',
            'slug': 'sodium',
            'title': 'Sodium',
            'description': 'Fast rendering',
            'author': 'jellysquid3',
            'categories': <String>['optimization', 'fabric'],
            'downloads': 12345678,
            'follows': 9000,
            'date_modified': '2024-08-01T00:00:00Z',
            'versions': <String>['1.21.1', '1.21'],
            'icon_url': 'https://cdn.modrinth.com/data/abc123/icon.png',
          },
        ],
      }, BrowseCategory.mod);
      expect(items, hasLength(1));
      final BrowseItem item = items.single;
      expect(item.id, 'abc123');
      expect(item.name, 'Sodium');
      expect(item.loaders, <String>['fabric']);
      expect(item.tags, contains('optimization'));
      expect(item.iconUrl, contains('icon.png'));
      expect(item.slug, 'sodium');
      expect(item.isOnline, isTrue);
    });

    test('picks the newest version matching game and loader', () {
      const ModrinthVersion good = ModrinthVersion(
        id: '1',
        projectId: 'p',
        name: 'good',
        versionNumber: '1.0',
        gameVersions: <String>['1.21.1'],
        loaders: <String>['fabric'],
        downloadUrl: 'https://cdn/x.jar',
        fileName: 'x.jar',
        versionType: 'release',
        datePublished: null,
      );
      const ModrinthVersion wrong = ModrinthVersion(
        id: '2',
        projectId: 'p',
        name: 'wrong',
        versionNumber: '2.0',
        gameVersions: <String>['1.20.1'],
        loaders: <String>['forge'],
        downloadUrl: 'https://cdn/y.jar',
        fileName: 'y.jar',
        versionType: 'release',
        datePublished: null,
      );
      expect(
        ModrinthClient.pick(
          <ModrinthVersion>[wrong, good],
          gameVersion: '1.21.1',
          loader: 'fabric',
        )?.id,
        '1',
      );
      expect(
        ModrinthClient.pick(<ModrinthVersion>[
          wrong,
        ], gameVersion: '1.21.1')?.id,
        '2',
      );
      expect(ModrinthClient.pick(const <ModrinthVersion>[]), isNull);
    });

    test('demo repository still serves loader entries', () {
      final BrowseRepository repository = BrowseRepository();
      final List<BrowseItem> loaders = repository.query(
        category: BrowseCategory.loader,
      );
      expect(loaders, isNotEmpty);
      expect(loaders.every((BrowseItem item) => item.loaderId != null), isTrue);
    });
  });

  group('version comparison for updates', () {
    test('orders semver-ish versions', () {
      expect(compareVersions('0.2.0', '0.1.0'), greaterThan(0));
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('0.1.1', '0.1.0'), greaterThan(0));
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
    });

    test('prerelease sorts before release', () {
      expect(compareVersions('0.2.0', '0.2.0-beta.1'), greaterThan(0));
      expect(compareVersions('0.2.0-beta.1', '0.2.0'), lessThan(0));
    });

    test('update check detects newer releases', () {
      const UpdateCheckResult none = UpdateCheckResult(
        currentVersion: '0.1.0',
        latest: null,
      );
      expect(none.hasUpdate, isFalse);
      final UpdateCheckResult newer = UpdateCheckResult(
        currentVersion: '0.1.0',
        latest: UpdateRelease.fromJson(<String, dynamic>{
          'version': '0.2.0',
          'notes': 'Fixes',
        }),
      );
      expect(newer.hasUpdate, isTrue);
      expect(newer.latest?.currentPlatform, isNull);
    });
  });
}
