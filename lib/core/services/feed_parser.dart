import 'package:xml/xml.dart';

import '../models/feed.dart';

/// Parses RSS 2.0, RSS 1.0 (RDF) and Atom feeds into [FeedArticle]s.
class FeedParser {
  const FeedParser();

  static final RegExp _tag = RegExp('<[^>]+>');
  static final RegExp _spaces = RegExp(r'\s+');

  /// Returns null when the document is not a recognisable feed.
  List<FeedArticle>? parse(String xml, {required String sourceId}) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException {
      return null;
    }
    final XmlElement? channel = document.findAllElements('channel').firstOrNull;
    if (channel != null) return _parseRss(channel, sourceId);
    final XmlElement? feed = document.findAllElements('feed').firstOrNull;
    if (feed != null && feed.name.local == 'feed') {
      return _parseAtom(feed, sourceId);
    }
    return null;
  }

  /// Extracts the feed title so a user-added URL gets a sensible name.
  String? titleOf(String xml) {
    try {
      final XmlDocument document = XmlDocument.parse(xml);
      for (final String tag in <String>['channel', 'feed']) {
        final XmlElement? root = document.findAllElements(tag).firstOrNull;
        final XmlElement? title = root?.findElements('title').firstOrNull;
        if (title != null && title.innerText.trim().isNotEmpty) {
          return title.innerText.trim();
        }
      }
    } on XmlException {
      return null;
    }
    return null;
  }

  List<FeedArticle> _parseRss(XmlElement channel, String sourceId) {
    final List<FeedArticle> articles = <FeedArticle>[];
    for (final XmlElement item in channel.findElements('item')) {
      final String title = _text(item, 'title');
      final String link = _text(item, 'link');
      final String linkFromGuid = _isPermaLink(item)
          ? _text(item, 'guid')
          : link;
      final String description = _text(item, 'description');
      final String content = _text(item, 'encoded');
      final String date = _text(item, 'pubDate') + _text(item, 'date');
      articles.add(
        FeedArticle(
          id: _articleId(sourceId, _text(item, 'guid'), link),
          sourceId: sourceId,
          title: title,
          author: _text(item, 'creator') + _text(item, 'author'),
          publishedAt: _parseDate(date) ?? DateTime.now(),
          summary: _stripHtml(description),
          content: _readable(content.isEmpty ? description : content),
          read: false,
        )..link = linkFromGuid.isEmpty ? link : linkFromGuid,
      );
    }
    return articles;
  }

  List<FeedArticle> _parseAtom(XmlElement feed, String sourceId) {
    final String feedTitle = _text(feed, 'title');
    final List<FeedArticle> articles = <FeedArticle>[];
    for (final XmlElement entry in feed.findElements('entry')) {
      String link = '';
      for (final XmlElement candidate in entry.findElements('link')) {
        final String rel = candidate.getAttribute('rel') ?? 'alternate';
        if (rel == 'alternate' || link.isEmpty) {
          link = candidate.getAttribute('href') ?? '';
          if (rel == 'alternate') break;
        }
      }
      final String summary = _text(entry, 'summary');
      final String content = _text(entry, 'content');
      final String date = _text(entry, 'updated') + _text(entry, 'published');
      articles.add(
        FeedArticle(
          id: _articleId(sourceId, _text(entry, 'id'), link),
          sourceId: sourceId,
          title: _text(entry, 'title'),
          author: _authorOf(entry, fallback: feedTitle),
          publishedAt: _parseDate(date) ?? DateTime.now(),
          summary: _stripHtml(summary.isEmpty ? content : summary),
          content: _readable(content.isEmpty ? summary : content),
          read: false,
        )..link = link,
      );
    }
    return articles;
  }

  XmlElement? _firstByLocal(XmlElement parent, String name) {
    for (final XmlElement child in parent.childElements) {
      if (child.name.local == name) return child;
    }
    return null;
  }

  String _text(XmlElement parent, String localName) {
    // Namespaced children (content:encoded, dc:creator) surface with their
    // prefix in `name.local` on some parsers; compare the suffix too.
    for (final XmlElement child in parent.childElements) {
      if (child.name.local == localName ||
          child.name.qualified.endsWith(':$localName')) {
        final String value = child.innerText.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  String _authorOf(XmlElement entry, {required String fallback}) {
    final XmlElement? author = _firstByLocal(entry, 'author');
    if (author == null) return fallback;
    final String name = _text(author, 'name');
    if (name.isNotEmpty) return name;
    final String text = author.innerText.trim();
    return text.isEmpty ? fallback : text;
  }

  bool _isPermaLink(XmlElement item) {
    final XmlElement? guid = _firstByLocal(item, 'guid');
    return guid?.getAttribute('isPermaLink') != 'false';
  }

  static String _articleId(String sourceId, String guid, String link) {
    final String seed = guid.isNotEmpty ? guid : link;
    final String hash = seed.hashCode.toRadixString(16);
    return '$sourceId-$hash';
  }

  static DateTime? _parseDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;
    final DateTime? iso = DateTime.tryParse(value);
    if (iso != null) return iso.toLocal();
    // RFC 822: "Tue, 03 Jun 2008 09:56:00 GMT"
    final Match? match = RegExp(
      r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(value);
    if (match == null) return null;
    const Map<String, int> months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final int month = months[match.group(2)!.toLowerCase()] ?? 1;
    final DateTime parsed = DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
    );
    return parsed.toLocal();
  }

  static String _stripHtml(String value) {
    final String text = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(_tag, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text.replaceAll(_spaces, ' ').trim();
  }

  /// Keeps paragraph structure the reader splits on, and drops markup.
  static String _readable(String value) {
    final String spaced = value
        .replaceAll(
          RegExp(r'</(p|div|h\d|li|br|blockquote)>', caseSensitive: false),
          '\n\n',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    final String byLine = spaced.split('\n').map(_stripHtml).join('\n');
    final List<String> paragraphs = byLine
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    return paragraphs.join('\n\n');
  }
}
