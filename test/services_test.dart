import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/services/crash_analyzer.dart';
import 'package:hydrogen_chloride_launcher/core/services/feed_parser.dart';
import 'package:hydrogen_chloride_launcher/core/services/world_repair.dart';
import 'package:hydrogen_chloride_launcher/core/models/feed.dart';

const String _rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Minecraft News</title>
    <link>https://example.com/</link>
    <item>
      <title>First &amp; story</title>
      <link>https://example.com/a</link>
      <guid>https://example.com/a</guid>
      <description>&lt;p&gt;Hello &lt;b&gt;world&lt;/b&gt;.&lt;/p&gt;</description>
      <pubDate>Tue, 03 Jun 2008 09:56:00 GMT</pubDate>
      <dc:creator>Alex</dc:creator>
    </item>
    <item>
      <title>Second story</title>
      <link>https://example.com/b</link>
      <content:encoded><![CDATA[<p>Para one</p><p>Para two</p>]]></content:encoded>
      <pubDate>Wed, 04 Jun 2008 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';

const String _atom = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Modrinth Blog</title>
  <updated>2024-01-02T03:04:05Z</updated>
  <entry>
    <title>Hello Atom</title>
    <id>tag:modrinth,2024:1</id>
    <link rel="alternate" href="https://modrinth.com/blog/hello"/>
    <updated>2024-01-02T03:04:05Z</updated>
    <author><name>Pink</name></author>
    <summary>Short text</summary>
    <content type="html">&lt;p&gt;Body text&lt;/p&gt;</content>
  </entry>
</feed>
''';

void main() {
  group('feed parser', () {
    const FeedParser parser = FeedParser();

    test('parses RSS items with entities and creators', () {
      final List<FeedArticle>? articles = parser.parse(_rss, sourceId: 's1');
      expect(articles, isNotNull);
      expect(articles!.length, 2);
      final FeedArticle first = articles.first;
      expect(first.title, 'First & story');
      expect(first.link, 'https://example.com/a');
      expect(first.author, 'Alex');
      expect(first.summary, 'Hello world .');
      expect(first.publishedAt.toUtc().year, 2008);
    });

    test('prefers content:encoded and keeps paragraphs', () {
      final List<FeedArticle> articles = parser.parse(_rss, sourceId: 's1')!;
      expect(articles[1].content, 'Para one\n\nPara two');
    });

    test('parses Atom entries', () {
      final List<FeedArticle>? articles = parser.parse(_atom, sourceId: 's2');
      expect(articles, isNotNull);
      final FeedArticle article = articles!.single;
      expect(article.title, 'Hello Atom');
      expect(article.link, 'https://modrinth.com/blog/hello');
      expect(article.author, 'Pink');
      expect(article.content, 'Body text');
    });

    test('rejects non-feed documents', () {
      expect(
        parser.parse('<html><body>hi</body></html>', sourceId: 'x'),
        isNull,
      );
      expect(parser.parse('not xml at all <', sourceId: 'x'), isNull);
    });

    test('feed title is read for new subscriptions', () {
      expect(parser.titleOf(_rss), 'Minecraft News');
      expect(parser.titleOf(_atom), 'Modrinth Blog');
    });
  });

  group('crash analyzer', () {
    test('matches rules case-insensitively', () {
      final List<CrashFinding> findings = CrashAnalyzer().analyze(
        'java.lang.UnsupportedClassVersionError: requires java 21',
      );
      expect(
        findings.map((CrashFinding f) => f.ruleId),
        contains('java-version'),
      );
    });

    test('reports each rule once', () {
      final List<CrashFinding> findings = CrashAnalyzer().analyze(
        'OutOfMemoryError OutOfMemoryError java heap space',
      );
      expect(
        findings.where((CrashFinding f) => f.ruleId == 'out-of-memory').length,
        1,
      );
    });

    test('clean log yields no findings', () {
      expect(CrashAnalyzer().analyze('all good'), isEmpty);
    });
  });

  group('world repair', () {
    late Directory world;

    setUp(() {
      world = Directory.systemTemp.createTempSync('hcl-world-');
    });

    tearDown(() {
      if (world.existsSync()) world.deleteSync(recursive: true);
    });

    NbtCompound sampleLevel({String name = '', String version = '1.21.1'}) {
      final NbtCompound versionTag = NbtCompound()
        ..putString('Name', version)
        ..putInt('Id', 3955);
      return NbtCompound()
        ..putString('LevelName', name)
        ..putInt('DataVersion', 3955)
        ..entries['Version'] = versionTag;
    }

    test('round-trips level.dat through gzip', () async {
      final File file = File('${world.path}/level.dat');
      await WorldRepair.writeLevelDat(
        world,
        LevelDat(sampleLevel(name: 'My World'), compressed: true),
      );
      expect((await file.readAsBytes()).sublist(0, 2), <int>[0x1f, 0x8b]);

      final LevelDat? read = await WorldRepair.readLevelDat(world);
      expect(read, isNotNull);
      expect(read!.levelName, 'My World');
      expect(read.versionName, '1.21.1');
      expect(read.dataVersion, 3955);
    });

    test('repair fills names, creates region and backs up', () async {
      await WorldRepair.writeLevelDat(
        world,
        LevelDat(sampleLevel(name: ''), compressed: true),
      );
      final WorldRepairReport before = await WorldRepair.analyze(world);
      expect(before.canRepair, isTrue);
      expect(before.issues, contains(contains('LevelName')));

      final List<String> applied = await WorldRepair.repair(
        world,
        fallbackName: 'Recovered',
        fallbackVersion: '1.21.1',
      );
      expect(applied, isNotEmpty);
      expect(Directory('${world.path}/region').existsSync(), isTrue);
      expect(File('${world.path}/level.dat.tmp').existsSync(), isFalse);

      final LevelDat? fixed = await WorldRepair.readLevelDat(world);
      expect(fixed!.levelName, 'Recovered');
    });

    test('missing level.dat is reported', () async {
      final WorldRepairReport report = await WorldRepair.analyze(world);
      expect(report.canRepair, isFalse);
      expect(report.issues.first, contains('level.dat'));
    });
  });
}
