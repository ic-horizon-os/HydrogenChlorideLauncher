import 'package:fluent_ui/fluent_ui.dart';

import '../../core/constants.dart';
import '../../state/app_state.dart';
import '../../theme/fluent_theme.dart';
import '../pages/about/about_dialog.dart';
import 'window_controls.dart';

/// Win11-style title bar. The HCL wordmark is the settings entry point.
class HclTitleBar extends StatelessWidget {
  const HclTitleBar({
    super.key,
    required this.app,
    required this.onOpenSettings,
  });

  final AppState app;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Container(
      height: FluentTokens.titleBarHeight,
      decoration: BoxDecoration(
        color: palette.background.withValues(
          alpha: palette.isDark ? 0.4 : 0.55,
        ),
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 4),
          _HclTitleButton(onTap: onOpenSettings),
          MenuBar(
            items: <MenuBarItem>[
              MenuBarItem(
                title: '窗口',
                items: <MenuFlyoutItemBase>[
                  MenuFlyoutItem(
                    text: const Text('最小化'),
                    leading: const Icon(FluentIcons.chrome_minimize),
                    onPressed: () {
                      WindowControls.minimize();
                    },
                  ),
                  MenuFlyoutItem(
                    text: const Text('最大化 / 还原'),
                    leading: const Icon(FluentIcons.chrome_restore),
                    onPressed: () {
                      WindowControls.toggleMaximize();
                    },
                  ),
                  const MenuFlyoutSeparator(),
                  MenuFlyoutItem(
                    text: const Text('关闭'),
                    leading: const Icon(FluentIcons.chrome_close),
                    onPressed: () {
                      WindowControls.close();
                    },
                  ),
                ],
              ),
              MenuBarItem(
                title: '关于',
                items: <MenuFlyoutItemBase>[
                  MenuFlyoutItem(
                    text: const Text('关于 Hydrogen Chloride Launcher'),
                    leading: const Icon(FluentIcons.info),
                    onPressed: () => showAboutHclDialog(context),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => WindowControls.startDragging(),
              onDoubleTap: WindowControls.toggleMaximize,
              child: const SizedBox.expand(),
            ),
          ),
          Text(
            'Alpha ${AppInfo.version}',
            style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
          ),
          const SizedBox(width: 8),
          _CaptionButton(
            icon: FluentIcons.chrome_minimize,
            tooltip: '最小化',
            onTap: WindowControls.minimize,
          ),
          _CaptionButton(
            icon: FluentIcons.chrome_restore,
            tooltip: '最大化 / 还原',
            onTap: WindowControls.toggleMaximize,
          ),
          _CaptionButton(
            icon: FluentIcons.chrome_close,
            tooltip: '关闭',
            onTap: WindowControls.close,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _HclTitleButton extends StatelessWidget {
  const _HclTitleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Tooltip(
      message: 'HCL 设置',
      child: HoverButton(
        cursor: SystemMouseCursors.click,
        onPressed: onTap,
        builder: (BuildContext context, Set<WidgetState> states) {
          final bool hovered = states.contains(WidgetState.hovered);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: hovered ? palette.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        palette.accent,
                        Color.lerp(palette.accent, Colors.black, 0.35)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    FluentIcons.developer_tools,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'HCL',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onTap;
  final bool destructive;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color hoverColor = widget.destructive
        ? const Color(0xFFC42B1C)
        : palette.hover;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 46,
            height: FluentTokens.titleBarHeight,
            color: _hovered ? hoverColor : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 12,
              color: _hovered && widget.destructive
                  ? Colors.white
                  : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
