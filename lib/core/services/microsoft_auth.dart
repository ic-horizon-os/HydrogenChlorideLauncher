import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_paths.dart';
import '../models/account.dart';
import 'loopback_sign_in.dart';
import 'token_vault.dart';
import '../constants.dart';
import '../utils/json_utils.dart';

class DeviceCodeInfo {
  const DeviceCodeInfo({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.message,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String message;
  final Duration expiresIn;
  final Duration interval;
}

/// Handle for the loopback sign-in: open [url] in the browser, then await
/// [finish] to complete the Xbox/Minecraft exchange.
class BrowserSignInTicket {
  const BrowserSignInTicket({required this.url, required this.finish});

  final Uri url;
  final Future<MinecraftAccount> Function() finish;
}

class MicrosoftAuthException implements Exception {
  const MicrosoftAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Full Microsoft account -> Xbox Live -> XSTS -> Minecraft Services chain.
///
/// Tokens are kept by [TokenVault]: the OS keychain when it can be
/// reached, otherwise the 0600 `account.json` file.
class MicrosoftAuthService extends ChangeNotifier {
  MicrosoftAuthService({
    required this.paths,
    required this.vault,
    http.Client? client,
    Future<void> Function(Duration)? sleep,
  }) : _client = client ?? http.Client(),
       _sleep =
           sleep ?? ((Duration duration) => Future<void>.delayed(duration));

  final AppPaths paths;
  final TokenVault vault;
  final http.Client _client;
  final Future<void> Function(Duration) _sleep;

  MinecraftAccount? _account;
  String? _lastError;

  MinecraftAccount? get account => _account;
  bool get isLoggedIn => _account != null;
  String? get lastError => _lastError;

  /// The default public client only exists in the legacy Live Connect
  /// directory, so it must use login.live.com. A user's own Azure app uses the
  /// Microsoft identity platform (Entra) endpoints instead.
  static const String _liveDeviceCodeEndpoint =
      'https://login.live.com/oauth20_connect.srf';
  static const String _liveTokenEndpoint =
      'https://login.live.com/oauth20_token.srf';
  static const String _entraDeviceCodeEndpoint =
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode';
  static const String _entraTokenEndpoint =
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/token';

  static bool usesLiveConnect(String clientId) =>
      clientId.trim() == AppInfo.defaultMicrosoftClientId;

  static String deviceCodeEndpointFor(String clientId) =>
      usesLiveConnect(clientId)
      ? _liveDeviceCodeEndpoint
      : _entraDeviceCodeEndpoint;

  static String tokenEndpointFor(String clientId) =>
      usesLiveConnect(clientId) ? _liveTokenEndpoint : _entraTokenEndpoint;
  static const String _xblEndpoint =
      'https://user.auth.xboxlive.com/user/authenticate';
  static const String _xstsEndpoint =
      'https://xsts.auth.xboxlive.com/xsts/authorize';
  static const String _mcLoginEndpoint =
      'https://api.minecraftservices.com/authentication/login_with_xbox';
  static const String _mcProfileEndpoint =
      'https://api.minecraftservices.com/minecraft/profile';
  static const String _mcSkinEndpoint =
      'https://api.minecraftservices.com/minecraft/profile/skins';
  static const String _scope = 'XboxLive.signin offline_access';

  Future<void> load() async {
    final MinecraftAccount? stored = await vault.read();
    if (stored == null) return;
    _account = stored;
    notifyListeners();
  }

  /// Where the tokens currently live, for the account pane.
  String get storageLabel => vault.backendLabel;

  Future<DeviceCodeInfo> requestDeviceCode(String clientId) async {
    final String normalized = clientId.trim();
    if (normalized.isEmpty) {
      throw const MicrosoftAuthException(
        '请先填写 Azure 应用 client ID。',
        code: 'missing_client_id',
      );
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(deviceCodeEndpointFor(normalized)),
            headers: const <String, String>{
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: <String, String>{
              'client_id': normalized,
              'scope': _scope,
              // Live Connect requires this; Entra infers it from the endpoint.
              if (usesLiveConnect(normalized)) 'response_type': 'device_code',
            },
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const MicrosoftAuthException('连接 Microsoft 登录服务超时。');
    } on Object {
      throw const MicrosoftAuthException('无法连接 Microsoft 登录服务，请检查网络。');
    }

    final Map<String, dynamic> json = _decodeMap(response.body);
    if (response.statusCode != 200) {
      throw _errorFromResponse(response.statusCode, json, '获取设备码');
    }
    return DeviceCodeInfo(
      deviceCode: asString(json['device_code']),
      userCode: asString(json['user_code']),
      verificationUri: asString(
        json['verification_uri'],
        'https://microsoft.com/link',
      ),
      message: asString(json['message']),
      expiresIn: Duration(seconds: asInt(json['expires_in'], 900)),
      interval: Duration(
        seconds: asInt(json['interval'], 5).clamp(1, 60).toInt(),
      ),
    );
  }

  /// Starts browser sign-in (authorization code + PKCE + loopback redirect),
  /// the flow PCL2 and HMCL use. Returns once the browser has redirected back
  /// with the code; callers should open [LoopbackSignIn.authorizationUrl].
  ///
  /// The Azure app must register `http://localhost` as a redirect URI under
  /// "Mobile and desktop applications".
  Future<BrowserSignInTicket> beginBrowserSignIn(
    String clientId, {
    bool Function()? isCancelled,
    void Function(String status)? onStatus,
  }) async {
    final String normalized = clientId.trim();
    if (normalized.isEmpty) {
      throw const MicrosoftAuthException(
        '请先填写 Azure 应用 client ID。',
        code: 'missing_client_id',
      );
    }
    final LoopbackSignIn flow = LoopbackSignIn();
    final int port = await flow.listen();
    final ({String verifier, String challenge}) pkce = LoopbackSignIn.pkce();
    final String state = LoopbackSignIn.randomState();
    final Uri url = flow.authorizationUrl(
      clientId: normalized,
      codeChallenge: pkce.challenge,
      state: state,
      port: port,
      scope: _scope,
    );
    onStatus?.call('请在浏览器中完成 Microsoft 登录…');

    Future<MinecraftAccount> finish() async {
      try {
        final ({String code, String? error}) result = await flow.waitForCode();
        if (isCancelled?.call() ?? false) {
          throw const MicrosoftAuthException('登录已取消。', code: 'cancelled');
        }
        if (result.error != null) {
          throw MicrosoftAuthException(
            result.error == 'access_denied'
                ? '登录请求已被取消或拒绝。'
                : 'Microsoft 登录失败：${result.error}',
            code: result.error,
          );
        }
        if (result.code.isEmpty) {
          throw const MicrosoftAuthException('回调中没有授权码。');
        }
        onStatus?.call('正在验证 Xbox 与 Minecraft 账户…');
        final http.Response response;
        try {
          response = await _client
              .post(
                Uri.parse(tokenEndpointFor(normalized)),
                headers: const <String, String>{
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Accept': 'application/json',
                },
                body: <String, String>{
                  'grant_type': 'authorization_code',
                  'client_id': normalized,
                  'code': result.code,
                  'redirect_uri': LoopbackSignIn.redirectUri(port),
                  'code_verifier': pkce.verifier,
                  'scope': _scope,
                },
              )
              .timeout(const Duration(seconds: 30));
        } on TimeoutException {
          throw const MicrosoftAuthException('换取登录令牌超时。');
        } on Object {
          throw const MicrosoftAuthException('无法连接 Microsoft 登录服务。');
        }
        final Map<String, dynamic> json = _decodeMap(response.body);
        if (response.statusCode != 200 || json['access_token'] is! String) {
          throw _errorFromResponse(response.statusCode, json, '换取登录令牌');
        }
        return await _exchange(
          asString(json['access_token']),
          refreshToken: asStringOrNull(json['refresh_token']),
        );
      } finally {
        await flow.close();
      }
    }

    return BrowserSignInTicket(url: url, finish: finish);
  }

  Future<MinecraftAccount> waitForLogin(
    DeviceCodeInfo info, {
    required String clientId,
    void Function(String status)? onStatus,
    bool Function()? isCancelled,
  }) async {
    final String normalized = clientId.trim();
    Duration interval = info.interval;
    final DateTime deadline = DateTime.now().add(info.expiresIn);

    while (true) {
      if (isCancelled?.call() ?? false) {
        throw const MicrosoftAuthException('登录已取消。', code: 'cancelled');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const MicrosoftAuthException(
          '设备码已过期，请重新开始登录。',
          code: 'expired_token',
        );
      }

      onStatus?.call('等待 Microsoft 账户确认…');
      final http.Response response;
      try {
        response = await _client
            .post(
              Uri.parse(tokenEndpointFor(normalized)),
              headers: const <String, String>{
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
              },
              body: <String, String>{
                'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
                'client_id': normalized,
                'device_code': info.deviceCode,
              },
            )
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        throw const MicrosoftAuthException('轮询登录结果超时。');
      } on Object {
        throw const MicrosoftAuthException('无法连接 Microsoft 登录服务，请检查网络。');
      }

      final Map<String, dynamic> json = _decodeMap(response.body);
      if (response.statusCode == 200 && json['access_token'] is String) {
        onStatus?.call('正在验证 Xbox 与 Minecraft 账户…');
        return _exchange(
          asString(json['access_token']),
          refreshToken: asStringOrNull(json['refresh_token']),
        );
      }

      final String error = asString(json['error']);
      switch (error) {
        case 'authorization_pending':
          await _sleep(interval);
          break;
        case 'slow_down':
          interval += const Duration(seconds: 5);
          await _sleep(interval);
          break;
        case 'expired_token':
          throw const MicrosoftAuthException(
            '设备码已过期，请重新开始登录。',
            code: 'expired_token',
          );
        case 'authorization_declined':
          throw const MicrosoftAuthException(
            '登录请求已被拒绝。',
            code: 'authorization_declined',
          );
        case 'bad_verification_code':
          throw const MicrosoftAuthException(
            '设备码无效，请重新开始登录。',
            code: 'bad_verification_code',
          );
        default:
          throw MicrosoftAuthException(
            asString(
              json['error_description'],
              'Microsoft 登录失败（${response.statusCode}）。',
            ),
            code: error.isEmpty ? null : error,
          );
      }
    }
  }

  Future<MinecraftAccount> _exchange(
    String microsoftAccessToken, {
    String? refreshToken,
  }) async {
    final Map<String, dynamic> xbl = await _postJson(
      Uri.parse(_xblEndpoint),
      <String, Object?>{
        'Properties': <String, Object?>{
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=$microsoftAccessToken',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      },
      context: 'Xbox Live 验证',
    );
    final String xblToken = asString(xbl['Token']);
    if (xblToken.isEmpty) {
      throw const MicrosoftAuthException('Xbox Live 返回了空令牌。');
    }

    final http.Response xstsResponse;
    try {
      xstsResponse = await _client
          .post(
            Uri.parse(_xstsEndpoint),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'Properties': <String, Object?>{
                'SandboxId': 'RETAIL',
                'UserTokens': <String>[xblToken],
              },
              'RelyingParty': 'rp://api.minecraftservices.com/',
              'TokenType': 'JWT',
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const MicrosoftAuthException('XSTS 验证超时。');
    } on Object {
      throw const MicrosoftAuthException('无法连接 Xbox 安全令牌服务。');
    }

    final Map<String, dynamic> xstsJson = _decodeMap(xstsResponse.body);
    if (xstsResponse.statusCode != 200) {
      throw _xstsError(xstsJson);
    }
    final String xstsToken = asString(xstsJson['Token']);
    final Map<String, dynamic> claims = asMap(xstsJson['DisplayClaims']);
    final List<Map<String, dynamic>> xui = asMapList(claims['xui']);
    final Map<String, dynamic> claim = xui.isEmpty
        ? <String, dynamic>{}
        : xui.first;
    final String userHash = asString(claim['uhs']);
    final String? gamertag = asStringOrNull(claim['gtg']);
    final String? xuid = asStringOrNull(claim['xid']);
    if (xstsToken.isEmpty || userHash.isEmpty) {
      throw const MicrosoftAuthException('XSTS 令牌缺少用户标识。');
    }

    final Map<String, dynamic> mc = await _postJson(
      Uri.parse(_mcLoginEndpoint),
      <String, Object?>{'identityToken': 'XBL3.0 x=$userHash;$xstsToken'},
      context: 'Minecraft 登录',
    );
    final String minecraftAccessToken = asString(mc['access_token']);
    if (minecraftAccessToken.isEmpty) {
      throw const MicrosoftAuthException('Minecraft 服务返回了空访问令牌。');
    }
    final int expiresIn = asInt(mc['expires_in'], 86400);

    final http.Response profileResponse;
    try {
      profileResponse = await _client
          .get(
            Uri.parse(_mcProfileEndpoint),
            headers: <String, String>{
              'Authorization': 'Bearer $minecraftAccessToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const MicrosoftAuthException('获取 Minecraft 档案超时。');
    } on Object {
      throw const MicrosoftAuthException('无法连接 Minecraft 服务。');
    }

    String name = gamertag ?? 'Minecraft 玩家';
    String uuid = '';
    bool ownsMinecraft = false;
    if (profileResponse.statusCode == 200) {
      final Map<String, dynamic> profile = _decodeMap(profileResponse.body);
      uuid = asString(profile['id']);
      name = asString(profile['name'], name);
      ownsMinecraft = uuid.isNotEmpty;
    } else if (profileResponse.statusCode != 404) {
      throw _errorFromResponse(
        profileResponse.statusCode,
        _decodeMap(profileResponse.body),
        '获取 Minecraft 档案',
      );
    }

    final MinecraftAccount account = MinecraftAccount(
      accessToken: minecraftAccessToken,
      refreshToken: refreshToken,
      uuid: uuid,
      name: name,
      gamertag: gamertag,
      xuid: xuid,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      ownsMinecraft: ownsMinecraft,
    );
    _account = account;
    _lastError = null;
    await _save();
    notifyListeners();
    return account;
  }

  /// Uploads a PNG/JPG skin to the logged-in account.
  ///
  /// Mojang wants either a multipart `file` upload or a `url` pointing at the
  /// texture; local files use the multipart form. [variant] is `classic` or
  /// `slim`.
  Future<void> uploadSkin(File file, {String variant = 'classic'}) async {
    final MinecraftAccount? current = _account;
    if (current == null) {
      throw const MicrosoftAuthException('请先登录 Microsoft 账户。');
    }
    final String name = file.path.toLowerCase();
    final bool modern = name.endsWith('.png') && variant != 'legacy';
    final Map<String, String> fields = <String, String>{
      'variant': modern ? variant : 'classic',
    };
    final http.MultipartRequest request =
        http.MultipartRequest('POST', Uri.parse(_mcSkinEndpoint))
          ..headers['Authorization'] = 'Bearer ${current.accessToken}'
          ..headers['Accept'] = 'application/json'
          ..fields.addAll(fields)
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path,
              contentType: MediaType(
                'image',
                file.path.toLowerCase().endsWith('.jpg') ||
                        file.path.toLowerCase().endsWith('.jpeg')
                    ? 'jpeg'
                    : 'png',
              ),
            ),
          );
    final http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const MicrosoftAuthException('上传皮肤超时。');
    } on Object {
      throw const MicrosoftAuthException('无法连接 Minecraft 服务。');
    }
    final String body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw _errorFromResponse(response.statusCode, _decodeMap(body), '上传皮肤');
  }

  /// Called before launching: refreshes an expired token when a client ID is
  /// available, and reports whether the account is usable.
  Future<String?> prepareForLaunch({required String? clientId}) async {
    final MinecraftAccount? current = _account;
    if (current == null) return '需要先登录 Microsoft 账户才能启动 Minecraft。';
    if (!current.ownsMinecraft) {
      return '该账户没有 Minecraft: Java Edition 档案。';
    }
    if (current.isExpired) {
      final String? id = clientId;
      if (id == null) {
        return '登录令牌已过期，请在设置中填写 Azure client ID 后重新登录。';
      }
      final bool ok = await refreshIfNeeded(clientId: id);
      if (!ok) {
        return _lastError ?? '登录令牌已过期，请重新登录。';
      }
    }
    return null;
  }

  Future<bool> refreshIfNeeded({required String clientId}) async {
    final MinecraftAccount? current = _account;
    if (current == null || !current.isExpired) return current != null;
    final String? refreshToken = current.refreshToken;
    if (refreshToken == null) {
      _lastError = '登录已过期，请重新登录。';
      notifyListeners();
      return false;
    }
    try {
      final Map<String, dynamic> token = await _postForm(
        Uri.parse(tokenEndpointFor(clientId)),
        <String, String>{
          'grant_type': 'refresh_token',
          'client_id': clientId.trim(),
          'refresh_token': refreshToken,
          'scope': _scope,
        },
        context: '刷新登录令牌',
      );
      await _exchange(
        asString(token['access_token']),
        refreshToken: asStringOrNull(token['refresh_token']) ?? refreshToken,
      );
      return true;
    } on MicrosoftAuthException catch (error) {
      _lastError = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _account = null;
    _lastError = null;
    try {
      await vault.delete();
    } on Object {
      // The in-memory session is cleared even if storage cannot be removed.
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final MinecraftAccount? current = _account;
    if (current == null) return;
    try {
      await vault.write(current);
    } on Object catch (error) {
      // Losing the refresh token only costs a re-login next launch.
      _lastError = '保存登录令牌失败：$error';
    }
  }

  Future<Map<String, dynamic>> _postForm(
    Uri uri,
    Map<String, String> body, {
    required String context,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw MicrosoftAuthException('$context超时。');
    } on Object {
      throw MicrosoftAuthException('无法连接$context服务。');
    }
    final Map<String, dynamic> json = _decodeMap(response.body);
    if (response.statusCode >= 400) {
      throw _errorFromResponse(response.statusCode, json, context);
    }
    return json;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    required String context,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw MicrosoftAuthException('$context超时。');
    } on Object {
      throw MicrosoftAuthException('无法连接$context服务。');
    }
    final Map<String, dynamic> json = _decodeMap(response.body);
    if (response.statusCode >= 400) {
      throw _errorFromResponse(response.statusCode, json, context);
    }
    return json;
  }

  static Map<String, dynamic> _decodeMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (Object? key, Object? value) => MapEntry('$key', value),
        );
      }
    } on FormatException {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static MicrosoftAuthException _errorFromResponse(
    int status,
    Map<String, dynamic> json,
    String context,
  ) {
    final String? error = asStringOrNull(json['error']);
    final String? description = asStringOrNull(json['error_description']);
    if (status == 429) {
      return const MicrosoftAuthException(
        '请求过于频繁，请稍后再试。',
        code: 'too_many_requests',
      );
    }
    if (status >= 500) {
      return MicrosoftAuthException('$context服务暂时不可用（HTTP $status）。');
    }
    return MicrosoftAuthException(
      description ?? '$context失败（HTTP $status）。',
      code: error,
    );
  }

  static MicrosoftAuthException _xstsError(Map<String, dynamic> json) {
    final String xerr = asString(json['XErr']);
    switch (xerr) {
      case '2148916233':
        return const MicrosoftAuthException(
          '该 Microsoft 账户尚未创建 Xbox 档案。请先在 xbox.com 登录一次。',
          code: 'no_xbox_profile',
        );
      case '2148916238':
        return const MicrosoftAuthException(
          '这是一个儿童账户，需要由家庭组管理员授权后才能登录。',
          code: 'child_account',
        );
      case '2148916235':
        return const MicrosoftAuthException(
          '该账户所在地区不支持 Xbox Live。',
          code: 'region_blocked',
        );
      default:
        return MicrosoftAuthException(
          'Xbox 安全令牌验证失败（XErr: ${xerr.isEmpty ? 'unknown' : xerr}）。',
          code: xerr.isEmpty ? null : xerr,
        );
    }
  }
}
