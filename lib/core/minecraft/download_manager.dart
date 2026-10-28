import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// One file the pipeline needs on disk. [url] must already be mirror-rewritten.
class DownloadRequest {
  const DownloadRequest({
    required this.url,
    required this.destination,
    this.sha1,
    this.size,
  });

  final String url;
  final String destination;

  /// Expected SHA-1 from Mojang metadata. When null the file is trusted as-is
  /// but still written atomically.
  final String? sha1;
  final int? size;

  String get name => p.basename(destination);
}

class DownloadBatchResult {
  const DownloadBatchResult({
    required this.downloaded,
    required this.reused,
    required this.bytes,
    required this.failures,
  });

  final int downloaded;
  final int reused;
  final int bytes;
  final List<DownloadFailure> failures;

  bool get ok => failures.isEmpty;
}

class DownloadFailure {
  const DownloadFailure(this.request, this.error);

  final DownloadRequest request;
  final Object error;
}

class DownloadProgress {
  const DownloadProgress({
    required this.completed,
    required this.total,
    required this.currentFile,
    required this.bytesDone,
    required this.bytesTotal,
  });

  final int completed;
  final int total;
  final String currentFile;
  final int bytesDone;
  final int bytesTotal;

  double get fraction {
    if (bytesTotal > 0) return (bytesDone / bytesTotal).clamp(0.0, 1.0);
    return total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);
  }
}

/// Concurrent, resumable downloader. Every write goes through a `.part` file
/// and is renamed only after the SHA-1 matches, so an interrupted run never
/// leaves a truncated file that later looks valid.
class DownloadManager {
  DownloadManager({
    http.Client? client,
    this.concurrency = 8,
    this.retries = 3,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  static const String userAgent =
      'HydrogenChlorideLauncher/0.1.0-alpha.1 (github.com/HyaLab-Soft/HydrogenChlorideLauncher)';

  /// minecraft.net sits behind Akamai, which stalls connections that carry an
  /// unrecognised crawler-looking User-Agent. Use a browser UA for that host
  /// only; Mojang/modrinth/etc. still see the honest launcher identifier.
  static const String _browserUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  static String userAgentFor(String url) {
    final String host = Uri.tryParse(url)?.host ?? '';
    if (host == 'www.minecraft.net' || host.endsWith('.minecraft.net')) {
      return _browserUserAgent;
    }
    return userAgent;
  }

  final http.Client _client;
  final int concurrency;
  final int retries;

  /// Connection timeout for a single request or a single streamed chunk read.
  final Duration timeout;

  /// Runs [requests] with bounded concurrency. Progress is reported through
  /// [onProgress] after each file and repeatedly while streaming.
  Future<DownloadBatchResult> run(
    List<DownloadRequest> requests, {
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final List<DownloadRequest> pending = <DownloadRequest>[];
    int reused = 0;
    for (final DownloadRequest request in requests) {
      if (await _isUpToDate(request)) {
        reused++;
      } else {
        pending.add(request);
      }
    }

    int completed = reused;
    final int total = requests.length;
    int bytesDone = 0;
    final int bytesTotal = pending.fold(
      0,
      (int sum, DownloadRequest request) => sum + (request.size ?? 0),
    );
    final List<DownloadFailure> failures = <DownloadFailure>[];
    final String currentFile = pending.isEmpty ? '' : pending.first.name;
    onProgress?.call(
      DownloadProgress(
        completed: completed,
        total: total,
        currentFile: currentFile,
        bytesDone: 0,
        bytesTotal: bytesTotal,
      ),
    );

    final _Queue queue = _Queue(pending);
    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) return;
        final DownloadRequest? request = queue.next();
        if (request == null) return;
        try {
          await _download(request, (int written) {
            onProgress?.call(
              DownloadProgress(
                completed: completed,
                total: total,
                currentFile: request.name,
                bytesDone: bytesDone + written,
                bytesTotal: bytesTotal,
              ),
            );
          });
          bytesDone += request.size ?? 0;
          completed++;
          onProgress?.call(
            DownloadProgress(
              completed: completed,
              total: total,
              currentFile: request.name,
              bytesDone: bytesDone,
              bytesTotal: bytesTotal,
            ),
          );
        } on Object catch (error) {
          failures.add(DownloadFailure(request, error));
        }
      }
    }

    final int workers = pending.length < concurrency
        ? pending.length
        : concurrency;
    await Future.wait(<Future<void>>[
      for (int i = 0; i < workers; i++) worker(),
    ]);
    return DownloadBatchResult(
      downloaded: completed - reused,
      reused: reused,
      bytes: bytesDone,
      failures: failures,
    );
  }

