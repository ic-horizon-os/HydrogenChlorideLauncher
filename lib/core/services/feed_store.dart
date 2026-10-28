import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_paths.dart';
import '../config/json_store.dart';
import '../demo/demo_data.dart';
import '../minecraft/download_manager.dart';
import '../models/feed.dart';
import 'feed_parser.dart';

/// Subscriptions shown in 社区. Sources added by the user are fetched as
/// RSS/Atom; demo sources stay local and the merged set is persisted to
/// `feeds.json`.
class FeedStore extends ChangeNotifier {
  FeedStore(
    this.paths, {
    JsonStore? jsonStore,
    FeedParser? parser,
    this.fetch,
    DownloadManager? downloader,
  }) : _json = jsonStore ?? const JsonStore(),
       _parser = parser ?? const FeedParser(),
       _downloader = downloader ?? DownloadManager();

  final AppPaths paths;
  final JsonStore _json;
  final FeedParser _parser;
  final Future<String> Function(String url)? fetch;
  final DownloadManager _downloader;
  final List<FeedSource> _sources = <FeedSource>[];
  final List<FeedArticle> _articles = <FeedArticle>[];
  final Map<String, String> _errors = <String, String>{};
  bool _refreshing = false;

  List<FeedSource> get sources => List<FeedSource>.unmodifiable(_sources);
  List<FeedArticle> get articles => List<FeedArticle>.unmodifiable(_articles);
  bool get refreshing => _refreshing;

  String? errorFor(String sourceId) => _errors[sourceId];

  /// Adds the built-in sample sources and articles.
  Future<void> addDemoSources() async {
    final Set<String> existing = _sources.map((FeedSource s) => s.id).toSet();
    _sources.addAll(
      DemoData.buildFeedSources().where(
        (FeedSource s) => !existing.contains(s.id),
      ),
    );
    final Set<String> articleIds = _articles
        .map((FeedArticle a) => a.id)
        .toSet();
    _articles.addAll(
      DemoData.buildFeedArticles().where(
        (FeedArticle a) => !articleIds.contains(a.id),
      ),
    );
    notifyListeners();
    await save();
  }

  Future<void> removeDemoSources() async {
    final int before = _sources.length + _articles.length;
    _sources.removeWhere((FeedSource s) => s.isDemo);
    _articles.removeWhere((FeedArticle a) => a.isDemo);
    if (_sources.length + _articles.length == before) return;
    notifyListeners();
    await save();
  }

  Future<void> load() async {
    final Map<String, dynamic>? map = await _json.readMap(paths.feedsFile);
    if (map == null) {
      notifyListeners();
      return;
    }
    _sources
      ..clear()
      ..addAll(
        (map['sources'] is List ? map['sources'] as List : const <Object?>[])
            .whereType<Map>()
            .map(
              (Map item) => FeedSource.fromJson(
                item.map(
                  (Object? key, Object? value) => MapEntry('$key', value),
                ),
              ),
            ),
      );
    _articles
      ..clear()
      ..addAll(
        (map['articles'] is List ? map['articles'] as List : const <Object?>[])
            .whereType<Map>()
            .map(
              (Map item) => FeedArticle.fromJson(
                item.map(
                  (Object? key, Object? value) => MapEntry('$key', value),
                ),
              ),
            ),
      );
    notifyListeners();
  }

  List<FeedSource> visibleSources(bool includeDemo) {
    return _sources
        .where((FeedSource source) => includeDemo || !source.isDemo)
        .toList(growable: false);
  }

  List<FeedArticle> articlesFor(String sourceId, {required bool includeDemo}) {
    return _articles
        .where(
          (FeedArticle article) =>
              article.sourceId == sourceId && (includeDemo || !article.isDemo),
        )
        .toList(growable: false)
      ..sort(
        (FeedArticle a, FeedArticle b) =>
            b.publishedAt.compareTo(a.publishedAt),
      );
  }

  int unreadFor(String sourceId, {required bool includeDemo}) {
    return articlesFor(
      sourceId,
      includeDemo: includeDemo,
    ).where((FeedArticle article) => !article.read).length;
  }

