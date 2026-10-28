import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/download_source.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/game_launcher.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/java_runtime_manager.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_json.dart';
import 'package:hydrogen_chloride_launcher/core/minecraft/version_manifest.dart';
import 'package:hydrogen_chloride_launcher/core/models/java_runtime.dart';

void main() {
  group('version manifest', () {
    test('parses latest release and filters types', () {
      final VersionManifest manifest = VersionManifest.fromJson(
        <String, dynamic>{
          'latest': <String, dynamic>{
            'release': '1.21.1',
            'snapshot': '24w01a',
          },
          'versions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '1.21.1',
              'type': 'release',
              'url': 'https://piston-meta.mojang.com/v1/1.21.1.json',
              'releaseTime': '2024-08-08T10:00:00+00:00',
              'sha1': 'abc',
            },
            <String, dynamic>{
              'id': '24w01a',
              'type': 'snapshot',
              'url': 'https://piston-meta.mojang.com/v1/24w01a.json',
              'releaseTime': '2024-01-03T10:00:00+00:00',
              'sha1': 'def',
            },
          ],
        },
      );

      expect(manifest.latestRelease, '1.21.1');
      expect(manifest.releases.map((VersionManifestEntry e) => e.id), <String>[
        '1.21.1',
      ]);
      expect(manifest.find('24w01a')?.type, 'snapshot');
      expect(manifest.find('missing'), isNull);
    });
  });

  group('version json', () {
    Map<String, dynamic> vanilla() => <String, dynamic>{
      'id': '1.21.1',
      'type': 'release',
      'mainClass': 'net.minecraft.client.main.Main',
      'assets': '17',
      'assetIndex': <String, dynamic>{
        'url': 'https://piston-data.mojang.com/v1/index.json',
        'sha1': 'aaa',
        'size': 10,
      },
      'downloads': <String, dynamic>{
        'client': <String, dynamic>{
          'url': 'https://piston-data.mojang.com/v1/client.jar',
          'sha1': 'bbb',
          'size': 20,
        },
      },
      'javaVersion': <String, dynamic>{'majorVersion': 21},
      'libraries': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'a:b:1',
          'downloads': <String, dynamic>{
            'artifact': <String, dynamic>{
              'url': 'https://libraries/a/b/1/b-1.jar',
              'path': 'a/b/1/b-1.jar',
              'sha1': 'ccc',
              'size': 5,
            },
          },
        },
        <String, dynamic>{
          'name': 'org.lwjgl:lwjgl:3.3',
          'downloads': <String, dynamic>{
            'artifact': <String, dynamic>{
              'url': 'https://libraries/lwjgl.jar',
              'path': 'org/lwjgl/lwjgl/3.3/lwjgl-3.3.jar',
            },
            'classifiers': <String, dynamic>{
              'natives-linux': <String, dynamic>{
                'url': 'https://libraries/lwjgl-natives-linux.jar',
                'path': 'org/lwjgl/lwjgl/3.3/lwjgl-3.3-natives-linux.jar',
              },
              'natives-windows': <String, dynamic>{
                'url': 'https://libraries/lwjgl-natives-windows.jar',
                'path': 'org/lwjgl/lwjgl/3.3/lwjgl-3.3-natives-windows.jar',
              },
            },
          },
          'natives': <String, dynamic>{
            'linux': 'natives-linux',
            'windows': 'natives-windows',
          },
        },
      ],
      'arguments': <String, dynamic>{
        'jvm': <Object>[
          '-Djava.library.path=\${natives_directory}',
          <String, dynamic>{
            'rules': <Map<String, dynamic>>[
              <String, dynamic>{
                'action': 'allow',
                'os': <String, dynamic>{'name': 'windows'},
              },
            ],
            'value': '-XX:HeapDumpPath=MojangTricksIntelDriversForPerformance',
          },
        ],
        'game': <Object>[
          '--username',
          '\${auth_player_name}',
          <String, dynamic>{
            'rules': <Map<String, dynamic>>[
              <String, dynamic>{
                'action': 'allow',
                'os': <String, dynamic>{'name': 'osx'},
              },
            ],
            'value': '-XstartOnFirstThread',
          },
        ],
      },
    };

    test('parses core fields and arguments', () {
      final VersionJson version = VersionJson.fromJson(vanilla());
      expect(version.mainClass, 'net.minecraft.client.main.Main');
      expect(version.javaVersion, 21);
      expect(version.client?.sha1, 'bbb');
      expect(version.assetIndex?.url, contains('index.json'));
      expect(version.libraries.length, 2);
      expect(version.jvmArguments.length, 2);
    });

    test('rules allow windows-only arguments on linux configs', () {
      final VersionJson version = VersionJson.fromJson(vanilla());
      final List<String> values = version.jvmArguments
          .where((ArgumentEntry entry) => entry.matches())
          .map((ArgumentEntry entry) => entry.value)
          .toList(growable: false);
      expect(values, contains('-Djava.library.path=\${natives_directory}'));
      // The windows-only argument must not match on linux/macos hosts.
      if (!Platform.isWindows) {
        expect(values, isNot(contains(startsWith('-XX:HeapDumpPath'))));
      }
    });

    test('merge keeps parent libraries and puts child first', () {
      final VersionJson parent = VersionJson.fromJson(vanilla());
      final VersionJson child = VersionJson.fromJson(<String, dynamic>{
        'id': 'fabric-loader-0.16-1.21.1',
        'inheritsFrom': '1.21.1',
        'libraries': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'net.fabricmc:fabric-loader:0.16',
            'url': 'https://maven.fabricmc.net/',
          },
        ],
        'arguments': <String, dynamic>{
          'game': <String>['--fabric'],
        },
      });
      final VersionJson merged = mergeVersionJson(parent, child);

      expect(merged.id, 'fabric-loader-0.16-1.21.1');
      expect(merged.mainClass, parent.mainClass);
      expect(merged.javaVersion, 21);
      expect(merged.inheritsFrom, isNull);
      expect(merged.libraries.first.name, 'net.fabricmc:fabric-loader:0.16');
      expect(merged.libraries.length, 3);
      // Child game arguments come before the inherited ones.
      expect(merged.gameArguments.first.value, '--fabric');
      expect(
        merged.gameArguments.map((ArgumentEntry entry) => entry.value),
        contains('\${auth_player_name}'),
      );
    });

    test('maven path is inferred when only coordinates exist', () {
      final LibraryEntry library = LibraryEntry.fromJson(<String, dynamic>{
        'name': 'com.example:artifact:1.0.0:natives-linux',
        'url': 'https://maven.example.com/',
      });
      expect(
        library.inferredPath,
        'com/example/artifact/1.0.0/artifact-1.0.0-natives-linux.jar',
      );
    });

    test('loadVersionJson follows inheritsFrom on disk', () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-vj-');
      addTearDown(() => root.deleteSync(recursive: true));
      final Directory vanillaDir = Directory('${root.path}/versions/1.21.1')
        ..createSync(recursive: true);
      File('${vanillaDir.path}/1.21.1.json')
          .writeAsStringSync(jsonEncode(vanilla()));
      final Directory childDir = Directory('${root.path}/versions/mine')
        ..createSync(recursive: true);
      File('${childDir.path}/mine.json').writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'id': 'mine',
          'inheritsFrom': '1.21.1',
          'libraries': <Object>[],
        }),
      );

      final VersionJson? merged = await loadVersionJson(root.path, 'mine');
      expect(merged, isNotNull);
      expect(merged!.mainClass, 'net.minecraft.client.main.Main');
      expect(merged.libraries.length, 2);
      expect(await loadVersionJson(root.path, 'nope'), isNull);
    });
  });

  group('download source', () {
    test('official source leaves urls untouched', () {
      const String url = 'https://piston-data.mojang.com/v1/objects/x.jar';
      expect(DownloadMirror.official.rewrite(url), url);
    });

    test('bmclapi rewrites both mojang hosts and asset objects', () {
      const DownloadMirror mirror = DownloadMirror(
        metaSource: DownloadSource.bmclapi,
        fileSource: DownloadSource.bmclapi,
      );
      expect(
        mirror.rewrite('https://piston-data.mojang.com/v1/objects/x.jar'),
        'https://bmclapi2.bangbang93.com/v1/objects/x.jar',
      );
      expect(
        mirror.rewrite(
          DownloadMirror.assetObjectUrl(
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ),
        startsWith('https://bmclapi2.bangbang93.com/assets/aa/'),
      );
      expect(mirror.manifestUrl, contains('bmclapi2.bangbang93.com'));
    });

    test('unknown hosts pass through', () {
      const DownloadMirror mirror = DownloadMirror(
        metaSource: DownloadSource.official,
        fileSource: DownloadSource.bmclapi,
      );
      expect(
        mirror.rewrite('https://maven.fabricmc.net/net/fabricmc/x.jar'),
        'https://maven.fabricmc.net/net/fabricmc/x.jar',
      );
    });
  });

  group('java selection', () {
    JavaRuntimeManager manager() => JavaRuntimeManager(
      root: '/tmp/hcl-java-test',
      mirror: DownloadMirror.official,
    );

    JavaRuntime runtime(int major) => JavaRuntime(
      path: '/opt/java$major/bin/java',
      version: '$major',
      major: major,
      vendor: 'Test',
      arch: 'x64',
      source: 'test',
    );

    test('picks a runtime that satisfies the requirement', () {
      final JavaRuntimeManager m = manager();
      final List<JavaRuntime> runtimes = <JavaRuntime>[
        runtime(8),
        runtime(17),
        runtime(21),
      ];
      expect(m.pickInstalled(runtimes, requiredMajor: 21)?.major, 21);
      expect(m.pickInstalled(runtimes, requiredMajor: 17)?.major, 17);
      expect(m.pickInstalled(runtimes, requiredMajor: 8)?.major, 8);
    });

    test('override wins over requirement', () {
      final JavaRuntimeManager m = manager();
      final List<JavaRuntime> runtimes = <JavaRuntime>[runtime(21)];
      final JavaRuntime? picked = m.pickInstalled(
        runtimes,
        override: '/custom/java/bin/java',
        requiredMajor: 8,
      );
      expect(picked?.path, '/custom/java/bin/java');
    });

    test('returns null when nothing satisfies the requirement', () {
      final JavaRuntimeManager m = manager();
      expect(
        m.pickInstalled(<JavaRuntime>[runtime(8)], requiredMajor: 21),
        isNull,
      );
    });
  });

  group('command line splitting', () {
    test('splits on spaces and honours quotes', () {
      expect(splitCommandLine('-Xmx4G -Dfoo="a b" --bar'), <String>[
        '-Xmx4G',
        '-Dfoo=a b',
        '--bar',
      ]);
      expect(splitCommandLine('   '), isEmpty);
    });
  });
}
