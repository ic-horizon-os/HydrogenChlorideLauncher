import 'package:fluent_ui/fluent_ui.dart';

import '../../theme/fluent_theme.dart';

/// A drop-down that always opens below the anchor with a visible scrollbar
/// and a solid-white popup.
///
/// fluent's own [ComboBox] acrylics its flyout and centres the selected item
/// over the box, which makes long lists extend upwards; this control trades
/// that behaviour for the plain Win11 list flyout the app wants.
class HclComboBox<T> extends StatefulWidget {
  const HclComboBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = false,
    this.placeholder,
    this.maxPopupHeight = 320,
  });

  final T? value;
  final List<ComboBoxItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  /// Shown when [value] is null; mirrors ComboBox's placeholder.
  final Widget? placeholder;

  /// The popup opens below the box and scrolls beyond this height.
  final double maxPopupHeight;

  @override
  State<HclComboBox<T>> createState() => _HclComboBoxState<T>();
}

class _HclComboBoxState<T> extends State<HclComboBox<T>> {
  final FlyoutController _controller = FlyoutController();
  final GlobalKey _boxKey = GlobalKey();
  final ScrollController _popupScroll = ScrollController();
  bool _hovered = false;

  @override
  void dispose() {
    _controller.dispose();
    _popupScroll.dispose();
    super.dispose();
  }

  bool get _enabled =>
      widget.onChanged != null && widget.items.isNotEmpty;

  ComboBoxItem<T>? get _selected {
    for (final ComboBoxItem<T> item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  Future<void> _open() async {
    if (!_enabled || _controller.isOpen) return;
    final RenderBox? box =
        _boxKey.currentContext?.findRenderObject() as RenderBox?;
    final double width = box?.size.width ?? 200;
    await _controller.showFlyout<void>(
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      dismissWithEsc: true,
      placementMode: FlyoutPlacementMode.bottomLeft,
      additionalOffset: 4,
      builder: (BuildContext context) => FlyoutContent(
        useAcrylic: false,
        color: Colors.white,
        elevation: 8,
        padding: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        constraints: BoxConstraints.tightFor(width: width),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxPopupHeight),
          child: Scrollbar(
            controller: _popupScroll,
            thumbVisibility: true,
            child: ListView(
              controller: _popupScroll,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (final ComboBoxItem<T> item in widget.items)
                  _PopupRow<T>(
                    item: item,
                    selected: item.value == widget.value,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onChanged?.call(item.value);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final ComboBoxItem<T>? selected = _selected;
    final bool enabled = _enabled;

    final Widget content = DefaultTextStyle(
      style: theme.typography.body!.copyWith(
        color: enabled
            ? theme.resources.textFillColorPrimary
            : theme.resources.textFillColorDisabled,
      ),
      overflow: TextOverflow.ellipsis,
      child: IconTheme.merge(
        data: IconThemeData(
          color: enabled
              ? palette.textSecondary
              : theme.resources.textFillColorDisabled,
          size: 10,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: selected?.child ??
                    widget.placeholder ??
                    const SizedBox.shrink(),
              ),
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 8),
                child: Icon(FluentIcons.chevron_down),
              ),
            ],
          ),
        ),
      ),
    );

    return FlyoutTarget(
      controller: _controller,
      child: GestureDetector(
        onTap: _open,
        child: MouseRegion(
          key: _boxKey,
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 32,
            width: widget.isExpanded ? double.infinity : null,
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: !enabled
                  ? theme.resources.controlFillColorDisabled
                  : _hovered
                  ? theme.resources.controlFillColorSecondary
                  : theme.resources.controlFillColorDefault,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _hovered && enabled
                    ? theme.resources.controlStrongStrokeColorDefault
                    : theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: DefaultTextStyle.merge(
              style: theme.typography.body!,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupRow<T> extends StatefulWidget {
  const _PopupRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ComboBoxItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PopupRow<T>> createState() => _PopupRowState<T>();
}

class _PopupRowState<T> extends State<_PopupRow<T>> {
  bool _hovered = false;

  // The popup is always solid white, so its content uses the light theme's
  // ink colours regardless of the app theme.
  static const Color _ink = Color(0xE4000000);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: 10, end: 10),
          height: 32,
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0x14000000)
                : _hovered
                ? const Color(0x0B000000)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: _ink, fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
            child: Row(
              children: <Widget>[
                Expanded(child: widget.item.child),
                if (widget.selected)
                  const Icon(
                    FluentIcons.check_mark,
                    size: 10,
                    color: _ink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