  /// Adds a subscription and immediately tries to fetch it. A fetch failure
  /// is remembered per source and shown in the UI; the source is kept either
  /// way so the address is not lost.
  Future<FeedSource> addSource({
    required String title,
    required String url,
    required bool isFeed,
  }) async {
    final String normalizedUrl = url.trim();
    final String host = Uri.tryParse(normalizedUrl)?.host ?? 'local';
    final FeedSource source = FeedSource(
      id: 'user-feed-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? host : title.trim(),
      url: normalizedUrl,
      siteUrl: normalizedUrl,
      description: isFeed ? 'RSS / Atom 订阅' : '站点',
      isFeed: isFeed,
    );
    _sources.add(source);
    notifyListeners();
    if (isFeed && normalizedUrl.isNotEmpty) {
      await refresh(source.id);
    }
    await save();
    return source;
  }

  Future<void> removeSource(String sourceId) async {
    _sources.removeWhere((FeedSource source) => source.id == sourceId);
    _articles.removeWhere(
      (FeedArticle article) => article.sourceId == sourceId,
    );
    _errors.remove(sourceId);
    notifyListeners();
    await save();
  }

  /// Refreshes one source, or every non-demo feed when [sourceId] is null.
  Future<void> refresh([String? sourceId]) async {
    if (_refreshing) return;
    final List<FeedSource> targets = _sources
        .where(
          (FeedSource source) =>
              source.isFeed &&
              !source.isDemo &&
              (sourceId == null || source.id == sourceId),
        )
        .toList(growable: false);
    if (targets.isEmpty) return;
    _refreshing = true;
    notifyListeners();
    for (final FeedSource source in targets) {
      await _refreshOne(source);
    }
    _refreshing = false;
    notifyListeners();
    await save();
  }

  Future<void> _refreshOne(FeedSource source) async {
    try {
      final String body =
          await (fetch?.call(source.url) ?? _defaultFetch(source.url));
      final List<FeedArticle>? parsed = _parser.parse(
        body,
        sourceId: source.id,
      );
      if (parsed == null) {
        _errors[source.id] = '不是可识别的 RSS/Atom 内容。';
        return;
      }
      final String? feedTitle = _parser.titleOf(body);
      if (feedTitle != null &&
          (source.title == Uri.tryParse(source.url)?.host ||
              source.title.isEmpty)) {
        source.title = feedTitle;
      }
      source.description = 'RSS / Atom 订阅 · ${parsed.length} 篇文章';
      _mergeArticles(source, parsed);
      _errors.remove(source.id);
    } on Object catch (error) {
      _errors[source.id] = '抓取失败：$error';
    }
  }

  /// Keeps read state for articles already seen and caps the article list so
  /// feeds.json does not grow without bound.
  void _mergeArticles(FeedSource source, List<FeedArticle> fetched) {
    final Map<String, FeedArticle> existing = <String, FeedArticle>{
      for (final FeedArticle article in _articles)
        if (article.sourceId == source.id) article.id: article,
    };
    for (final FeedArticle article in fetched) {
      final FeedArticle? previous = existing[article.id];
      if (previous != null && previous.read) {
        article.read = true;
      }
      existing[article.id] = article;
    }
    final List<FeedArticle> merged = existing.values.toList()
      ..sort(
        (FeedArticle a, FeedArticle b) =>
            b.publishedAt.compareTo(a.publishedAt),
      );
    _articles.removeWhere(
      (FeedArticle article) => article.sourceId == source.id,
    );
    _articles.addAll(merged.take(100));
  }

  Future<String> _defaultFetch(String url) async {
    final List<int> bytes = await _downloader.fetchBytes(url);
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> markRead(String articleId) async {
    for (final FeedArticle article in _articles) {
      if (article.id == articleId) {
        article.read = true;
      }
    }
    notifyListeners();
    await save();
  }

  Future<void> markAllRead(String sourceId) async {
    for (final FeedArticle article in _articles) {
      if (article.sourceId == sourceId) {
        article.read = true;
      }
    }
    notifyListeners();
    await save();
  }

  Future<void> save() {
    return _json.write(paths.feedsFile, <String, dynamic>{
      'sources': _sources.map((FeedSource source) => source.toJson()).toList(),
      'articles': _articles
          .map((FeedArticle article) => article.toJson())
          .toList(),
    });
  }
}
