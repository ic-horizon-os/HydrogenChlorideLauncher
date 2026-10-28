import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/minecraft/loader_installer.dart';
import '../../../core/minecraft/version_manifest.dart';
import '../../../core/models/app_entry.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/java_runtime.dart';
import '../../../core/services/platform_actions.dart';
import '../../../core/services/version_isolation.dart';
import '../../../core/utils/format.dart';
import '../../../state/app_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';
import 'library_panels.dart';

enum LibraryDetailTab { overview, loader, mods, worlds, skins, crashes }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FlyoutController _flyoutController = FlyoutController();
  LibraryDetailTab _detailTab = LibraryDetailTab.overview;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final List<AppEntry> entries = app.visibleEntries;
    final AppEntry? selected = app.selectedEntry;

    return FlyoutTarget(
      controller: _flyoutController,
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        header: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 4),
          child: PageHeader(
            title: const Text('库'),
            commandBar: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (app.installModules.supportsVanilla)
                  FluentButton(
                    label: '安装版本',
                    icon: FluentIcons.download,
                    dense: true,
                    style: FluentButtonStyle.primary,
                    onPressed: () => _installVersion(context, app),
                  ),

                const SizedBox(width: 8),
                FluentButton(
                  label: '添加自定义程序',
                  icon: FluentIcons.add,
                  dense: true,
                  onPressed: () => _addCustomApp(context, app),
                ),
                const SizedBox(width: 8),
                FluentButton(
                  label: '打开 .minecraft',
                  icon: FluentIcons.folder,
                  dense: true,
                  onPressed: () {
                    final String? path = app.settings.minecraftDirs.isEmpty
                        ? null
                        : app.settings.minecraftDirs.first;
                    if (path == null) {
                      showAppMessage(context, '尚未配置 Minecraft 目录。');
                    } else {
                      PlatformActions.openDirectory(path);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        content: PageBodyEntrance(
          child: entries.isEmpty
              ? EmptyState(
                  icon: FluentIcons.game,
                  title: '还没有游戏或程序',
                  message: '点右上角「安装版本」下载 Minecraft，或添加自定义程序。',
                  action: FluentButton(
                    label: '安装版本',
                    icon: FluentIcons.download,
                    style: FluentButtonStyle.primary,
                    onPressed: () => _installVersion(context, app),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 320,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          8,
                          16,
                          18,
                        ),
                        child: Card(
                          padding: const EdgeInsets.all(6),
                          margin: EdgeInsets.zero,
                          child: SlidingNavList(
                            itemCount: entries.length,
                            selectedIndex: entries.indexWhere(
                              (AppEntry e) => e.id == selected?.id,
                            ),
                            itemBuilder:
                                (BuildContext context, int index, Key key) {
                                  final AppEntry entry = entries[index];
                                  return GestureDetector(
                                    key: key,
                                    onSecondaryTapDown:
                                        (TapDownDetails details) =>
                                            _showEntryMenu(
                                              context,
                                              app,
                                              entry,
                                              details.globalPosition,
                                            ),
                                    child: NavListTile(
                                      selected: entry.id == selected?.id,
                                      showIndicator: false,
                                      onPressed: () =>
                                          app.selectLibraryEntry(entry.id),
                                      leading: _AppIcon(entry: entry),
                                      title: entry.name,
                                      subtitle: entry.subtitle.isEmpty
                                          ? _kindLabel(entry.kind)
                                          : entry.subtitle,
                                      trailing: app.launcher.isRunning(entry.id)
                                          ? MetaPill(
                                              label: formatClock(
                                                app.launcher.elapsed,
                                              ),
                                              color: FluentColors.of(context)
                                                  .palette
                                                  .success,
                                              dense: true,
                                            )
                                          : null,
                                    ),
                                  );
                                },
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: selected == null
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _DetailTabBar(
                                  selected: _detailTab,
                                  onSelected: (LibraryDetailTab tab) =>
                                      setState(() => _detailTab = tab),
                                ),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder:
                                        (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.01),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                    child: _detailContent(selected, app),
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

  Widget _detailContent(AppEntry entry, AppState app) {
    final ValueKey<String> key = ValueKey<String>(
      '${entry.id}-${_detailTab.name}',
    );
    switch (_detailTab) {
      case LibraryDetailTab.overview:
        return _InstanceHero(
          key: key,
          entry: entry,
          app: app,
          onContextMenu: (Offset position) =>
              _showEntryMenu(context, app, entry, position),
        );
      case LibraryDetailTab.loader:
        return LoaderPanel(key: key, entry: entry, app: app);
      case LibraryDetailTab.mods:
        return ModsPanel(key: key, entry: entry, app: app);
      case LibraryDetailTab.worlds:
        return WorldsPanel(key: key, entry: entry, app: app);
      case LibraryDetailTab.skins:
        return SkinsPanel(key: key, app: app);
      case LibraryDetailTab.crashes:
        return CrashPanel(key: key, entry: entry, app: app);
    }
  }

  void _openDetailTab(AppEntry entry, AppState app, LibraryDetailTab tab) {
    app.selectLibraryEntry(entry.id);
    setState(() => _detailTab = tab);
  }

  Future<void> _addCustomApp(BuildContext context, AppState app) async {
    final AppEntry? entry = await showFluentDialog<AppEntry>(
      context: context,
      title: '添加自定义程序',
      description: '保存条目并模拟启动与计时。',
      width: 620,
      child: const _AddAppForm(),
    );
    if (entry == null) return;
    await app.addEntry(entry);
    if (context.mounted) showAppMessage(context, '已添加“${entry.name}”。');
  }

  Future<void> _installVersion(BuildContext context, AppState app) async {
    await showFluentDialog<void>(
      context: context,
      title: '安装 Minecraft 版本',
      description: '从 Mojang 下载版本 JSON、客户端、库文件与资源。',
      width: 620,
      child: _InstallVersionForm(app: app),
    );
    if (context.mounted) await app.scanVersions();
  }

  void _showEntryMenu(
    BuildContext context,
    AppState app,
    AppEntry entry,
    Offset position,
  ) {
    final bool running = app.launcher.isRunning(entry.id);
    _flyoutController.showFlyout<void>(
      position: position,
      builder: (BuildContext flyoutContext) {
        return MenuFlyout(
          items: <MenuFlyoutItemBase>[
            MenuFlyoutItem(
              text: Text(running ? '停止' : '启动'),
              leading: Icon(running ? FluentIcons.stop : FluentIcons.play),
              onPressed: () => running ? app.stopActive() : app.launch(entry),
            ),
            MenuFlyoutItem(
              text: const Text('打开安装目录'),
              leading: const Icon(FluentIcons.folder),
              onPressed: () => _openFolder(context, app, entry),
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: const Text('Java 设置'),
              leading: const Icon(FluentIcons.code),
              onPressed: () =>
                  _editInstanceSettings(context, app, entry, javaTab: true),
            ),
            MenuFlyoutItem(
              text: const Text('JVM 设置'),
              leading: const Icon(FluentIcons.settings),
              onPressed: () =>
                  _editInstanceSettings(context, app, entry, javaTab: false),
            ),
            MenuFlyoutSubItem(
              text: const Text('管理'),
              leading: const Icon(FluentIcons.settings),
              items: (BuildContext menuContext) => <MenuFlyoutItemBase>[
                MenuFlyoutItem(
                  text: const Text('安装加载器'),
                  leading: const Icon(FluentIcons.download),
                  onPressed: () =>
                      _openDetailTab(entry, app, LibraryDetailTab.loader),
                ),
                MenuFlyoutItem(
                  text: const Text('模组管理'),
                  leading: const Icon(FluentIcons.puzzle),
                  onPressed: () =>
                      _openDetailTab(entry, app, LibraryDetailTab.mods),
                ),
                MenuFlyoutItem(
                  text: const Text('世界管理'),
                  leading: const Icon(FluentIcons.globe),
                  onPressed: () =>
                      _openDetailTab(entry, app, LibraryDetailTab.worlds),
                ),
                MenuFlyoutItem(
                  text: const Text('皮肤'),
                  leading: const Icon(FluentIcons.photo),
                  onPressed: () =>
                      _openDetailTab(entry, app, LibraryDetailTab.skins),
                ),
                MenuFlyoutItem(
                  text: const Text('崩溃分析'),
                  leading: const Icon(FluentIcons.warning),
                  onPressed: () =>
                      _openDetailTab(entry, app, LibraryDetailTab.crashes),
                ),
              ],
            ),
            MenuFlyoutItem(
              text: const Text('属性'),
              leading: const Icon(FluentIcons.info),
              onPressed: () => showFluentDialog<void>(
                context: context,
                title: entry.name,
                width: 560,
                child: _Properties(entry: entry, settings: app.settings),
              ),
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: const Text('从库中移除'),
              leading: const Icon(FluentIcons.delete),
              onPressed: running
                  ? null
                  : () => _removeEntry(context, app, entry),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFolder(
    BuildContext context,
    AppState app,
    AppEntry entry,
  ) async {
    final String? path =
        entry.workingDir ??
        (entry.executablePath == null
            ? null
            : File(entry.executablePath!).parent.path) ??
        (app.settings.minecraftDirs.isEmpty
            ? null
            : app.settings.minecraftDirs.first);
    if (path == null) {
      showAppMessage(context, '该条目没有可打开的目录。');
    } else if (!Directory(path).existsSync()) {
      showAppMessage(context, '目录不存在：$path');
    } else {
      PlatformActions.openDirectory(path);
    }
  }

  Future<void> _removeEntry(
    BuildContext context,
    AppState app,
    AppEntry entry,
  ) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '从库中移除',
      message: '将从库中移除“${entry.name}”。不会删除游戏文件或程序本身。',
      confirmLabel: '移除',
      destructive: true,
    );
    if (confirmed) await app.removeEntry(entry.id);
  }

  Future<void> _editInstanceSettings(
    BuildContext context,
    AppState app,
    AppEntry entry, {
    required bool javaTab,
  }) async {
    final AppEntry? updated = await showFluentDialog<AppEntry>(
      context: context,
      title: '${entry.name} · ${javaTab ? 'Java 设置' : 'JVM 设置'}',
      description: '覆盖启动器默认值，仅对该条目生效。',
      width: 660,
      child: _InstanceSettingsForm(
        entry: entry,
        app: app,
        initialJavaTab: javaTab,
      ),
    );
    if (updated == null) return;
    await app.updateEntry(updated);
    if (context.mounted) {
      showAppMessage(context, '已保存“${entry.name}”的启动设置。');
    }
  }

  static String _kindLabel(AppKind kind) {
    switch (kind) {
      case AppKind.minecraft:
        return 'Minecraft 原版';
      case AppKind.modpack:
        return '整合包';
      case AppKind.custom:
        return '自定义程序';
      case AppKind.utility:
        return '实用软件';
    }
  }
}

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({required this.selected, required this.onSelected});

  final LibraryDetailTab selected;
  final ValueChanged<LibraryDetailTab> onSelected;

  static const Map<LibraryDetailTab, String> _labels =
      <LibraryDetailTab, String>{
        LibraryDetailTab.overview: '概览',
        LibraryDetailTab.loader: '加载器',
        LibraryDetailTab.mods: '模组',
        LibraryDetailTab.worlds: '世界',
        LibraryDetailTab.skins: '皮肤',
        LibraryDetailTab.crashes: '崩溃分析',
      };

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: palette.background.withValues(
          alpha: palette.isDark ? 0.24 : 0.5,
        ),
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        child: Row(
          children: LibraryDetailTab.values
              .map((LibraryDetailTab tab) {
                final bool active = tab == selected;
                return GestureDetector(
                  key: ValueKey<String>('detail-tab-${tab.name}'),
                  onTap: () => onSelected(tab),
                  child: Container(
                    margin: const EdgeInsetsDirectional.symmetric(
                      horizontal: 4,
                    ),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active ? palette.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _labels[tab]!,
                      style: TextStyle(
                        color: active
                            ? palette.textPrimary
                            : palette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _InstanceHero extends StatelessWidget {
  const _InstanceHero({
    super.key,
    required this.entry,
    required this.app,
    required this.onContextMenu,
  });

  final AppEntry entry;
  final AppState app;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    final bool running = app.launcher.isRunning(entry.id);
    final bool starting = app.launcher.isStarting;
    return GestureDetector(
      onSecondaryTapDown: (TapDownDetails details) =>
          onContextMenu(details.globalPosition),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _HeroBackdrop(
            entry: entry,
            settings: app.settings,
            coverPath: app.covers.cachedPath,
          ),
          Positioned(
            top: 16,
            left: 24,
            child: Row(
              children: <Widget>[
                if (entry.isMinecraft)
                  MetaPill(
                    label: entry.loader ?? 'Vanilla',
                    icon: FluentIcons.puzzle,
                    dense: true,
                  ),
                if (entry.isolated) ...<Widget>[
                  const SizedBox(width: 8),
                  const MetaPill(
                    label: '版本隔离',
                    icon: FluentIcons.folder,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Acrylic(
              tint: Colors.black,
              tintAlpha: 0.48,
              blurAmount: 32,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(28, 22, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: <Widget>[
                        _HeroStat(
                          icon: FluentIcons.clock,
                          label: '总时长',
                          value: formatPlaytime(entry.totalPlayMs),
                        ),
                        _HeroStat(
                          icon: FluentIcons.history,
                          label: '最后启动',
                          value: formatRelativeTime(entry.lastPlayed),
                        ),
                        _HeroStat(
                          icon: FluentIcons.settings,
                          label: '内存',
                          value:
                              '${entry.memoryMbOverride ?? app.settings.defaultMemoryMb} MB',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        FilledButton(
                          onPressed: starting
                              ? null
                              : () async {
                                  if (running) {
                                    await app.stopActive();
                                  } else {
                                    await app.launch(entry);
                                  }
                                },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (starting && !running)
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: ProgressRing(strokeWidth: 2),
                                )
                              else
                                Icon(
                                  running ? FluentIcons.stop : FluentIcons.play,
                                  size: 14,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                running
                                    ? '停止'
                                    : starting
                                    ? '启动中…'
                                    : '启动',
                              ),
                            ],
                          ),
                        ),
                        if (entry.isMinecraft) ...<Widget>[
                          const SizedBox(width: 12),
                          // Isolation toggle sits next to 启动 so it is
                          // discoverable without digging into the menu.
                          Tooltip(
                            message: entry.isolated
                                ? '版本隔离已开启：模组与存档在 versions/<版本>/ 下'
                                : '开启版本隔离，让模组与存档只属于这个版本',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '隔离',
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: entry.isolated ? 0.9 : 0.55,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ToggleSwitch(
                                  checked: entry.isolated,
                                  onChanged: (bool value) async {
                                    await app.updateEntry(
                                      entry.copyWith(isolated: value),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (starting || running) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 280,
                        child: ProgressBar(
                          value: starting
                              ? (app.launchFraction > 0
                                    ? app.launchFraction
                                    : null)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        starting
                            ? (app.launchStage ?? '启动中…')
                            : '运行 ${formatPlaytime(app.launcher.elapsed.inMilliseconds)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (entry.description.isNotEmpty)
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      running ? '停止后写入会话记录。' : '右键打开条目菜单。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 10.5,
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.66)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({
    required this.entry,
    required this.settings,
    this.coverPath,
  });

  final AppEntry entry;
  final AppSettings settings;

  /// Official Minecraft key art downloaded by [CoverArtService].
  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final Color base = Color(entry.iconColorValue);
    if (entry.kind == AppKind.utility) {
      return const ColoredBox(color: Colors.black);
    }
    if (entry.kind == AppKind.modpack) {
      final String? image = settings.backgroundImagePath;
      if (image != null && File(image).existsSync()) {
        return Image.file(
          File(image),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stack,
          ) => _gradientWithWatermark(base),
        );
      }
      return _gradientWithWatermark(base);
    }
    if (entry.kind == AppKind.minecraft) {
      final String? cover = coverPath;
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (cover != null && File(cover).existsSync())
            _OfficialCover(path: cover)
          else
            _bannerArt(const Color(0xFF2F6B3C), entry.id.hashCode),
          Positioned(
            right: -20,
            bottom: 180,
            child: Text(
              entry.minecraftVersion ?? 'Minecraft',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 150,
                fontWeight: FontWeight.w800,
                letterSpacing: -6,
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'MINECRAFT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                ),
                Text(
                  'JAVA EDITION · ${entry.minecraftVersion ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.16),
                    fontSize: 11,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return _gradientWithWatermark(base);
  }

  Widget _bannerArt(Color base, int seed) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CustomPaint(
          painter: _BannerArtPainter(base: base, seed: seed),
        ),
        Positioned(
          right: -34,
          top: 60,
          child: Icon(
            FluentIcons.all_apps,
            size: 360,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }

  Widget _gradientWithWatermark(Color base) {
    return _bannerArt(base, entry.id.hashCode);
  }
}

/// Full-bleed official key art with a dark scrim so the hero text on top of it
/// stays readable.
class _OfficialCover extends StatelessWidget {
  const _OfficialCover({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.file(
          File(path),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.medium,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stack,
          ) => const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66000000),
                Color(0x00000000),
                Color(0x99000000),
                Color(0xF2000000),
              ],
              stops: <double>[0, 0.28, 0.62, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.entry});

  final AppEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color base = Color(entry.iconColorValue);
    final String initial = entry.name.isEmpty
        ? '?'
        : entry.name.substring(0, 1).toUpperCase();
    return SizedBox(
      width: 34,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[base, Color.lerp(base, Colors.black, 0.42)!],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: entry.isMinecraft
              ? const Icon(FluentIcons.game, color: Colors.white, size: 16)
              : Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Properties extends StatelessWidget {
  const _Properties({required this.entry, required this.settings});

  final AppEntry entry;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      ('条目 ID', entry.id),
      ('类型', entry.kind.name),
      ('副标题', entry.subtitle),
      ('Minecraft 版本', entry.minecraftVersion ?? '—'),
      ('加载器', entry.loader ?? '—'),
      ('可执行文件', entry.executablePath ?? '—'),
      ('工作目录', entry.workingDir ?? '—'),
      ('累计时长', formatPlaytime(entry.totalPlayMs)),
      ('最后启动', formatRelativeTime(entry.lastPlayed)),
      ('时长统计', entry.trackPlaytime ? '启用' : '关闭'),
      ('版本隔离', entry.isolated ? '启用' : '关闭'),
      (
        '隔离目录',
        entry.isolated
            ? VersionIsolation.gameDir(entry, AppSettings.defaults())
            : '—',
      ),
      ('Java 覆盖', entry.javaPathOverride ?? '跟随默认'),
      (
        '内存覆盖',
        entry.memoryMbOverride == null
            ? '跟随默认'
            : '${entry.memoryMbOverride} MB',
      ),
      ('JVM 参数覆盖', entry.jvmArgsOverride ?? '跟随默认'),
      ('数据来源', entry.isDemo ? '演示条目' : '用户添加'),
    ];
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      children: rows
          .map(
            ((String, String) row) => Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.$2,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AddAppForm extends StatefulWidget {
  const _AddAppForm();

  @override
  State<_AddAppForm> createState() => _AddAppFormState();
}

class _AddAppFormState extends State<_AddAppForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _executable = TextEditingController();
  final TextEditingController _workingDir = TextEditingController();
  final TextEditingController _arguments = TextEditingController();
  bool _track = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _executable.dispose();
    _workingDir.dispose();
    _arguments.dispose();
    super.dispose();
  }

  Future<void> _pickExecutable() async {
    final XFile? file = await openFile();
    if (file == null) return;
    setState(() {
      _executable.text = file.path;
      if (_name.text.isEmpty) _name.text = file.name;
    });
  }

  Future<void> _pickWorkingDir() async {
    final String? directory = await getDirectoryPath();
    if (directory == null) return;
    setState(() => _workingDir.text = directory);
  }

  void _save() {
    final String name = _name.text.trim();
    final String executable = _executable.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写程序名称。');
      return;
    }
    if (executable.isEmpty) {
      setState(() => _error = '请选择可执行文件。');
      return;
    }
    Navigator.of(context).pop(
      AppEntry(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        subtitle: '自定义程序',
        description: _arguments.text.trim().isEmpty
            ? '通过“添加自定义程序”加入库中的条目。'
            : '启动参数：${_arguments.text.trim()}',
        kind: AppKind.custom,
        executablePath: executable,
        workingDir: _workingDir.text.trim().isEmpty
            ? null
            : _workingDir.text.trim(),
        arguments: _arguments.text.trim().isEmpty
            ? null
            : _arguments.text.trim(),
        iconColorValue: 0xFF3B82F6,
        trackPlaytime: _track,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Field(
          label: '名称',
          child: TextBox(controller: _name, placeholder: '例如：Blockbench'),
        ),
        const SizedBox(height: 12),
        _Field(
          label: '可执行文件',
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextBox(
                  controller: _executable,
                  placeholder: '/usr/bin/程序 或 C:\\Program Files\\App\\app.exe',
                ),
              ),
              const SizedBox(width: 8),
              FluentButton(
                label: '浏览',
                dense: true,
                onPressed: _pickExecutable,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: '工作目录（可选）',
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextBox(
                  controller: _workingDir,
                  placeholder: '留空则使用可执行文件所在目录',
                ),
              ),
              const SizedBox(width: 8),
              FluentButton(
                label: '选择',
                dense: true,
                onPressed: _pickWorkingDir,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: '启动参数（可选）',
          child: TextBox(
            controller: _arguments,
            placeholder: '--example value',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            ToggleSwitch(
              checked: _track,
              onChanged: (bool value) => setState(() => _track = value),
            ),
            const SizedBox(width: 8),
            Text(
              '启用打开时长统计',
              style: TextStyle(color: palette.textPrimary, fontSize: 12),
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: palette.danger, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 18),
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
              icon: FluentIcons.add,
              style: FluentButtonStyle.primary,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}

class _InstanceSettingsForm extends StatefulWidget {
  const _InstanceSettingsForm({
    required this.entry,
    required this.app,
    required this.initialJavaTab,
  });

  final AppEntry entry;
  final AppState app;
  final bool initialJavaTab;

  @override
  State<_InstanceSettingsForm> createState() => _InstanceSettingsFormState();
}

class _InstanceSettingsFormState extends State<_InstanceSettingsForm> {
  late bool _javaTab = widget.initialJavaTab;
  late final TextEditingController _javaPath = TextEditingController(
    text: widget.entry.javaPathOverride ?? '',
  );
  late final TextEditingController _jvmArgs = TextEditingController(
    text: widget.entry.jvmArgsOverride ?? '',
  );
  late final TextEditingController _manualJava = TextEditingController();
  late int _memory =
      widget.entry.memoryMbOverride ?? widget.app.settings.defaultMemoryMb;
  late bool _track = widget.entry.trackPlaytime;
  late bool _isolated = widget.entry.isolated;

  @override
  void dispose() {
    _javaPath.dispose();
    _jvmArgs.dispose();
    _manualJava.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    await widget.app.scanJava();
    if (mounted) setState(() {});
  }

  void _save() {
    final String javaOverride = _javaPath.text.trim().isEmpty
        ? _manualJava.text.trim()
        : _javaPath.text.trim();
    Navigator.of(context).pop(
      widget.entry.copyWith(
        javaPathOverride: javaOverride.isEmpty ? null : javaOverride,
        memoryMbOverride: _memory,
        jvmArgsOverride: _jvmArgs.text.trim().isEmpty
            ? null
            : _jvmArgs.text.trim(),
        trackPlaytime: _track,
        // Isolation was togglable in the form but never persisted.
        isolated: _isolated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<JavaRuntime> runtimes = widget.app.javaRuntimes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _TabButton(
              label: 'Java 运行时',
              selected: _javaTab,
              onTap: () => setState(() => _javaTab = true),
            ),
            const SizedBox(width: 6),
            _TabButton(
              label: 'JVM / 内存',
              selected: !_javaTab,
              onTap: () => setState(() => _javaTab = false),
            ),
            const Spacer(),
            MetaPill(
              label: widget.app.javaBackend,
              icon: FluentIcons.code,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_javaTab) ...<Widget>[
          Text(
            '选择该条目使用的 Java。留空则跟随启动器默认值。',
            style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 210),
            child: widget.app.scanningJava
                ? const Center(child: ProgressRing(strokeWidth: 2))
                : runtimes.isEmpty
                ? Text(
                    '尚未发现 Java 运行时。可以点击“重新扫描”，'
                    '或手动填写 java 可执行文件路径。',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      ListTile.selectable(
                        selected: _javaPath.text.isEmpty,
                        onPressed: () => setState(() {
                          _javaPath.text = '';
                          _manualJava.text = '';
                        }),
                        title: const Text('跟随启动器默认值'),
                        subtitle: Text(
                          widget.app.settings.defaultJavaPath ?? '未设置默认 Java',
                        ),
                      ),
                      for (final JavaRuntime runtime in runtimes)
                        ListTile.selectable(
                          selected: _javaPath.text == runtime.path,
                          onPressed: () => setState(() {
                            _javaPath.text = runtime.path;
                            _manualJava.text = '';
                          }),
                          title: Text(runtime.label),
                          subtitle: Text(runtime.path),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              FluentButton(
                label: '重新扫描',
                icon: FluentIcons.refresh,
                dense: true,
                onPressed: widget.app.scanningJava ? null : _scan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: _manualJava,
                  placeholder: '手动输入 java 可执行文件路径',
                  onChanged: (String value) {
                    if (value.isNotEmpty) setState(() => _javaPath.text = '');
                  },
                ),
              ),
            ],
          ),
        ] else ...<Widget>[
          Row(
            children: <Widget>[
              Text('最大内存', style: TextStyle(color: palette.textSecondary)),
              const Spacer(),
              Text(
                '$_memory MB',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _memory.toDouble().clamp(1024, 16384).toDouble(),
            min: 1024,
            max: 16384,
            divisions: 30,
            onChanged: (double value) =>
                setState(() => _memory = (value / 512).round() * 512),
          ),
          const SizedBox(height: 8),
          Text('JVM 参数', style: TextStyle(color: palette.textSecondary)),
          const SizedBox(height: 6),
          TextBox(
            controller: _jvmArgs,
            placeholder: widget.app.settings.defaultJvmArgs,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              ToggleSwitch(
                checked: _track,
                onChanged: (bool value) => setState(() => _track = value),
              ),
              const SizedBox(width: 8),
              Text('为这个条目启用打开时长统计'),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Card(
          padding: const EdgeInsetsDirectional.all(12),
          margin: EdgeInsets.zero,
          backgroundColor: palette.surface,
          borderColor: palette.border,
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ToggleSwitch(
                    checked: _isolated,
                    onChanged: (bool value) =>
                        setState(() => _isolated = value),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '版本隔离',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'mods、config、saves 放在当前版本目录下。',
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isolated) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  VersionIsolation.gameDir(widget.entry, widget.app.settings),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              label: '保存',
              icon: FluentIcons.save,
              style: FluentButtonStyle.primary,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? palette.accent : palette.border),
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _BannerArtPainter extends CustomPainter {
  _BannerArtPainter({required this.base, required this.seed});

  final Color base;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final math.Random random = math.Random(seed);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(base, Colors.black, 0.58)!,
            base,
            Color.lerp(base, Colors.white, 0.14)!,
          ],
        ).createShader(rect),
    );

    final Paint glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.55, -0.8),
        radius: 0.9,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    for (int i = 0; i < 42; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height * 0.55,
        ),
        random.nextDouble() * 1.4 + 0.4,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.12 + random.nextDouble() * 0.2,
          ),
      );
    }

    final Path far = Path()
      ..moveTo(0, size.height * 0.72)
      ..lineTo(size.width * 0.14, size.height * 0.48)
      ..lineTo(size.width * 0.28, size.height * 0.66)
      ..lineTo(size.width * 0.44, size.height * 0.38)
      ..lineTo(size.width * 0.62, size.height * 0.67)
      ..lineTo(size.width * 0.78, size.height * 0.46)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      far,
      Paint()
        ..color = Color.lerp(base, Colors.black, 0.42)!.withValues(alpha: 0.7),
    );

    final Path near = Path()
      ..moveTo(0, size.height * 0.9)
      ..lineTo(size.width * 0.18, size.height * 0.63)
      ..lineTo(size.width * 0.36, size.height * 0.82)
      ..lineTo(size.width * 0.55, size.height * 0.58)
      ..lineTo(size.width * 0.74, size.height * 0.84)
      ..lineTo(size.width * 0.9, size.height * 0.68)
      ..lineTo(size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      near,
      Paint()
        ..color = Color.lerp(base, Colors.black, 0.62)!.withValues(alpha: 0.86),
    );

    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (int i = 0; i < 7; i++) {
      final double y = size.height - 12.0 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (int i = 0; i < 12; i++) {
      final double x = size.width * i / 11;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(size.width / 2 + (x - size.width / 2) * 0.3, size.height * 0.7),
        grid,
      );
    }

    for (int i = 0; i < 5; i++) {
      final double x = size.width * (0.66 + i * 0.055);
      final double y = size.height * (0.22 + random.nextDouble() * 0.28);
      final double s = 14 + random.nextDouble() * 22;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * 0.5 - 0.25);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s, height: s),
        Paint()..color = Colors.white.withValues(alpha: 0.055),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BannerArtPainter oldDelegate) {
    return oldDelegate.base != base || oldDelegate.seed != seed;
  }
}

/// Version picker with a live, stage-by-stage download readout.
class _InstallVersionForm extends StatefulWidget {
  const _InstallVersionForm({required this.app});

  final AppState app;

  @override
  State<_InstallVersionForm> createState() => _InstallVersionFormState();
}

class _InstallVersionFormState extends State<_InstallVersionForm> {
  static const Map<String, LoaderKind?> _loaders = <String, LoaderKind?>{
    '不安装加载器': null,
    'Fabric': LoaderKind.fabric,
    'Forge': LoaderKind.forge,
    'NeoForge': LoaderKind.neoforge,
  };

  String? _selected;
  bool _loading = true;
  String? _error;
  bool _installing = false;
  String _stage = '';
  String _detail = '';
  double _fraction = 0;

  String _loaderChoice = '不安装加载器';
  List<LoaderBuild> _builds = <LoaderBuild>[];
  String? _build;
  bool _loadingBuilds = false;
  String? _buildError;

  LoaderKind? get _loader => _loaders[_loaderChoice];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loader builds for the currently selected game version.
  Future<void> _loadBuilds() async {
    final LoaderKind? loader = _loader;
    final String? version = _selected;
    if (loader == null || version == null) {
      setState(() {
        _builds = <LoaderBuild>[];
        _build = null;
        _buildError = null;
        _loadingBuilds = false;
      });
      return;
    }
    setState(() {
      _loadingBuilds = true;
      _buildError = null;
      _builds = <LoaderBuild>[];
      _build = null;
    });
    try {
      final List<LoaderBuild> builds = await widget.app.loaderInstaller
          .listBuilds(loader, version);
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _builds = builds;
        _build = builds.isEmpty ? null : builds.first.loaderVersion;
        if (builds.isEmpty) _buildError = '该版本没有可用的 $loader 构建。';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _buildError = error.toString();
      });
    }
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final VersionManifest manifest = await widget.app.loadManifest(
        force: force,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _selected ??= manifest.latestRelease.isNotEmpty
            ? manifest.latestRelease
            : manifest.releases.firstOrNull?.id;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取版本清单失败：$error';
      });
    }
  }

  Future<void> _install() async {
    final String? version = _selected;
    if (version == null || _installing) return;
    setState(() {
      _installing = true;
      _stage = '准备';
      _detail = '';
      _fraction = 0;
    });
    final AppEntry? created = await widget.app.installVersion(
      version,
      onProgress: (String stage, double fraction, String detail) {
        if (!mounted) return;
        setState(() {
          // The loader install runs after vanilla; show it as a second phase.
          _stage = _loader == null ? stage : '原版 · $stage';
          _fraction = _loader == null ? fraction : fraction * 0.6;
          _detail = detail;
        });
      },
    );
    if (!mounted) return;
    if (created == null) {
      setState(() {
        _installing = false;
        _error = widget.app.lastError ?? '安装失败。';
      });
      return;
    }

    final LoaderKind? loader = _loader;
    final String? build = _build;
    if (loader != null && build != null) {
      final AppEntry? withLoader = await widget.app.installLoader(
        loader,
        version,
        build,
        onProgress: (String stage, double fraction, String detail) {
          if (!mounted) return;
          setState(() {
            _stage = '加载器 · $stage';
            _fraction = 0.6 + fraction * 0.4;
            _detail = detail;
          });
        },
      );
      if (!mounted) return;
      setState(() => _installing = false);
      if (withLoader == null) {
        setState(
          () => _error = '原版已安装，但加载器安装失败：${widget.app.lastError ?? '未知错误'}',
        );
        return;
      }
      Navigator.of(context).pop(withLoader);
      return;
    }

    setState(() => _installing = false);
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final VersionManifest? manifest = widget.app.manifest;
    final List<VersionManifestEntry> releases =
        manifest?.releases ?? const <VersionManifestEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_loading && manifest == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: ProgressRing(strokeWidth: 2)),
          )
        else
          VersionPicker(
            versions: releases
                .map((VersionManifestEntry entry) => entry.id)
                .toList(growable: false),
            selected: _selected,
            subtitleOf: (String id) {
              final VersionManifestEntry? entry = manifest?.find(id);
              return entry == null
                  ? null
                  : formatRelativeTime(entry.releaseTime);
            },
            onSelected: _installing
                ? (String _) {}
                : (String id) {
                    setState(() => _selected = id);
                    _loadBuilds();
                  },
          ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Text(
              '加载器',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: ComboBox<String>(
                value: _loaderChoice,
                isExpanded: true,
                items: _loaders.keys
                    .map(
                      (String name) =>
                          ComboBoxItem<String>(value: name, child: Text(name)),
                    )
                    .toList(growable: false),
                onChanged: _installing
                    ? null
                    : (String? value) {
                        if (value == null) return;
                        setState(() => _loaderChoice = value);
                        _loadBuilds();
                      },
              ),
            ),
          ],
        ),
        if (_loader != null) ...<Widget>[
          const SizedBox(height: 10),
          if (_loadingBuilds)
            Text(
              '正在获取加载器构建…',
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            )
          else if (_buildError != null)
            Text(
              _buildError!,
              style: TextStyle(color: palette.danger, fontSize: 11),
            )
          else
            VersionPicker(
              height: 130,
              versions: _builds
                  .map((LoaderBuild build) => build.loaderVersion)
                  .toList(growable: false),
              selected: _build,
              onSelected: _installing
                  ? (String _) {}
                  : (String value) => setState(() => _build = value),
            ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: palette.danger, fontSize: 11.5),
          ),
        ],
        if (_installing) ...<Widget>[
          const SizedBox(height: 16),
          InstallStageProgress(
            stage: _stage,
            detail: _detail,
            fraction: _fraction,
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Button(
                onPressed: _installing
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _installing || _selected == null ? null : _install,
                child: Text(_installing ? '安装中…' : '安装'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Loader picker with build selection and the same staged progress readout.
class _InstallLoaderForm extends StatefulWidget {
  const _InstallLoaderForm({required this.app});

  final AppState app;

  @override
  State<_InstallLoaderForm> createState() => _InstallLoaderFormState();
}

class _InstallLoaderFormState extends State<_InstallLoaderForm> {
  static const Map<String, LoaderKind> _kinds = <String, LoaderKind>{
    'Fabric': LoaderKind.fabric,
    'Forge': LoaderKind.forge,
    'NeoForge': LoaderKind.neoforge,
  };

  String _loader = 'Fabric';
  final TextEditingController _version = TextEditingController(text: '1.21.1');
  List<LoaderBuild> _builds = <LoaderBuild>[];
  String? _build;
  bool _loadingBuilds = false;
  String? _error;
  bool _installing = false;
  String _stage = '';
  String _detail = '';
  double _fraction = 0;

  LoaderKind get _kind => _kinds[_loader]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBuilds());
  }

  @override
  void dispose() {
    _version.dispose();
    super.dispose();
  }

  Future<void> _loadBuilds() async {
    setState(() {
      _loadingBuilds = true;
      _error = null;
      _builds = <LoaderBuild>[];
      _build = null;
    });
    try {
      final List<LoaderBuild> builds = await widget.app.loaderInstaller
          .listBuilds(_kind, _version.text.trim());
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _builds = builds;
        _build = builds.isEmpty ? null : builds.first.loaderVersion;
        if (builds.isEmpty) _error = '没有找到可用的构建。';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _install() async {
    final String? build = _build;
    if (build == null || _installing) return;
    setState(() {
      _installing = true;
      _stage = '准备';
      _detail = '';
      _fraction = 0;
    });
    final AppEntry? created = await widget.app.installLoader(
      _kind,
      _version.text.trim(),
      build,
      onProgress: (String stage, double fraction, String detail) {
        if (!mounted) return;
        setState(() {
          _stage = stage;
          _fraction = fraction;
          _detail = detail;
        });
      },
    );
    if (!mounted) return;
    setState(() => _installing = false);
    if (created == null) {
      setState(() => _error = widget.app.lastError ?? '安装失败。');
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ComboBox<String>(
                value: _loader,
                isExpanded: true,
                items: _kinds.keys
                    .map(
                      (String name) =>
                          ComboBoxItem<String>(value: name, child: Text(name)),
                    )
                    .toList(growable: false),
                onChanged: _installing
                    ? null
                    : (String? value) {
                        if (value == null) return;
                        setState(() => _loader = value);
                        _loadBuilds();
                      },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: TextBox(
                controller: _version,
                placeholder: '游戏版本',
                enabled: !_installing,
                onSubmitted: (_) => _loadBuilds(),
              ),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '获取构建',
              dense: true,
              loading: _loadingBuilds,
              onPressed: _installing ? null : _loadBuilds,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingBuilds)
          Text(
            '正在获取构建列表…',
            style: TextStyle(color: palette.textTertiary, fontSize: 11.5),
          )
        else
          VersionPicker(
            height: 180,
            versions: _builds
                .map((LoaderBuild build) => build.loaderVersion)
                .toList(growable: false),
            selected: _build,
            onSelected: _installing
                ? (String _) {}
                : (String value) => setState(() => _build = value),
          ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: palette.danger, fontSize: 11.5),
          ),
        ],
        if (_installing) ...<Widget>[
          const SizedBox(height: 16),
          InstallStageProgress(
            stage: _stage,
            detail: _detail,
            fraction: _fraction,
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Button(
                onPressed: _installing
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _installing || _build == null ? null : _install,
                child: Text(_installing ? '安装中…' : '安装'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
