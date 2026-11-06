import 'dart:ui' show ImageFilter;

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../core/services/app_task.dart';
import '../../theme/fluent_theme.dart';

enum FluentButtonStyle { primary, secondary, ghost, danger }

class FluentButton extends StatelessWidget {
  const FluentButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = FluentButtonStyle.secondary,
    this.loading = false,
    this.dense = false,
    this.minWidth,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final FluentButtonStyle style;
  final bool loading;
  final bool dense;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final bool disabled = onPressed == null || loading;
    final EdgeInsetsGeometry padding = EdgeInsetsDirectional.symmetric(
      horizontal: dense ? 10 : 14,
      vertical: dense ? 5 : 7,
    );
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          const SizedBox(
            width: 13,
            height: 13,
            child: ProgressRing(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: dense ? 12 : 14),
        if (loading || icon != null) const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: dense ? 11.5 : 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final ButtonStyle buttonStyle = ButtonStyle(
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      backgroundColor: switch (style) {
        FluentButtonStyle.primary => null,
        FluentButtonStyle.secondary => null,
        FluentButtonStyle.ghost => const WidgetStatePropertyAll<Color?>(
          Colors.transparent,
        ),
        FluentButtonStyle.danger => WidgetStatePropertyAll<Color?>(
          palette.danger.withValues(alpha: 0.12),
        ),
      },
      foregroundColor: style == FluentButtonStyle.danger
          ? WidgetStatePropertyAll<Color?>(palette.danger)
          : null,
    );

    final Widget button = style == FluentButtonStyle.primary
        ? FilledButton(
            onPressed: disabled ? null : onPressed,
            style: buttonStyle,
            child: content,
          )
        : Button(
            onPressed: disabled ? null : onPressed,
            style: buttonStyle,
            child: content,
          );

    if (minWidth == null) return button;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth!),
      child: button,
    );
  }
}

class FluentIconButton extends StatelessWidget {
  const FluentIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 30,
    this.iconSize = 14,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          icon: Icon(
            icon,
            size: iconSize,
            color: selected ? palette.accent : palette.textSecondary,
          ),
          onPressed: onPressed,
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsetsDirectional.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class MetaPill extends StatelessWidget {
  const MetaPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color foreground = color ?? palette.textSecondary;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 10 : 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.typography.subtitle),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(description!, style: theme.typography.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final FluentThemeData theme = FluentTheme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: palette.subtleFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Icon(icon, size: 22, color: palette.textTertiary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.typography.subtitle,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.typography.body?.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Snack-bar style toast rendered through the overlay.
void showAppMessage(BuildContext context, String message) {
  final OverlayState overlay = Overlay.of(context);
  final FluentPalette palette = FluentColors.of(context).palette;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => Positioned(
      left: 0,
      right: 0,
      bottom: 28,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(FluentTokens.radius),
              border: Border.all(color: palette.border),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(color: palette.textPrimary, fontSize: 12),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 3), entry.remove);
}

/// Modal content dialog. Returns the value passed to `Navigator.pop`.
Future<T?> showFluentDialog<T>({
  required BuildContext context,
  required String title,
  String? description,
  required Widget child,
  List<Widget> actions = const <Widget>[],
  double width = 560,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      final Size size = MediaQuery.sizeOf(context);
      return ContentDialog(
        title: Text(title),
        constraints: BoxConstraints(minWidth: width, maxWidth: width),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (size.height - 220).clamp(240, 720),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (description != null) ...<Widget>[
                  Text(
                    description,
                    style: TextStyle(
                      color: FluentColors.of(context).palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                child,
              ],
            ),
          ),
        ),
        actions: actions.isEmpty
            ? <Widget>[
                Button(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ]
            : actions,
      );
    },
  );
}

/// Yes/no confirmation. Returns true only when the user confirms.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final Color danger = FluentColors.of(context).palette.danger;
  final bool? result = await showFluentDialog<bool>(
    context: context,
    title: title,
    child: Text(
      message,
      style: TextStyle(
        color: FluentColors.of(context).palette.textSecondary,
        fontSize: 12.5,
        height: 1.6,
      ),
    ),
    actions: <Widget>[
      Button(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(cancelLabel),
      ),
      FilledButton(
        style: destructive
            ? ButtonStyle(
                backgroundColor: WidgetStatePropertyAll<Color>(danger),
              )
            : null,
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(confirmLabel),
      ),
    ],
  );
  return result ?? false;
}

