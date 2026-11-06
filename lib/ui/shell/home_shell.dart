import 'package:fluent_ui/fluent_ui.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/acrylic_background.dart';
import '../../theme/fluent_theme.dart';
import '../pages/account/account_page.dart';
import '../pages/browse/browse_page.dart';
import '../pages/community/community_page.dart';
import '../pages/library/library_page.dart';
import '../pages/settings/settings_page.dart';
import '../widgets/fluent_widgets.dart';
import 'title_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// One key per top tab so the shared selection pill can measure it.
  /// Hosts the navigation view and the sliding pill in one coordinate space.
  final GlobalKey _navStackKey = GlobalKey();

  final List<GlobalKey> _tabKeys = List<GlobalKey>.generate(
    HomeTab.values.length,
    (_) => GlobalKey(),
  );
  AppState? _app;
  String? _lastError;
  bool _settingsDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppState app = AppScope.of(context);
    if (!identical(app, _app)) {
      _app?.removeListener(_handleAppChanged);
      _app = app;
      app.addListener(_handleAppChanged);
    }
  }

  void _handleAppChanged() {
    final String? error = _app?.lastError;
    if (error == null) {
      _lastError = null;
    } else if (error != _lastError) {
      _lastError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppMessage(context, error);
        _app?.clearError();
      });
    }

    final AppState? app = _app;
    if (app == null || !app.settingsOpen || _settingsDialogOpen) return;
    _settingsDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _app == null) return;
      await showSettingsDialog(context, app);
      _settingsDialogOpen = false;
      if (mounted && (_app?.settingsOpen ?? false)) {
        _app!.closeSettings();
      }
    });
  }

  @override
  void dispose() {
    _app?.removeListener(_handleAppChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return AcrylicBackground(
      settings: app.settings,
      child: Stack(
        key: _navStackKey,
        children: <Widget>[
          NavigationView(
            titleBar: HclTitleBar(
              app: app,
              onOpenSettings: () => app.openSettings(),
            ),
            // Draw no shell-level transition: headers must stay exactly where
            // they are on tab switches. The animation object is handed down so
            // each page's PageBodyEntrance can replay on every activation.
            transitionBuilder: (Widget child, Animation<double> animation) =>
                PageEntranceSignal(animation: animation, child: child),
            // Tab switching has no shell-level animation: each page keeps its
            // header still and slides only its body in (see PageBodyEntrance).
            pane: NavigationPane(
              displayMode: PaneDisplayMode.top,
              selected: HomeTab.values.indexOf(app.tab),
              onChanged: (int index) => app.selectTab(HomeTab.values[index]),
              acrylicDisabled: true,
              indicator: const _HiddenIndicator(),
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FluentIconButton(
                      icon: FluentIcons.back,
                      tooltip: '后退',
                      size: 30,
                      iconSize: 12,
                      onPressed: app.canGoBack ? app.goBack : null,
                    ),
                    FluentIconButton(
                      icon: FluentIcons.forward,
                      tooltip: '前进',
                      size: 30,
                      iconSize: 12,
                      onPressed: app.canGoForward ? app.goForward : null,
                    ),
                  ],
                ),
              ),
              items: <PaneItem>[
                PaneItem(
                  title: const Text('浏览'),
                  contentBuilder: (
                    BuildContext context,
                    PaneItemContentData data,
                  ) => _tabContent(context, data, '浏览', anchorKey: _tabKeys[0]),
                  body: const BrowsePage(),
                ),
                PaneItem(
                  title: const Text('库'),
                  contentBuilder: (
                    BuildContext context,
                    PaneItemContentData data,
                  ) => _tabContent(context, data, '库', anchorKey: _tabKeys[1]),
                  body: const LibraryPage(),
                ),
                PaneItem(
                  title: const Text('社区'),
                  contentBuilder: (
                    BuildContext context,
                    PaneItemContentData data,
                  ) => _tabContent(context, data, '社区', anchorKey: _tabKeys[2]),
                  body: const CommunityPage(),
                ),
                PaneItem(
                  title: Text(app.accountDisplayName),
                  contentBuilder:
                      (BuildContext context, PaneItemContentData data) =>
                          _tabContent(
                            context,
                            data,
                            app.accountDisplayName,
                            anchorKey: _tabKeys[3],
                          ),
                  body: const AccountPage(),
                ),
              ],
            ),
          ),
          if (app.activeTask != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // Without a boundary, every progress refresh would dirty the
              // whole Stack and re-record the entire app display list.
              child: RepaintBoundary(
                child: BottomTaskBar(
                  task: app.activeTask!,
                  onDismiss: () => app.dismissTask(app.activeTask!),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              // Same: the pill repaints per frame while sliding; keep that
              // from re-recording the navigation view beneath it.
              child: RepaintBoundary(
                child: _SlidingNavPill(
                  key: const ValueKey<String>('nav-pill'),
                  tabKeys: _tabKeys,
                  selected: HomeTab.values.indexOf(app.tab),
                  hostKey: _navStackKey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws nothing: the animated selection pill is drawn once for the whole
/// navigation row by [_SlidingNavPill].
class _HiddenIndicator extends NavigationIndicator {
  const _HiddenIndicator();

  @override
  NavigationIndicatorState<_HiddenIndicator> createState() =>
      _HiddenIndicatorState();
}

class _HiddenIndicatorState extends NavigationIndicatorState<_HiddenIndicator> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A single pill that slides between top tabs, the way Windows 11 navigation
/// highlights move, instead of each item fading its own underline.
///
/// It lives in the same [Stack] as the navigation view, so every anchor key is
/// measured against that stack's coordinate space.
class _SlidingNavPill extends StatefulWidget {
  const _SlidingNavPill({
    super.key,
    required this.tabKeys,
    required this.selected,
    required this.hostKey,
  });

  final List<GlobalKey> tabKeys;
  final int selected;

  /// Key of the Stack that contains both the navigation view and this pill.
  final GlobalKey hostKey;

  @override
  State<_SlidingNavPill> createState() => _SlidingNavPillState();
}

class _SlidingNavPillState extends State<_SlidingNavPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  GlobalKey get _hostKey => widget.hostKey;

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  int _previous = 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.selected;
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _SlidingNavPill old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _previous = old.selected;
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Horizontal centre and bottom edge of a tab label, measured against the
  /// stack this pill is positioned in.
  ({double centerX, double bottom})? _anchor(int index) {
    if (index < 0 || index >= widget.tabKeys.length) return null;
    final RenderObject? box = widget.tabKeys[index].currentContext
        ?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    // The pill is laid out in the same Stack that hosts the navigation view,
    // so measuring against that Stack keeps positions aligned.
    final RenderObject? host = _hostKey.currentContext?.findRenderObject();
    if (host is! RenderBox) return null;
    Offset origin;
    try {
      origin = box.localToGlobal(Offset.zero, ancestor: host);
    } on Object {
      return null;
    }
    return (
      centerX: origin.dx + box.size.width / 2,
      bottom: origin.dy + box.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = FluentTheme.of(context).accentColor;
    return AnimatedBuilder(
      animation: _curve,
      // Anchors are re-resolved every frame so window resizes stay aligned.
      builder: (BuildContext context, Widget? _) {
        final ({double centerX, double bottom})? to = _anchor(widget.selected);
        if (to == null) return const SizedBox.shrink();
        final ({double centerX, double bottom})? from = _anchor(_previous);
        final double t = _controller.isAnimating ? _curve.value : 1;
        final double centerX = from == null
            ? to.centerX
            : from.centerX + (to.centerX - from.centerX) * t;
        return Stack(
          children: <Widget>[
            Positioned(
              left: centerX - 10,
              top: to.bottom - 4,
              width: 20,
              height: 3,
              child: DecoratedBox(
                key: const ValueKey<String>('nav-selection-indicator'),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _tabContent(
  BuildContext context,
  PaneItemContentData data,
  String label, {
  Key? anchorKey,
}) {
  final FluentPalette palette = FluentColors.of(context).palette;
  return Padding(
    key: anchorKey,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 9),
    child: Text(
      label,
      style: TextStyle(
        color: data.selected ? palette.textPrimary : palette.textSecondary,
        fontSize: 13,
        fontWeight: data.selected ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
  );
}
