import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../../../core/models/feed.dart';
import '../../../core/services/platform_actions.dart';
import '../../../core/utils/format.dart';
import '../../../state/app_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/acrylic_background.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<FeedSource> sources = app.visibleFeedSources;
    final FeedSource? source = app.selectedFeedSource;
    final List<FeedArticle> articles = app.currentArticles;
    final FeedArticle? article = app.selectedArticle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('社区', style: FluentTheme.of(context).typography.titleLarge),
              const Spacer(),
              FluentButton(
                label: '添加站点',
                icon: Icons.public,
                dense: true,
                onPressed: () => _addSource(context, app, isFeed: false),
              ),
              const SizedBox(width: 8),
              FluentButton(
                label: '添加订阅',
                icon: Icons.rss_feed,
                dense: true,
                onPressed: () => _addSource(context, app, isFeed: true),
              ),
              const SizedBox(width: 8),
              FluentButton(
                label: app.feeds.refreshing ? '刷新中…' : '刷新订阅',
                icon: Icons.refresh,
                dense: true,
                loading: app.feeds.refreshing,
                onPressed: app.feeds.refreshing
                    ? null
                    : () => app.refreshFeeds(
                        source?.isDemo == true ? null : source?.id,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            source == null
                ? '站点与 RSS/Atom 订阅，三栏阅读。'
                : '${source.title} · ${app.feeds.errorFor(source.id) ?? source.description}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: source == null || app.feeds.errorFor(source.id) == null
                  ? palette.textSecondary
                  : palette.warning,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: PageBodyEntrance(
              child: sources.isEmpty
                  ? EmptyState(
                      icon: Icons.rss_feed,
                      title: '还没有社区来源',
                      message: '添加一个站点或订阅链接，开始构建你的阅读列表。',
                      action: FluentButton(
                        label: '添加订阅',
                        icon: Icons.add,
                        style: FluentButtonStyle.primary,
                        onPressed: () => _addSource(context, app, isFeed: true),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: 230,
                          child: _SourceList(
                            sources: sources,
                            app: app,
                            selectedId: source?.id,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 310,
                          child: _ArticleList(
                            source: source,
                            articles: articles,
                            selectedId: article?.id,
                            app: app,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Reader(article: article, source: source),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _addSource(
    BuildContext context,
    AppState app, {
    required bool isFeed,
  }) async {
    await showFluentDialog<void>(
      context: context,
      title: isFeed ? '添加订阅源' : '添加站点',
      description: isFeed ? '填写 RSS 或 Atom 订阅地址，添加后会立即抓取。' : '添加一个常访问的站点。',
      width: 540,
      child: _AddSourceForm(app: app, isFeed: isFeed),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.sources,
    required this.app,
    required this.selectedId,
  });

  final List<FeedSource> sources;
  final AppState app;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return GlassPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: <Widget>[
                Text(
                  '来源',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sources.length}',
                  style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: sources.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 2),
              itemBuilder: (BuildContext context, int index) {
                final FeedSource source = sources[index];
                final int unread = app.feeds.unreadFor(
                  source.id,
                  includeDemo: app.settings.demoData,
                );
                final bool selected = source.id == selectedId;
                return _SourceTile(
                  source: source,
                  unread: unread,
                  selected: selected,
                  onTap: () => app.selectFeedSource(source.id),
                  onRemove: source.isDemo
                      ? null
                      : () => app.removeFeedSource(source.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatefulWidget {
  const _SourceTile({
    required this.source,
    required this.unread,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final FeedSource source;
  final int unread;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  State<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<_SourceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? palette.accent.withValues(alpha: 0.1)
                : _hovered
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  widget.source.isFeed ? Icons.rss_feed : Icons.public,
                  size: 13,
                  color: widget.selected
                      ? palette.accent
                      : palette.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.source.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 11.5,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.source.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onRemove != null && _hovered) ...<Widget>[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: palette.textTertiary,
                  ),
                ),
              ],
              if (widget.unread > 0) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.unread}',
                    style: TextStyle(
                      color: palette.accentForeground,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({
    required this.source,
    required this.articles,
    required this.selectedId,
    required this.app,
  });

  final FeedSource? source;
  final List<FeedArticle> articles;
  final String? selectedId;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return GlassPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    source?.title ?? '文章',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (source != null)
                  FluentButton(
                    label: '全部已读',
                    dense: true,
                    style: FluentButtonStyle.ghost,
                    onPressed: () => app.feeds.markAllRead(source!.id),
                  ),
              ],
            ),
          ),
          Expanded(
            child: articles.isEmpty
                ? Center(
                    child: Text(
                      '该来源下暂无文章',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: articles.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      final FeedArticle article = articles[index];
                      return _ArticleTile(
                        article: article,
                        selected: article.id == selectedId,
                        onTap: () => app.selectArticle(article.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArticleTile extends StatefulWidget {
  const _ArticleTile({
    required this.article,
    required this.selected,
    required this.onTap,
  });

  final FeedArticle article;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ArticleTile> createState() => _ArticleTileState();
}

class _ArticleTileState extends State<_ArticleTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final FeedArticle article = widget.article;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? palette.accent.withValues(alpha: 0.08)
                : _hovered
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: article.read ? Colors.transparent : palette.accent,
                  shape: BoxShape.circle,
                  border: article.read
                      ? Border.all(
                          color: palette.textTertiary.withValues(alpha: 0.4),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: article.read
                            ? palette.textSecondary
                            : palette.textPrimary,
                        fontSize: 11.5,
                        fontWeight: article.read
                            ? FontWeight.w500
                            : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${article.author} · ${formatRelativeTime(article.publishedAt)}',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  const _Reader({required this.article, required this.source});

  final FeedArticle? article;
  final FeedSource? source;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    if (article == null) {
      return GlassPanel(
        child: EmptyState(
          icon: Icons.article_outlined,
          title: '选择一篇文章',
          message: '从左侧文章列表中选择一篇，阅读面板会显示在这里。',
        ),
      );
    }
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Spacer(),
              FluentButton(
                label: '复制链接',
                icon: Icons.link,
                dense: true,
                style: FluentButtonStyle.ghost,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: article!.link.isNotEmpty
                          ? article!.link
                          : source?.url ?? '',
                    ),
                  );
                  showAppMessage(context, '已复制来源链接。');
                },
              ),
              const SizedBox(width: 6),
              FluentButton(
                label: '打开原文',
                icon: Icons.open_in_new,
                dense: true,
                onPressed: () {
                  final String url = article!.link.isNotEmpty
                      ? article!.link
                      : source?.siteUrl ?? '';
                  if (url.isNotEmpty) PlatformActions.openExternal(url);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      article!.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${article!.author} · ${formatDateTime(article!.publishedAt)} · '
                      '${source?.title ?? ''}',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(),
                    const SizedBox(height: 18),
                    for (final String paragraph in article!.content.split(
                      '\n\n',
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          paragraph,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13.5,
                            height: 1.85,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.subtleFill,
                        borderRadius: BorderRadius.circular(
                          FluentTokens.radius,
                        ),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        '当前显示本地示例文章。接入 RSS/Atom 后会显示真实内容。',
                        style: TextStyle(
                          color: palette.textTertiary,
                          fontSize: 10.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSourceForm extends StatefulWidget {
  const _AddSourceForm({required this.app, required this.isFeed});

  final AppState app;
  final bool isFeed;

  @override
  State<_AddSourceForm> createState() => _AddSourceFormState();
}

class _AddSourceFormState extends State<_AddSourceForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _url = TextEditingController();
  late bool _isFeed = widget.isFeed;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String url = _url.text.trim();
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      setState(() => _error = '请输入完整的 http(s) 地址。');
      return;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      setState(() => _error = '只支持 http 或 https 地址。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.app.addFeed(
      title: _title.text.trim(),
      url: url,
      isFeed: _isFeed,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _ModeButton(
              label: '站点',
              selected: !_isFeed,
              onTap: () => setState(() => _isFeed = false),
            ),
            const SizedBox(width: 8),
            _ModeButton(
              label: 'RSS / Atom 订阅',
              selected: _isFeed,
              onTap: () => setState(() => _isFeed = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '显示名称（可选）',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextBox(controller: _title, placeholder: '留空则使用域名'),
        const SizedBox(height: 14),
        Text(
          _isFeed ? '订阅地址' : '站点地址',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextBox(
          controller: _url,
          placeholder: _isFeed
              ? 'https://example.com/feed.xml'
              : 'https://example.com/',
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: palette.danger, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            FluentButton(
              label: '取消',
              style: FluentButtonStyle.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            FluentButton(
              label: '添加',
              icon: Icons.add,
              loading: _saving,
              style: FluentButtonStyle.primary,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          border: Border.all(
            color: selected
                ? palette.accent.withValues(alpha: 0.4)
                : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.accent : palette.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