/// A Windows 11 navigation row: rounded highlight plus a full-height accent
/// bar on the leading edge. fluent_ui's `ListTile.selectable` pins that bar to
/// 70% of the tile height minus padding, which reads as a short stub.
class NavListTile extends StatefulWidget {
  const NavListTile({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showIndicator = true,
  });

  final bool selected;
  final VoidCallback onPressed;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// False when a parent draws one shared sliding bar for the whole list.
  final bool showIndicator;

  @override
  State<NavListTile> createState() => _NavListTileState();
}

class _NavListTileState extends State<NavListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color accent = FluentTheme.of(context).accentColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withValues(alpha: 0.10)
                : _hovered
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 4),
              // Windows 11 uses a short bar centred on the row, a bit taller
              // than the icon; it never stretches with the row height.
              SizedBox(
                width: 3,
                height: 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: widget.selected && widget.showIndicator
                        ? accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (widget.leading != null) ...<Widget>[
                widget.leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12.5,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                widget.trailing!,
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stage list rendered the way PCL shows an install: the current phase on top,
/// a determinate bar, and the file or count being worked on underneath.
class InstallStageProgress extends StatelessWidget {
  const InstallStageProgress({
    super.key,
    required this.stage,
    required this.detail,
    required this.fraction,
  });

  final String stage;
  final String detail;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 14,
              height: 14,
              child: ProgressRing(strokeWidth: 2, activeColor: palette.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                stage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(fraction.clamp(0, 1) * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(value: fraction <= 0 ? null : fraction.clamp(0, 1)),
        if (detail.isNotEmpty) ...<Widget>[
          const SizedBox(height: 7),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
          ),
        ],
      ],
    );
  }
}

/// A vertical list whose selection bar slides between rows, the way Windows 11
/// settings animates its left navigation.
///
/// Each row reports its box through the embedded [IndicatorAnchor]; the
/// shared bar is drawn once for the whole list.
class SlidingNavList extends StatefulWidget {
  const SlidingNavList({
    super.key,
    required this.itemCount,
    required this.selectedIndex,
    required this.itemBuilder,
  });

  final int itemCount;
  final int selectedIndex;
  final Widget Function(BuildContext context, int index, Key anchorKey)
  itemBuilder;

  @override
  State<SlidingNavList> createState() => _SlidingNavListState();
}

