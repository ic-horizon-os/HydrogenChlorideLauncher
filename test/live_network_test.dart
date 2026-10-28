// Live network checks against real public endpoints.
//
// Slow and internet-dependent, so this file ships but is skipped unless
// `HCL_LIVE=1` is set. Run with:
//
//   HCL_LIVE=1 flutter test test/live_network_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/download_source.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/minecraft_installer.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/modrinth_client.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_manifest.dart';
import 'package:hydrogen_chloride_launcher/core/models/browse_item.dart';
import 'package:hydrogen_chloride_launcher/core/models/feed.dart';
import 'package:hydrogen_chloride_launcher/core/services/feed_store.dart';

final bool _live = Platform.environment['HCL_LIVE'] == '1';

void main() {
  test(
    'live: Mojang manifest lists releases',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-live-');
      addTearDown(() => root.deleteSync(recursive: true));
      final MinecraftInstaller installer = MinecraftInstaller(
        root: root.path,
        mirror: DownloadMirror.official,
      );
      final VersionManifest manifest = await installer.fetchManifest();
      expect(manifest.releases, isNotEmpty);
      expect(manifest.find(manifest.latestRelease), isNotNull);
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'live: Modrinth search and versions',
    () async {
      final ModrinthClient client = ModrinthClient();
      final List<BrowseItem> items = await client.search(
        category: BrowseCategory.mod,
        query: 'sodium',
        loader: 'fabric',
      );
      expect(items, isNotEmpty);
      final List<ModrinthVersion> versions = await client.versions(
        items.first.id,
        gameVersion: '1.21.1',
        loader: 'fabric',
      );
      expect(versions, isNotEmpty);
      expect(versions.first.downloadUrl, startsWith('https://'));
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'live: RSS feed fetch, parse and store',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-feed-');
      addTearDown(() => root.deleteSync(recursive: true));
      final FeedStore store = FeedStore(AppPaths.forTesting(root));
      await store.load();
      final FeedSource source = await store.addSource(
        title: '',
        url: 'https://blog.modrinth.com/rss.xml',
        isFeed: true,
      );
      expect(store.errorFor(source.id), isNull);
      expect(store.articlesFor(source.id, includeDemo: false), isNotEmpty);
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'live: a vanilla version downloads to disk',
    () async {
      final Directory root = Directory.systemTemp.createTempSync(
        'hcl-vanilla-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final MinecraftInstaller installer = MinecraftInstaller(
        root: root.path,
        mirror: DownloadMirror.official,
      );
      // 1.1 has a single small jar and no asset index, so this stays fast.
      await installer.installVanilla('1.1');
      expect(File('${root.path}/versions/1.1/1.1.json').existsSync(), isTrue);
      expect(File('${root.path}/versions/1.1/1.1.jar').existsSync(), isTrue);
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
