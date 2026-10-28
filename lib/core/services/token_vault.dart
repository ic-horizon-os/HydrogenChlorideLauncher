import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_paths.dart';
import '../config/json_store.dart';
import '../models/account.dart';
import 'core_bridge.dart';

/// Stores the Minecraft account token bundle.
///
/// The preferred backend is the OS credential store reached through the
/// `hcl-core` sidecar (`secret-tool` on Linux, DPAPI on Windows). When that is
/// unavailable the bundle falls back to the 0600 `account.json` file, so
/// builds without the sidecar keep working unchanged.
class TokenVault {
  TokenVault({required this.paths, required this.core, JsonStore? jsonStore})
    : _json = jsonStore ?? const JsonStore();

  static const String accountKey = 'microsoft-account';

  final AppPaths paths;
  final CoreBridge core;
  final JsonStore _json;

  String _backend = 'file';
  String? _error;

  /// `secret-service`, `dpapi` or `file`.
  String get backend => _backend;
  String? get lastError => _error;

  Future<MinecraftAccount?> read() async {
    if (core.isAvailable) {
      final SecretReadResult result = await core.secretGet(accountKey);
      if (result.backend != 'unavailable') {
        _backend = result.backend;
        final Map<String, dynamic>? value = result.value;
        return value == null ? null : MinecraftAccount.fromJson(value);
      }
    }
    _backend = 'file';
    final Map<String, dynamic>? json = await _json.readMap(paths.accountFile);
    return json == null ? null : MinecraftAccount.fromJson(json);
  }

  Future<void> write(MinecraftAccount account) async {
    if (core.isAvailable) {
      final bool ok = await core.secretSet(
        accountKey,
        jsonEncode(account.toJson()),
      );
      if (ok) {
        _backend = 'keychain';
        _error = null;
        if (await paths.accountFile.exists()) {
          await paths.accountFile.delete();
        }
        return;
      }
      _error = '系统钥匙串不可用，已回退到本地文件。';
    }
    _backend = 'file';
    await _json.write(paths.accountFile, account.toJson(), private: true);
  }

  Future<void> delete() async {
    if (core.isAvailable) {
      await core.secretDelete(accountKey);
    }
    final File file = paths.accountFile;
    if (await file.exists()) await file.delete();
  }

  /// Human-readable backend name for the settings pane.
  String get backendLabel {
    switch (_backend) {
      case 'secret-service':
        return '系统钥匙串（Secret Service）';
      case 'dpapi':
        return '系统钥匙串（Windows DPAPI）';
      case 'keychain':
        return '系统钥匙串';
      default:
        return '本地文件（权限 0600）';
    }
  }
}

/// Shows only the head and tail of a token, for diagnostics.
String maskToken(String token) {
  if (token.isEmpty) return '—';
  if (token.length <= 8) return '*' * token.length;
  return '${token.substring(0, 4)}…${token.substring(token.length - 4)}';
}

/// Exposed for tests that need the fallback file location.
@visibleForTesting
String tokenVaultFile(AppPaths paths) => paths.accountFile.path;
