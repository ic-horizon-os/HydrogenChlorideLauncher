import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_chain.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('hcl-chain-');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void writeVersion(String id, {String? inherits}) {
    final Directory dir = Directory(p.join(root.path, 'versions', id))
      ..createSync(recursive: true);
    File(p.join(dir.path, '$id.json')).writeAsStringSync(
      jsonEncode(<String, dynamic>{'id': id, 'inheritsFrom': ?inherits}),
    );
  }

  void writeJar(String id) {
    File(p.join(root.path, 'versions', id, '$id.jar')).writeAsStringSync('jar');
  }

  test('loader version has no jar and resolves the vanilla one', () async {
    writeVersion('1.21.1');
    writeJar('1.21.1');
    writeVersion('fabric-loader-0.20.1-1.21.1', inherits: '1.21.1');

    final VersionChain? chain = await VersionChain.load(
      root.path,
      'fabric-loader-0.20.1-1.21.1',
    );
    expect(chain, isNotNull);
    expect(chain!.versionIds, <String>[
      'fabric-loader-0.20.1-1.21.1',
      '1.21.1',
    ]);
    // This is the regression: the vanilla jar must appear in the classpath.
    expect(chain.clientJars(root.path), <String>[
      p.join(root.path, 'versions', '1.21.1', '1.21.1.jar'),
    ]);
  });

  test('multi-level chain keeps loader-first order', () async {
    writeVersion('1.20.1');
    writeJar('1.20.1');
    writeVersion('forge-47.0');
    writeJar('forge-47.0');
    writeVersion('optifine-on-forge', inherits: 'forge-47.0');
    writeVersion('forge-47.0b', inherits: '1.20.1');

    final VersionChain? chain = await VersionChain.load(
      root.path,
      'forge-47.0b',
    );
    expect(chain!.versionIds, <String>['forge-47.0b', '1.20.1']);
    expect(chain.clientJars(root.path), hasLength(1));
  });

  test('missing version returns null', () async {
    expect(await VersionChain.load(root.path, 'nope'), isNull);
  });

  test('cycle in inheritsFrom terminates', () async {
    writeVersion('a', inherits: 'b');
    writeVersion('b', inherits: 'a');
    final VersionChain? chain = await VersionChain.load(root.path, 'a');
    expect(chain!.versionIds, <String>['a', 'b']);
  });
}
