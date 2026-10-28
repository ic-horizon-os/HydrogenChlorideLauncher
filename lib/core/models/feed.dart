import '../utils/json_utils.dart';

class FeedSource {
  FeedSource({
    required this.id,
    required this.title,
    required this.url,
    required this.siteUrl,
    required this.description,
    required this.isFeed,
    this.isDemo = false,
  });

  factory FeedSource.fromJson(Map<String, dynamic> json) {
    return FeedSource(
      id: asString(json['id']),
      title: asString(json['title']),
      url: asString(json['url']),
      siteUrl: asString(json['siteUrl']),
      description: asString(json['description']),
      isFeed: asBool(json['isFeed'], true),
      isDemo: asBool(json['isDemo'], false),
    );
  }

  final String id;
  String title;
  String url;
  String siteUrl;
  String description;
  bool isFeed;
  bool isDemo;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'url': url,
    'siteUrl': siteUrl,
    'description': description,
    'isFeed': isFeed,
    'isDemo': isDemo,
  };
}

class FeedArticle {
  FeedArticle({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.author,
    required this.publishedAt,
    required this.summary,
    required this.content,
    this.isDemo = false,
    this.read = false,
    this.link = '',
  });

  factory FeedArticle.fromJson(Map<String, dynamic> json) {
    return FeedArticle(
      id: asString(json['id']),
      sourceId: asString(json['sourceId']),
      title: asString(json['title']),
      author: asString(json['author']),
      publishedAt: asDateTime(json['publishedAt']) ?? DateTime.now(),
      summary: asString(json['summary']),
      content: asString(json['content']),
      isDemo: asBool(json['isDemo'], false),
      read: asBool(json['read'], false),
      link: asString(json['link']),
    );
  }

  final String id;
  final String sourceId;
  final String title;
  final String author;
  final DateTime publishedAt;
  final String summary;
  final String content;
  final bool isDemo;
  bool read;

  /// Original article URL; empty for demo and placeholder entries.
  String link;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sourceId': sourceId,
    'title': title,
    'author': author,
    'publishedAt': publishedAt.toIso8601String(),
    'summary': summary,
    'content': content,
    'isDemo': isDemo,
    'read': read,
    'link': link,
  };
}
