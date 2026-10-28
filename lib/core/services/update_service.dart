import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../minecraft/download_manager.dart';
import 'update_installer.dart';

/// One release listed in the update manifest.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.notes,
    required this.publishedAt,
    required this.assets,
  });

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> assets = json['assets'] is Map
        ? Map<String, dynamic>.from(json['assets'] as Map)
        : <String, dynamic>{};
    return UpdateRelease(
      version: '${json['version'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      publishedAt: DateTime.tryParse('${json['publishedAt'] ?? ''}'),
      assets: assets.map(
        (String platform, dynamic value) => MapEntry(
          platform,
          UpdateAsset.fromJson(
            value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{},
          ),
        ),
      ),
    );
  }

  final String version;
  final String notes;
  final DateTime? publishedAt;

  /// Keyed by `linux-x64` / `windows-x64` / `darwin`.
  final Map<String, UpdateAsset> assets;

  UpdateAsset? get currentPlatform => assets[UpdatePlatform.key];
}

class UpdateAsset {
  const UpdateAsset({
    required this.url,
    required this.sha256,
    required this.size,
    this.executableName,
  });

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    return UpdateAsset(
      url: '${json['url'] ?? ''}',
      sha256: '${json['sha256'] ?? ''}',
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
      executableName: json['executable'] is String
          ? json['executable'] as String
          : null,
    );
  }

  final String url;
  final String sha256;
  final int size;

  /// File to launch after replacing the bundle (defaults to the running exe).
  final String? executableName;
}

class UpdatePlatform {
  static String get key {
    if (Platform.isWindows) return 'windows-x64';
    if (Platform.isMacOS) return 'darwin';
    return 'linux-x64';
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latest,
    this.error,
  });

  final String currentVersion;
  final UpdateRelease? latest;
  final String? error;

  bool get hasUpdate =>
      latest != null && compareVersions(latest!.version, currentVersion) > 0;
}

enum UpdateStage {
  idle,
  checking,
  downloading,
  verifying,
  applying,
  done,
  failed,
}

/// Checks a user-configured JSON manifest, downloads the platform asset,
/// verifies SHA-256, and hands it to [UpdateInstaller].
class UpdateService extends ChangeNotifier {
  UpdateService({
    required this.currentVersion,
    DownloadManager? downloader,
    UpdateInstaller? installer,
  }) : _downloader = downloader ?? DownloadManager(),
       _installer = installer ?? UpdateInstaller();

  final String currentVersion;
  final DownloadManager _downloader;
  final UpdateInstaller _installer;

  UpdateStage stage = UpdateStage.idle;
  UpdateCheckResult? lastCheck;
  double progress = 0;
  String? message;

  Future<UpdateCheckResult> check(String manifestUrl) async {
    final String url = manifestUrl.trim();
    if (url.isEmpty) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latest: null,
        error: '未配置更新源。',
      );
    }
    stage = UpdateStage.checking;
    message = null;
    notifyListeners();
    try {
      final Map<String, dynamic> json = await _downloader.fetchJson(url);
      final UpdateRelease release = UpdateRelease.fromJson(json);
      final UpdateCheckResult result = UpdateCheckResult(
        currentVersion: currentVersion,
        latest: release,
      );
      lastCheck = result;
      stage = UpdateStage.idle;
      notifyListeners();
      return result;
    } on Object catch (error) {
      final UpdateCheckResult result = UpdateCheckResult(
        currentVersion: currentVersion,
        latest: null,
        error: '检查更新失败：$error',
      );
      lastCheck = result;
      stage = UpdateStage.idle;
      notifyListeners();
      return result;
    }
  }

  /// Downloads and verifies the update. Returns the file ready to apply.
  Future<File?> download(UpdateRelease release) async {
    final UpdateAsset? asset = release.currentPlatform;
    if (asset == null || asset.url.isEmpty) {
      _fail('该版本没有当前平台的安装包。');
      return null;
    }
    final Directory dir = Directory(
      p.join(Directory.systemTemp.path, 'hcl-update'),
    );
    await dir.create(recursive: true);
    final String name = Uri.parse(asset.url).pathSegments.last;
    final File target = File(
      p.join(dir.path, name.isEmpty ? 'update.zip' : name),
    );
    if (await target.exists()) await target.delete();

    stage = UpdateStage.downloading;
    progress = 0;
    message = '下载 ${release.version}';
    notifyListeners();
    try {
      final DownloadBatchResult result = await _downloader.run(
        <DownloadRequest>[
          DownloadRequest(
            url: asset.url,
            destination: target.path,
            size: asset.size,
          ),
        ],
        onProgress: (DownloadProgress item) {
          progress = item.fraction;
          notifyListeners();
        },
      );
      if (!result.ok) throw result.failures.first.error;

      stage = UpdateStage.verifying;
      progress = 1;
      notifyListeners();
      if (asset.sha256.isNotEmpty) {
        final String actual = sha256
            .convert(await target.readAsBytes())
            .toString();
        if (actual.toLowerCase() != asset.sha256.toLowerCase()) {
          throw Exception('SHA-256 校验失败。');
        }
      }
      return target;
    } on Object catch (error) {
      _fail('更新下载失败：$error');
      return null;
    }
  }

  /// Replaces the running bundle with [file] and restarts.
  Future<void> apply(File file, {String? executableName}) async {
    stage = UpdateStage.applying;
    progress = 0;
    message = '正在应用更新';
    notifyListeners();
    try {
      await _installer.install(
        file,
        executableName: executableName,
        onProgress: (String text, double value) {
          message = text;
          progress = value;
          notifyListeners();
        },
      );
      stage = UpdateStage.done;
      message = '更新已就绪，重启后生效。';
      notifyListeners();
    } on Object catch (error) {
      _fail('应用更新失败：$error');
    }
  }

  void _fail(String text) {
    stage = UpdateStage.failed;
    message = text;
    notifyListeners();
  }
}

/// Dotted-version comparison, treating prerelease suffixes as lower.
int compareVersions(String a, String b) {
  List<int> parse(String value) {
    final String core = value.split('+').first.split('-').first;
    return core
        .split('.')
        .map((String part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  final List<int> left = parse(a);
  final List<int> right = parse(b);
  for (int i = 0; i < left.length || i < right.length; i++) {
    final int l = i < left.length ? left[i] : 0;
    final int r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  final bool aPre = a.split('+').first.contains('-');
  final bool bPre = b.split('+').first.contains('-');
  if (aPre == bPre) return 0;
  return aPre ? -1 : 1;
}

/// Small helper used by the About pane to show the manifest template.
String updateManifestTemplate() =>
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'version': '0.2.0',
      'notes': '更新说明',
      'publishedAt': '2026-01-01T00:00:00Z',
      'assets': <String, dynamic>{
        'linux-x64': <String, dynamic>{
          'url': 'https://example.com/hcl-0.2.0-linux-x64.tar.gz',
          'sha256': '<sha256>',
          'size': 0,
        },
        'windows-x64': <String, dynamic>{
          'url': 'https://example.com/hcl-0.2.0-windows-x64.zip',
          'sha256': '<sha256>',
          'size': 0,
          'executable': 'hydrogen_chloride_launcher.exe',
        },
      },
    });