class _SlidingNavListState extends State<SlidingNavList>
    with SingleTickerProviderStateMixin {
  late final PageStorageBucket _bucket = PageStorageBucket();
  late final List<GlobalKey> _keys = List<GlobalKey>.generate(
    widget.itemCount,
    (_) => GlobalKey(),
  );

  /// Wraps the list itself so row offsets are measured in the same space.
  final GlobalKey _listKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  int _previous = 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.selectedIndex;
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant SlidingNavList old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _previous = old.selectedIndex;
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

  /// Vertical centre of row [index] inside the list's own coordinate space.
  double? _centerOf(int index) {
    if (index < 0 || index >= _keys.length) return null;
    final RenderObject? row = _keys[index].currentContext?.findRenderObject();
    final RenderObject? list = _listKey.currentContext?.findRenderObject();
    if (row is! RenderBox || !row.hasSize || !row.attached) return null;
    if (list is! RenderBox || !list.hasSize) return null;
    try {
      final Offset origin = row.localToGlobal(Offset.zero, ancestor: list);
      return origin.dy + row.size.height / 2;
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = FluentTheme.of(context).accentColor;
    return Stack(
      children: <Widget>[
        PageStorage(
          bucket: _bucket,
          child: ListView.builder(
            key: _listKey,
            padding: EdgeInsets.zero,
            itemCount: widget.itemCount,
            itemBuilder: (BuildContext context, int index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: widget.itemBuilder(context, index, _keys[index]),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _curve,
              builder: (BuildContext context, Widget? child) {
                final double? to = _centerOf(widget.selectedIndex);
                if (to == null) return const SizedBox.shrink();
                final double? from = _centerOf(_previous);
                final double t = _controller.isAnimating ? _curve.value : 1;
                final double centerY = from == null
                    ? to
                    : from + (to - from) * t;
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: 4,
                      top: centerY - 8,
                      width: 3,
                      height: 16,
                      child: child!,
                    ),
                  ],
                );
              },
              child: DecoratedBox(
                key: const ValueKey<String>('sidebar-selection-indicator'),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Marks a row inside [SlidingNavList] so its position can be measured.
class IndicatorAnchor extends StatelessWidget {
  const IndicatorAnchor({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Two-column version picker: the left column lists version families
/// ("1.21", "1.20" …) and the right one lists the exact releases in the
/// chosen family. Used instead of a long flat dropdown.
class VersionPicker extends StatefulWidget {
  const VersionPicker({
    super.key,
    required this.versions,
    required this.selected,
    required this.onSelected,
    this.subtitleOf,
    this.height = 260,
  });

  /// Version ids, newest first.
  final List<String> versions;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? Function(String version)? subtitleOf;
  final double height;

  /// "1.21.1" -> "1.21"; snapshots keep their whole id as the family.
  static String familyOf(String id) {
    final Match? match = RegExp(r'^(\d+)\.(\d+)').firstMatch(id);
    return match == null ? id : '${match.group(1)}.${match.group(2)}';
  }

  @override
  State<VersionPicker> createState() => _VersionPickerState();
}

class _VersionPickerState extends State<VersionPicker> {
  late String _family = VersionPicker.familyOf(
    widget.selected ?? (widget.versions.isEmpty ? '' : widget.versions.first),
  );

  @override
  void didUpdateWidget(covariant VersionPicker old) {
    super.didUpdateWidget(old);
    final String? selected = widget.selected;
    if (selected != null && VersionPicker.familyOf(selected) != _family) {
      _family = VersionPicker.familyOf(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<String> families = <String>[];
    for (final String version in widget.versions) {
      final String family = VersionPicker.familyOf(version);
      if (!families.contains(family)) families.add(family);
    }
    final List<String> members = widget.versions
        .where((String v) => VersionPicker.familyOf(v) == _family)
        .toList(growable: false);

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Card(
              padding: const EdgeInsets.all(4),
              margin: EdgeInsets.zero,
              child: ListView.builder(
                itemCount: families.length,
                itemBuilder: (BuildContext context, int index) {
                  final String family = families[index];
                  final bool active = family == _family;
                  return _PickerRow(
                    active: active,
                    label: family,
                    onTap: () => setState(() => _family = family),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              padding: const EdgeInsets.all(4),
              margin: EdgeInsets.zero,
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        '没有版本',
                        style: TextStyle(
                          color: palette.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String version = members[index];
                        final String? subtitle = widget.subtitleOf?.call(
                          version,
                        );
                        return _PickerRow(
                          active: version == widget.selected,
                          label: version,
                          subtitle: subtitle,
                          onTap: () => widget.onSelected(version),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatefulWidget {
  const _PickerRow({
    required this.active,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final bool active;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  State<_PickerRow> createState() => _PickerRowState();
}

class _PickerRowState extends State<_PickerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color accent = FluentTheme.of(context).accentColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: widget.active
                ? accent.withValues(alpha: 0.10)
                : _hovered
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textTertiary, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Steam-style download bar pinned above the window edge: one compact strip
/// with the task name, its current stage and a progress fill. It cannot be
/// expanded to a full-screen manager.
class BottomTaskBar extends StatelessWidget {
  const BottomTaskBar({super.key, required this.task, required this.onDismiss});

  final AppTask task;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // The task updates itself up to ~20×/s; listening here keeps those
    // ticks from rebuilding the whole shell.
    return ListenableBuilder(
      listenable: task,
      builder: (BuildContext context, Widget? _) {
        return _build(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color accent = FluentTheme.of(context).accentColor;
    final bool done = !task.running;
    final Color barColor = task.error != null ? palette.danger : accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FluentTokens.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(FluentTokens.radius),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      task.error != null
                          ? Icons.error_outline
                          : done
                          ? Icons.check_circle_outline
                          : Icons.downloading,
                      size: 14,
                      color: barColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.error ??
                            (done
                                ? '完成'
                                : [
                                    task.stage,
                                    if (task.detail.isNotEmpty) task.detail,
                                  ].join(' · ')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: task.error != null
                              ? palette.danger
                              : palette.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!done)
                      Text(
                        '${(task.fraction * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    FluentIconButton(
                      icon: Icons.close,
                      size: 26,
                      iconSize: 10,
                      tooltip: '关闭',
                      onPressed: onDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressBar(
                  value: done && task.error == null ? 1 : task.fraction,
                  activeColor: barColor,
                  backgroundColor: palette.border,
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Windows 11 page layout: the header stays exactly where it is while the body
/// rises into place from below and fades in.
///
/// Pages use this instead of putting the title inside their scrollable
/// content, so tab switches never move the header.
class FluentPage extends StatelessWidget {
  const FluentPage({
    super.key,
    required this.header,
    required this.body,
    this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 0),
  });

  final Widget header;
  final Widget body;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          const SizedBox(height: 16),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Slides [child] up from a small offset and fades it in. Applied to page
/// bodies only, never to headers.
///
/// fluent_ui keeps visited tab bodies alive offstage, so without help the
/// entrance would play exactly once per session. Wrapped in a navigation
/// shell that provides a [PageEntranceSignal], the entrance restarts every
/// time the page becomes active.
class PageBodyEntrance extends StatefulWidget {
  const PageBodyEntrance({
    super.key,
    required this.child,
    this.offset = 0.06,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;

  /// Fraction of the body height to travel; a larger value reads as a slide
  /// rather than a fade.
  final double offset;
  final Duration duration;

  @override
  State<PageBodyEntrance> createState() => _PageBodyEntranceState();
}

class _PageBodyEntranceState extends State<PageBodyEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  /// The shell transition this page is bound to, if any.
  Animation<double>? _shell;
  double _lastShellValue = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? shell = PageEntranceSignal.read(context);
    if (identical(shell, _shell)) return;
    _shell?.removeListener(_handleShellTick);
    _shell = shell;
    _lastShellValue = shell?.value ?? 1;
    shell?.addListener(_handleShellTick);
  }

  /// The shell restarts its transition (the value snaps back toward zero)
  /// every time its tab is re-activated; replay the entrance in step with it.
  void _handleShellTick() {
    final double value = _shell?.value ?? 1;
    final bool restarted = value < _lastShellValue - 0.05;
    _lastShellValue = value;
    if (restarted && !_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shell?.removeListener(_handleShellTick);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The boundary caches the body's display list across the ~320ms of fade
    // frames, so each frame re-composites one cached layer instead of
    // re-recording (and repainting) the whole page.
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.offset),
          end: Offset.zero,
        ).animate(_curve),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// Handed down by the navigation shell so [PageBodyEntrance] can replay its
/// entrance on every activation. The shell itself renders the child
/// unchanged — headers stay still while bodies animate.
class PageEntranceSignal extends InheritedWidget {
  const PageEntranceSignal({
    super.key,
    required this.animation,
    required super.child,
  });

  /// Restarts (runs 0 -> 1) each time the owning page becomes active.
  final Animation<double> animation;

  /// Read without registering a dependency: the animation object is held
  /// directly and watched with a listener instead.
  static Animation<double>? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PageEntranceSignal>()?.animation;

  @override
  bool updateShouldNotify(PageEntranceSignal oldWidget) => false;
}
