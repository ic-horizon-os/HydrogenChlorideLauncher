// Verifies the built-in public client talks to the legacy Live Connect
// endpoints. The live case stops at "device code issued" because completing a
// sign-in requires a human; run with HCL_LIVE=1.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/services/core_bridge.dart';
import 'package:hydrogen_chloride_launcher/core/services/microsoft_auth.dart';
import 'package:hydrogen_chloride_launcher/core/services/token_vault.dart';

final bool _live = Platform.environment['HCL_LIVE'] == '1';

const String _fixtureClientId = 'hcl-fixture-client-id';

void main() {
  test('device code endpoints are the Entra consumer endpoints', () {
    expect(
      MicrosoftAuthService.deviceCodeEndpointFor(_fixtureClientId),
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode',
    );
    expect(
      MicrosoftAuthService.tokenEndpointFor(_fixtureClientId),
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/token',
    );
  });

  test(
    'live: public client receives a device code',
    () async {
      final Directory root = Directory.systemTemp.createTempSync('hcl-ms-');
      addTearDown(() => root.deleteSync(recursive: true));
      final AppPaths paths = AppPaths.forTesting(root);
      await paths.ensure();
      final MicrosoftAuthService auth = MicrosoftAuthService(
        paths: paths,
        vault: TokenVault(
          paths: paths,
          core: CoreBridge(explicitPath: '/nonexistent/hcl-core'),
        ),
      );
      final DeviceCodeInfo info = await auth.requestDeviceCode(
        _fixtureClientId,
      );
      expect(info.userCode, isNotEmpty);
      expect(info.deviceCode, isNotEmpty);
      expect(info.verificationUri, contains('microsoft.com'));
      expect(info.interval.inSeconds, greaterThan(0));
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
