import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../core/models/app_entry.dart';
import '../../../core/models/browse_item.dart';
import '../../../core/services/browse_repository.dart';
import '../../../core/services/platform_actions.dart';
import '../../../core/utils/format.dart';
import '../../../state/app_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  BrowseCategory _category = BrowseCategory.mod;
  BrowseSort _sort = BrowseSort.popular;
  String _loader = '全部';
  String _search = '';

  List<BrowseItem> _online = <BrowseItem>[];
  bool _loading = false;
  bool _fetched = false;
  String? _error;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOnline());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOnline() async {
    final AppState app = AppScope.read(context);
    if (_category == BrowseCategory.loader) {
      setState(() {
        _online = <BrowseItem>[];
        _loading = false;
        _error = null;
      });
      return;
    }
    final int id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<BrowseItem> items = await app.searchModrinth(
        category: _category,
        query: _search,
        loader: _loader == '全部' ? null : _loader,
        sort: _sort,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _online = items;
        _loading = false;
        _fetched = true;
      });
    } on Object catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _online = <BrowseItem>[];
        _loading = false;
        _fetched = true;
        _error = '无法连接 Modrinth：$error';
      });
    }
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _fetchOnline);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<BrowseItem> demoItems = app.browse.query(
      category: _category,
      search: _search,
      loader: _loader == '全部' ? null : _loader,
      sort: _sort,
    );
    final bool showDemo =
        _category == BrowseCategory.loader ||
        (_online.isEmpty &&
            (_error != null || (_fetched && demoItems.isNotEmpty)));
    final List<BrowseItem> items = showDemo ? demoItems : _online;
    final List<String> loaders = <String>{
      ...app.browse.loadersFor(_category),
      ..._online.expand((BrowseItem item) => item.loaders),
    }.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          '浏览 Minecraft 内容',
                          style: FluentTheme.of(context).typography.titleLarge,
                        ),
                        const SizedBox(width: 10),
                        MetaPill(
                          label: showDemo ? '示例' : 'Modrinth',
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '模组、整合包、光影和加载器。',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 300,
                child: TextBox(
                  controller: _searchController,
                  placeholder: '搜索项目、作者或标签',
                  onChanged: (String value) {
                    setState(() => _search = value);
                    _scheduleFetch();
                  },
                  prefix: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 10),
                    child: Icon(
                      Icons.search,
                      size: 15,
                      color: palette.textTertiary,
                    ),
                  ),
                  suffix: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 12),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                            _scheduleFetch();
                          },
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                              EdgeInsetsDirectional.zero,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _CategoryBar(
            selected: _category,
            onSelected: (BrowseCategory category) {
              setState(() {
                _category = category;
                _loader = '全部';
              });
              _fetchOnline();
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                _category.description,
                style: TextStyle(color: palette.textTertiary, fontSize: 11.5),
              ),
              const Spacer(),
              if (_category != BrowseCategory.loader) ...<Widget>[
                _FilterButton(
                  label: '加载器',
                  value: _loader,
                  options: <String>['全部', ...loaders],
                  onSelected: (String value) {
                    setState(() => _loader = value);
                    _fetchOnline();
                  },
                ),
                const SizedBox(width: 8),
              ],
              _FilterButton(
                label: '排序',
                value: switch (_sort) {
                  BrowseSort.popular => '热门',
                  BrowseSort.recent => '最近更新',
                  BrowseSort.name => '名称',
                },
                options: const <String>['热门', '最近更新', '名称'],
                onSelected: (String value) {
                  setState(() {
                    _sort = switch (value) {
                      '最近更新' => BrowseSort.recent,
                      '名称' => BrowseSort.name,
                      _ => BrowseSort.popular,
                    };
                  });
                  _fetchOnline();
                },
              ),
            ],
          ),
          if (showDemo && _error != null && _category != BrowseCategory.loader)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 13,
                    color: palette.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '连不上 Modrinth，先显示内置示例。',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: PageBodyEntrance(
              child: _loading && !_fetched
                  ? const Center(child: ProgressRing(strokeWidth: 2))
                  : _error != null && _online.isEmpty && !showDemo
                  ? EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Modrinth 没有响应',
                      message: _error!,
                      action: FluentButton(
                        label: '重试',
                        icon: Icons.refresh,
                        onPressed: _fetchOnline,
                      ),
                    )
                  : items.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: '没有找到匹配的项目',
                      message: '换个关键词，或清除筛选条件。',
                      action: FluentButton(
                        label: '清除筛选',
                        icon: Icons.filter_alt_off_outlined,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _search = '';
                            _loader = '全部';
                          });
                          _fetchOnline();
                        },
                      ),
                    )
                  : LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final int columns = constraints.maxWidth >= 1180
                                ? 4
                                : constraints.maxWidth >= 900
                                ? 3
                                : 2;
                            return GridView.builder(
                              padding: const EdgeInsets.only(bottom: 12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 292,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                              itemCount: items.length,
                              itemBuilder: (BuildContext context, int index) {
                                return _ProjectCard(
                                  item: items[index],
                                  onTap: () =>
                                      _showProject(context, items[index]),
                                );
                              },
                            );
                          },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProject(BuildContext context, BrowseItem item) async {
    final AppState app = AppScope.read(context);
    if (item.category == BrowseCategory.loader) {
      await showFluentDialog<void>(
        context: context,
        title: item.name,
        description: '加载器 · ${item.author}',
        width: 720,
        child: _ProjectDetail(item: item),
        actions: <Widget>[
          FluentButton(
            label: '打开官网',
            icon: Icons.open_in_new,
            onPressed: () => PlatformActions.openExternal(_projectUrl(item)),
          ),
          FluentButton(
            label: '安装加载器',
            icon: Icons.build_outlined,
            style: FluentButtonStyle.primary,
            onPressed: () {
              Navigator.of(context).pop();
              app.openSettings(SettingsSection.versions);
            },
          ),
        ],
      );
      return;
    }
    final List<AppEntry> targets = app.visibleEntries
        .where((AppEntry entry) => entry.isMinecraft)
        .toList(growable: false);
    if (targets.isEmpty) {
      await showFluentDialog<void>(
        context: context,
        title: item.name,
        description: '${item.category.label} · ${item.author}',
        width: 720,
        child: _ProjectDetail(item: item),
        actions: <Widget>[
          FluentButton(
            label: '打开项目主页',
            icon: Icons.open_in_new,
            onPressed: () => PlatformActions.openExternal(_projectUrl(item)),
          ),
        ],
      );
      return;
    }
    final AppEntry initial = app.selectedEntry?.isMinecraft == true
        ? app.selectedEntry!
        : targets.first;
    await showFluentDialog<void>(
      context: context,
      title: item.name,
      description: '${item.category.label} · ${item.author}',
      width: 720,
      child: _ProjectDetail(item: item, targets: targets, initial: initial),
      actions: <Widget>[
        FluentButton(
          label: '打开项目主页',
          icon: Icons.open_in_new,
          onPressed: () => PlatformActions.openExternal(_projectUrl(item)),
        ),
      ],
    );
  }

  static String _projectUrl(BrowseItem item) {
    final String? slug = item.slug;
    if (slug != null && slug.isNotEmpty) {
      final String type = switch (item.category) {
        BrowseCategory.modpack => 'modpack',
        BrowseCategory.shader => 'shader',
        BrowseCategory.loader => 'mod',
        BrowseCategory.mod => 'mod',
      };
      return 'https://modrinth.com/$type/$slug';
    }
    switch (item.category) {
      case BrowseCategory.mod:
        return 'https://modrinth.com/mods?q=${Uri.encodeQueryComponent(item.name)}';
      case BrowseCategory.modpack:
        return 'https://modrinth.com/modpacks?q=${Uri.encodeQueryComponent(item.name)}';
      case BrowseCategory.shader:
        return 'https://modrinth.com/shaders?q=${Uri.encodeQueryComponent(item.name)}';
      case BrowseCategory.loader:
        switch (item.loaderId) {
          case 'fabric':
            return 'https://fabricmc.net/use/installer/';
          case 'forge':
            return 'https://files.minecraftforge.net/';
          case 'neoforge':
            return 'https://neoforged.net/';
          case 'optifine':
            return 'https://optifine.net/downloads';
        }
        return 'https://modrinth.com/';
    }
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final BrowseCategory selected;
  final ValueChanged<BrowseCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BrowseCategory.values
          .map((BrowseCategory category) {
            final bool active = category == selected;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelected(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? palette.accent.withValues(alpha: 0.14)
                        : palette.subtleFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? palette.accent.withValues(alpha: 0.45)
                          : palette.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _categoryIcon(category),
                        size: 14,
                        color: active ? palette.accent : palette.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        category.label,
                        style: TextStyle(
                          color: active
                              ? palette.textPrimary
                              : palette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  static IconData _categoryIcon(BrowseCategory category) {
    switch (category) {
      case BrowseCategory.mod:
        return Icons.extension_outlined;
      case BrowseCategory.modpack:
        return Icons.inventory_2_outlined;
      case BrowseCategory.shader:
        return Icons.auto_awesome_outlined;
      case BrowseCategory.loader:
        return Icons.build_circle_outlined;
    }
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label：',
          style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 132,
          child: ComboBox<String>(
            value: value,
            items: options
                .map(
                  (String option) =>
                      ComboBoxItem<String>(value: option, child: Text(option)),
                )
                .toList(growable: false),
            onChanged: (String? next) {
              if (next != null) onSelected(next);
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({required this.item, required this.onTap});

  final BrowseItem item;
  final VoidCallback onTap;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final BrowseItem item = widget.item;
    final Color start = Color(item.accentStartValue);
    final Color end = Color(item.accentEndValue);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.012 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Card(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 126,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[start, end],
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          right: -12,
                          bottom: -22,
                          child: Icon(
                            _iconFor(item.category),
                            size: 118,
                            color: Colors.white.withValues(alpha: 0.13),
                          ),
                        ),
                        if (item.iconUrl != null)
                          Positioned(
                            left: 12,
                            top: 34,
                            child: _ProjectIcon(url: item.iconUrl!, size: 44),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  MetaPill(
                                    label: item.category.label,
                                    dense: true,
                                    color: Colors.white,
                                  ),
                                  const Spacer(),
                                  if (item.featured)
                                    MetaPill(
                                      label: '精选',
                                      icon: Icons.star_rounded,
                                      dense: true,
                                      color: Colors.white,
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'by ${item.author}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.76),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: item.tags
                                .take(3)
                                .map(
                                  (String tag) =>
                                      MetaPill(label: tag, dense: true),
                                )
                                .toList(growable: false),
                          ),
                          const Spacer(),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.download_outlined,
                                size: 12,
                                color: palette.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatCount(item.downloads),
                                style: TextStyle(
                                  color: palette.textTertiary,
                                  fontSize: 10.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.loaders.take(2).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: palette.textTertiary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(BrowseCategory category) {
    switch (category) {
      case BrowseCategory.mod:
        return Icons.extension_outlined;
      case BrowseCategory.modpack:
        return Icons.inventory_2_outlined;
      case BrowseCategory.shader:
        return Icons.auto_awesome_outlined;
      case BrowseCategory.loader:
        return Icons.build_circle_outlined;
    }
  }
}

class _ProjectDetail extends StatefulWidget {
  const _ProjectDetail({
    required this.item,
    this.targets = const <AppEntry>[],
    this.initial,
  });

  final BrowseItem item;
  final List<AppEntry> targets;
  final AppEntry? initial;

  @override
  State<_ProjectDetail> createState() => _ProjectDetailState();
}

class _ProjectDetailState extends State<_ProjectDetail> {
  late AppEntry? _target = widget.initial;
  bool _installing = false;
  String _stage = '';
  double _fraction = 0;

  Future<void> _install() async {
    final AppEntry? target = _target;
    if (target == null || _installing) return;
    final AppState app = AppScope.read(context);
    setState(() {
      _installing = true;
      _stage = '查询版本';
      _fraction = 0;
    });
    final String? message = await app.installFromModrinth(
      item: widget.item,
      entry: target,
      onProgress: (String stage, double fraction) {
        if (!mounted) return;
        setState(() {
          _stage = stage;
          _fraction = fraction;
        });
      },
    );
    if (!mounted) return;
    setState(() => _installing = false);
    if (message != null) {
      showAppMessage(context, message);
      Navigator.of(context).pop();
    } else {
      showAppMessage(context, app.lastError ?? '安装失败。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final BrowseItem item = widget.item;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 132,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(item.accentStartValue),
                  Color(item.accentEndValue),
                ],
              ),
              borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
            ),
            child: Stack(
              children: <Widget>[
                if (item.iconUrl != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _ProjectIcon(url: item.iconUrl!, size: 64),
                  ),
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.category.label} · ${item.author}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              MetaPill(
                label: '${formatCount(item.downloads)} 次下载',
                icon: Icons.download_outlined,
              ),
              MetaPill(
                label: '${formatCount(item.followers)} 关注',
                icon: Icons.favorite_border,
              ),
              MetaPill(
                label: '更新于 ${formatRelativeTime(item.updatedAt)}',
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _DetailLabel(label: '支持的加载器'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.loaders
                          .map(
                            (String loader) =>
                                MetaPill(label: loader, dense: true),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _DetailLabel(label: '游戏版本'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.versions
                          .map(
                            (String version) => MetaPill(
                              label: version,
                              icon: Icons.tag,
                              dense: true,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.targets.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            const _DetailLabel(label: '安装到'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: palette.subtleFill,
                borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.videogame_asset_outlined,
                    size: 15,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ComboBox<AppEntry>(
                      value: _target,
                      isExpanded: true,
                      items: widget.targets
                          .map(
                            (AppEntry entry) => ComboBoxItem<AppEntry>(
                              value: entry,
                              child: Text(
                                '${entry.name} · '
                                '${entry.minecraftVersion ?? ''} '
                                '${entry.loader ?? 'Vanilla'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _installing
                          ? null
                          : (AppEntry? value) =>
                                setState(() => _target = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FluentButton(
                    label: _installing ? '安装中' : '安装',
                    icon: Icons.download_outlined,
                    style: FluentButtonStyle.primary,
                    loading: _installing,
                    onPressed: _installing ? null : _install,
                  ),
                ],
              ),
            ),
            if (_installing) ...<Widget>[
              const SizedBox(height: 10),
              ProgressBar(value: _fraction <= 0 ? null : _fraction),
              const SizedBox(height: 6),
              Text(
                _stage,
                style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            '文件来自 Modrinth，按实例的游戏版本与加载器自动选择最新兼容版本。',
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: 11,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        color: Colors.white.withValues(alpha: 0.14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            Icon(
              Icons.extension_outlined,
              size: size * 0.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? event,
        ) => event == null ? child : const SizedBox.shrink(),
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: FluentColors.of(context).palette.textTertiary,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}
