import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/models/account.dart';
import 'package:hydrogen_chloride_launcher/core/services/core_bridge.dart';
import 'package:hydrogen_chloride_launcher/core/services/microsoft_auth.dart';
import 'package:hydrogen_chloride_launcher/core/services/token_vault.dart';

http.Response _json(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _deviceCodeBody() => <String, dynamic>{
  'device_code': 'device-code',
  'user_code': 'ABCD-EFGH',
  'verification_uri': 'https://microsoft.com/link',
  'expires_in': 900,
  'interval': 5,
  'message': 'Use the code to sign in.',
};

MockClient _fullChainClient({
  required List<Map<String, dynamic>> tokenResponses,
  int xstsStatus = 200,
  Map<String, dynamic>? xstsBody,
  void Function(String microsoftToken)? onMicrosoftToken,
}) {
  int tokenCalls = 0;
  return MockClient((http.Request request) async {
    final String host = request.url.host;
    if (host == 'login.microsoftonline.com' &&
        request.url.path.endsWith('/devicecode')) {
      return _json(_deviceCodeBody());
    }
    if (host == 'login.microsoftonline.com' &&
        request.url.path.endsWith('/token')) {
      final Map<String, String> body = Uri.splitQueryString(request.body);
      if (body['grant_type'] == 'refresh_token') {
        return _json(<String, dynamic>{
          'access_token': 'ms-refreshed',
          'refresh_token': 'refresh-new',
          'expires_in': 3600,
        });
      }
      final Map<String, dynamic> response =
          tokenResponses[tokenCalls
              .clamp(0, tokenResponses.length - 1)
              .toInt()];
      tokenCalls++;
      return _json(response, status: response['error'] == null ? 200 : 400);
    }
    if (host == 'user.auth.xboxlive.com') {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      final Map<String, dynamic> properties =
          body['Properties'] as Map<String, dynamic>;
      onMicrosoftToken?.call(properties['RpsTicket'] as String);
      return _json(<String, dynamic>{'Token': 'xbl-token'});
    }
    if (host == 'xsts.auth.xboxlive.com') {
      if (xstsStatus != 200) {
        return _json(
          xstsBody ?? <String, dynamic>{'XErr': 2148916238},
          status: xstsStatus,
        );
      }
      return _json(
        xstsBody ??
            <String, dynamic>{
              'Token': 'xsts-token',
              'DisplayClaims': <String, dynamic>{
                'xui': <Object?>[
                  <String, dynamic>{
                    'uhs': 'user-hash',
                    'gtg': 'TestGamer',
                    'xid': 'xuid-1',
                  },
                ],
              },
            },
      );
    }
    if (host == 'api.minecraftservices.com' &&
        request.url.path.endsWith('/login_with_xbox')) {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['identityToken'], 'XBL3.0 x=user-hash;xsts-token');
      return _json(<String, dynamic>{
        'access_token': 'mc-token',
        'expires_in': 86400,
      });
    }
    if (host == 'api.minecraftservices.com' &&
        request.url.path.endsWith('/minecraft/profile')) {
      expect(request.headers['Authorization'], 'Bearer mc-token');
      return _json(<String, dynamic>{'id': 'uuid-1234', 'name': 'Steve'});
    }
    return _json(<String, dynamic>{
      'error': 'unexpected ${request.url}',
    }, status: 500);
  });
}