  /// Downloads a single URL and returns the raw bytes (metadata files).
  /// [timeoutOverride] widens the per-attempt timeout for slow mirrors.
  Future<List<int>> fetchBytes(
    String url, {
    int retries = 3,
    Duration? timeoutOverride,
  }) async {
    Object? lastError;
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final http.Response response = await _client
            .get(
              Uri.parse(url),
              headers: <String, String>{'User-Agent': userAgentFor(url)},
            )
            .timeout(timeoutOverride ?? timeout);
        if (response.statusCode == 200) return response.bodyBytes;
        lastError = HttpStatusError(url, response.statusCode);
      } on Object catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? HttpStatusError(url, 0);
  }

  Future<Map<String, dynamic>> fetchJson(String url) async {
    final List<int> bytes = await fetchBytes(url);
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('$url 返回的不是 JSON 对象。');
  }

  Future<bool> _isUpToDate(DownloadRequest request) async {
    final File file = File(request.destination);
    if (!await file.exists()) return false;
    final String? expected = request.sha1;
    if (expected == null || expected.isEmpty) return true;
    try {
      final int expectedSize = request.size ?? 0;
      if (expectedSize > 0 && await file.length() != expectedSize) {
        return false;
      }
      return await sha1OfFile(file.path) == expected.toLowerCase();
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _download(
    DownloadRequest request,
    void Function(int written) onBytes,
  ) async {
    await Directory(p.dirname(request.destination)).create(recursive: true);
    final File part = File('${request.destination}.part');
    Object? lastError;
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        int existing = 0;
        if (await part.exists()) {
          existing = await part.length();
        }
        final Map<String, String> headers = <String, String>{
          'User-Agent': userAgentFor(request.url),
          if (existing > 0) 'Range': 'bytes=$existing-',
        };
        final http.StreamedResponse response = await _client
            .send(
              http.Request('GET', Uri.parse(request.url))
                ..headers.addAll(headers),
            )
            .timeout(timeout);
        if (response.statusCode == 416) {
          await part.delete();
          continue;
        }
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw HttpStatusError(request.url, response.statusCode);
        }
        // A 200 means the server ignored the range; restart from zero.
        final IOSink sink = part.openWrite(
          mode: response.statusCode == 206 ? FileMode.append : FileMode.write,
        );
        int written = response.statusCode == 206 ? existing : 0;
        try {
          // Guard each chunk so a stalled mirror cannot hang a worker forever.
          final StreamIterator<List<int>> iterator = StreamIterator<List<int>>(
            response.stream.timeout(timeout),
          );
          try {
            while (await iterator.moveNext()) {
              final List<int> chunk = iterator.current;
              sink.add(chunk);
              written += chunk.length;
              onBytes(written);
            }
          } finally {
            await iterator.cancel();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        final String? expected = request.sha1;
        if (expected != null && expected.isNotEmpty) {
          final String actual = await sha1OfFile(part.path);
          if (actual != expected.toLowerCase()) {
            await part.delete();
            throw HashMismatchError(request.url, expected, actual);
          }
        }
        await part.rename(request.destination);
        return;
      } on Object catch (error) {
        lastError = error;
        final bool retryable =
            error is! HashMismatchError && attempt < retries - 1;
        if (!retryable) break;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw lastError ?? HttpStatusError(request.url, 0);
  }

  void close() => _client.close();
}

class _Queue {
  _Queue(this._items);

  final List<DownloadRequest> _items;
  int _index = 0;

  DownloadRequest? next() => _index < _items.length ? _items[_index++] : null;
}

class HttpStatusError implements Exception {
  const HttpStatusError(this.url, this.statusCode);

  final String url;
  final int statusCode;

  @override
  String toString() => '下载失败（HTTP $statusCode）：$url';
}

class HashMismatchError implements Exception {
  const HashMismatchError(this.url, this.expected, this.actual);

  final String url;
  final String expected;
  final String actual;

  @override
  String toString() => 'SHA-1 校验失败：$url（期望 $expected，实际 $actual）';
}

/// Streams a file through SHA-1 without loading it into memory.
Future<String> sha1OfFile(String path) async {
  final _DigestCollector collector = _DigestCollector();
  await for (final List<int> chunk in File(path).openRead()) {
    collector.add(chunk);
  }
  return collector.finish();
}

class _DigestCollector {
  _DigestCollector() {
    _in = sha1.startChunkedConversion(_out);
  }

  final _DigestSink _out = _DigestSink();
  late final ByteConversionSink _in;

  void add(List<int> chunk) => _in.add(chunk);

  String finish() {
    _in.close();
    return _out.value.toString();
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
