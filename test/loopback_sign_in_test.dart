import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hydrogen_chloride_launcher/core/services/loopback_sign_in.dart';

void main() {
  group('PKCE', () {
    test('challenge is the S256 hash of the verifier', () {
      final ({String verifier, String challenge}) pair = LoopbackSignIn.pkce();
      final String expected = base64Url
          .encode(sha256.convert(utf8.encode(pair.verifier)).bytes)
          .replaceAll('=', '');
      expect(pair.challenge, expected);
      // RFC 7636: verifier is 43-128 chars of unreserved characters.
      expect(pair.verifier.length, greaterThanOrEqualTo(43));
      expect(pair.verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
    });

    test('each call produces a different verifier', () {
      expect(
        LoopbackSignIn.pkce().verifier,
        isNot(LoopbackSignIn.pkce().verifier),
      );
    });
  });

  group('authorization url', () {
    test('points at the consumer endpoint with loopback redirect', () {
      final Uri url = LoopbackSignIn().authorizationUrl(
        clientId: 'my-client',
        codeChallenge: 'challenge',
        state: 'state-1',
        port: 42420,
      );
      expect(url.host, 'login.microsoftonline.com');
      expect(url.path, '/consumers/oauth2/v2.0/authorize');
      expect(url.queryParameters['client_id'], 'my-client');
      expect(
        url.queryParameters['redirect_uri'],
        'http://localhost:42420/auth/callback',
      );
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['state'], 'state-1');
      expect(url.queryParameters['scope'], contains('XboxLive.signin'));
    });
  });

  group('loopback listener', () {
    test('receives the code from the browser redirect', () async {
      final LoopbackSignIn flow = LoopbackSignIn();
      addTearDown(flow.close);
      final int port = await flow.listen();

      final Future<({String code, String? error})> pending = flow.waitForCode();
      final http.Response response = await http.get(
        Uri.parse('http://127.0.0.1:$port/auth/callback?code=abc123&state=x'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.body, contains('登录完成'));

      final ({String code, String? error}) result = await pending;
      expect(result.code, 'abc123');
      expect(result.error, isNull);
    });

    test('surfaces an access_denied error from the callback', () async {
      final LoopbackSignIn flow = LoopbackSignIn();
      addTearDown(flow.close);
      final int port = await flow.listen();
      final Future<({String code, String? error})> pending = flow.waitForCode();
      await http.get(
        Uri.parse('http://127.0.0.1:$port/auth/callback?error=access_denied'),
      );
      final ({String code, String? error}) result = await pending;
      expect(result.error, 'access_denied');
      expect(result.code, isEmpty);
    });

    test('returns 404 for other paths and keeps waiting', () async {
      final LoopbackSignIn flow = LoopbackSignIn();
      addTearDown(flow.close);
      final int port = await flow.listen();
      final Future<({String code, String? error})> pending = flow.waitForCode();
      final http.Response miss = await http.get(
        Uri.parse('http://127.0.0.1:$port/favicon.ico'),
      );
      expect(miss.statusCode, 404);
      await http.get(Uri.parse('http://127.0.0.1:$port/auth/callback?code=ok'));
      expect((await pending).code, 'ok');
    });

    test('times out when the browser never returns', () async {
      final LoopbackSignIn flow = LoopbackSignIn(
        timeout: const Duration(milliseconds: 200),
      );
      addTearDown(flow.close);
      await flow.listen();
      expect(flow.waitForCode(), throwsA(isA<TimeoutException>()));
    });
  });
}