void main() {
  test('device code response is parsed', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-auth-device-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();

    final MicrosoftAuthService service = MicrosoftAuthService(
      paths: paths,
      vault: TokenVault(
        paths: paths,
        core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
      ),
      client: MockClient((http.Request request) async {
        expect(request.url.host, 'login.microsoftonline.com');
        final Map<String, String> body = Uri.splitQueryString(request.body);
        expect(body['client_id'], 'client-id');
        expect(body['scope'], contains('XboxLive.signin'));
        return _json(_deviceCodeBody());
      }),
      sleep: (Duration _) async {},
    );
    addTearDown(service.dispose);

    final DeviceCodeInfo info = await service.requestDeviceCode('client-id');
    expect(info.deviceCode, 'device-code');
    expect(info.userCode, 'ABCD-EFGH');
    expect(info.verificationUri, 'https://microsoft.com/link');
    expect(info.interval, const Duration(seconds: 5));
    expect(info.expiresIn, const Duration(seconds: 900));

    await expectLater(
      service.requestDeviceCode('  '),
      throwsA(isA<MicrosoftAuthException>()),
    );
  });

  test('polling reaches a Minecraft account through the full chain', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-auth-full-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();
    final List<Duration> sleeps = <Duration>[];
    String? microsoftToken;

    final MicrosoftAuthService service = MicrosoftAuthService(
      paths: paths,
      vault: TokenVault(
        paths: paths,
        core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
      ),
      client: _fullChainClient(
        tokenResponses: <Map<String, dynamic>>[
          <String, dynamic>{'error': 'authorization_pending'},
          <String, dynamic>{
            'access_token': 'ms-token',
            'refresh_token': 'refresh-token',
          },
        ],
        onMicrosoftToken: (String token) => microsoftToken = token,
      ),
      sleep: (Duration duration) async => sleeps.add(duration),
    );
    addTearDown(service.dispose);
    final DeviceCodeInfo info = await service.requestDeviceCode('client-id');
    final MinecraftAccount account = await service.waitForLogin(
      info,
      clientId: 'client-id',
      onStatus: (String _) {},
    );

    expect(microsoftToken, 'd=ms-token');
    expect(account.name, 'Steve');
    expect(account.uuid, 'uuid-1234');
    expect(account.gamertag, 'TestGamer');
    expect(account.xuid, 'xuid-1');
    expect(account.ownsMinecraft, isTrue);
    expect(account.refreshToken, 'refresh-token');
    expect(account.expiresAt, isNotNull);
    expect(sleeps, <Duration>[const Duration(seconds: 5)]);
    expect(service.isLoggedIn, isTrue);
    expect(paths.accountFile.existsSync(), isTrue);
  });

  test('slow_down increases the polling interval', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-auth-slow-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();
    final List<Duration> sleeps = <Duration>[];

    final MicrosoftAuthService service = MicrosoftAuthService(
      paths: paths,
      vault: TokenVault(
        paths: paths,
        core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
      ),
      client: _fullChainClient(
        tokenResponses: <Map<String, dynamic>>[
          <String, dynamic>{'error': 'authorization_pending'},
          <String, dynamic>{'error': 'slow_down'},
          <String, dynamic>{
            'access_token': 'ms-token',
            'refresh_token': 'refresh-token',
          },
        ],
      ),
      sleep: (Duration duration) async => sleeps.add(duration),
    );
    addTearDown(service.dispose);
    final DeviceCodeInfo info = await service.requestDeviceCode('client-id');
    await service.waitForLogin(info, clientId: 'client-id');

    expect(sleeps, <Duration>[
      const Duration(seconds: 5),
      const Duration(seconds: 10),
    ]);
  });

  test('XSTS child-account error is mapped to a readable message', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-auth-xsts-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();

    final MicrosoftAuthService service = MicrosoftAuthService(
      paths: paths,
      vault: TokenVault(
        paths: paths,
        core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
      ),
      client: _fullChainClient(
        tokenResponses: <Map<String, dynamic>>[
          <String, dynamic>{
            'access_token': 'ms-token',
            'refresh_token': 'refresh-token',
          },
        ],
        xstsStatus: 401,
      ),
      sleep: (Duration _) async {},
    );
    addTearDown(service.dispose);
    final DeviceCodeInfo info = await service.requestDeviceCode('client-id');

    await expectLater(
      service.waitForLogin(info, clientId: 'client-id'),
      throwsA(
        isA<MicrosoftAuthException>().having(
          (MicrosoftAuthException error) => error.message,
          'message',
          contains('家庭组'),
        ),
      ),
    );
  });

  test('expired account refreshes its token', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'hcl-auth-refresh-',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();
    final MinecraftAccount expired = MinecraftAccount(
      accessToken: 'old-token',
      refreshToken: 'refresh-old',
      uuid: 'uuid-old',
      name: 'OldName',
      gamertag: 'OldGamer',
      xuid: 'xuid-old',
      expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ownsMinecraft: true,
    );
    File(paths.accountFile.path)
        .writeAsStringSync(jsonEncode(expired.toJson()));

    final MicrosoftAuthService service = MicrosoftAuthService(
      paths: paths,
      vault: TokenVault(
        paths: paths,
        core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
      ),
      client: _fullChainClient(tokenResponses: <Map<String, dynamic>>[]),
      sleep: (Duration _) async {},
    );
    addTearDown(service.dispose);
    await service.load();
    expect(service.account?.isExpired, isTrue);

    final bool refreshed = await service.refreshIfNeeded(clientId: 'client-id');
    expect(refreshed, isTrue);
    expect(service.account?.name, 'Steve');
    expect(service.account?.refreshToken, 'refresh-new');
    expect(service.account?.accessToken, 'mc-token');
  });
}
