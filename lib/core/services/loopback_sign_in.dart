import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Interactive browser sign-in using the OAuth 2.0 authorization-code flow
/// with a loopback redirect, the same approach PCL2/HMCL use.
///
/// Requires the Azure app registration to list `http://localhost` under
/// "Mobile and desktop applications" redirect URIs. RFC 8252 allows any port
/// on loopback, so we bind an ephemeral port at runtime.
class LoopbackSignIn {
  LoopbackSignIn({
    this.host = 'localhost',
    List<int>? candidatePorts,
    Duration? timeout,
  }) : candidatePorts = candidatePorts ?? defaultPorts,
       timeout = timeout ?? const Duration(minutes: 5);

  /// Common desktop-client ports tried first so the Windows firewall prompt is
  /// usually already approved; 0 lets the OS pick any free port last.
  static const List<int> defaultPorts = <int>[
    42420,
    42421,
    42422,
    42423,
    42424,
    0,
  ];

  final String host;
  final List<int> candidatePorts;
  final Duration timeout;

  HttpServer? _server;
  Completer<_Callback>? _completer;

  /// Authorization URL for the caller to open in a browser.
  Uri authorizationUrl({
    required String clientId,
    required String codeChallenge,
    required String state,
    required int port,
    String scope = 'XboxLive.signin offline_access',
  }) {
    return Uri.https(
      'login.microsoftonline.com',
      '/consumers/oauth2/v2.0/authorize',
      <String, String>{
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri(port),
        'response_mode': 'query',
        'scope': scope,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account',
      },
    );
  }

  static String redirectUri(int port) => 'http://localhost:$port/auth/callback';

  /// Binds the loopback listener and returns the port actually in use.
  Future<int> listen() async {
    Object? lastError;
    for (final int candidate in candidatePorts) {
      try {
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          candidate,
        );
        _server = server;
        _completer = Completer<_Callback>();
        server.listen(_handle);
        return server.port;
      } on SocketException catch (error) {
        lastError = error;
      }
    }
    throw StateError('无法在本地端口启动登录回调服务：$lastError');
  }

  /// Completes when the browser redirect arrives, or throws on timeout.
  Future<({String code, String? error})> waitForCode() async {
    final Completer<_Callback> completer = _completer!;
    final _Callback callback = await completer.future.timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('等待浏览器登录超时。');
      },
    );
    return (code: callback.code, error: callback.error);
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final Uri uri = request.uri;
    if (uri.path != '/auth/callback') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await request.response.close();
      return;
    }
    final String? error = uri.queryParameters['error'];
    final String code = uri.queryParameters['code'] ?? '';
    final String? description = uri.queryParameters['error_description'];
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_resultPage(error: error, description: description));
    await request.response.close();

    final Completer<_Callback>? completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(_Callback(code: code, error: error));
    }
  }

  static String _resultPage({String? error, String? description}) {
    final bool ok = error == null;
    final String title = _escapeHtml(ok ? '登录完成' : '登录失败');
    final String? detail = description;
    final String failure = detail != null && detail.isNotEmpty
        ? detail
        : 'Microsoft 返回了错误 ${error ?? ''}';
    final String message = _escapeHtml(ok ? '可以关闭此页面，回到启动器继续。' : failure);
    final StringBuffer html = StringBuffer()
      ..write('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">')
      ..write('<title>')
      ..write(title)
      ..write('</title>')
      ..write(_pageStyle)
      ..write('</head><body><div class="box"><h1>')
      ..write(title)
      ..write('</h1><p>')
      ..write(message)
      ..write('</p></div></body></html>');
    return html.toString();
  }

  static const String _pageStyle =
      '<style>'
      'body{margin:0;height:100vh;display:flex;align-items:center;'
      'justify-content:center;font-family:system-ui,-apple-system,sans-serif;'
      'background:#1a1a1a;color:#eee}'
      '.box{text-align:center;max-width:32rem;padding:2rem}'
      'h1{font-size:1.5rem;font-weight:600;margin:0 0 .75rem}'
      'p{color:#aaa;line-height:1.6;margin:0}'
      '</style>';

  static String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// RFC 7636 S256 challenge from a fresh random verifier.
  static ({String verifier, String challenge}) pkce() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final String verifier = _base64Url(bytes);
    final String challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    return (verifier: verifier, challenge: challenge);
  }

  static String randomState() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return _base64Url(bytes);
  }

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}

class _Callback {
  const _Callback({required this.code, required this.error});

  final String code;
  final String? error;
}
