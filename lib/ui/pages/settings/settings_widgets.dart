import 'package:fluent_ui/fluent_ui.dart';

import '../../../theme/fluent_theme.dart';

class SettingsPaneHeader extends StatelessWidget {
  const SettingsPaneHeader({
    super.key,
    required this.title,
    required this.description,
    this.trailing,
  });

  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: FluentTheme.of(context).typography.titleLarge),
              const SizedBox(height: 5),
              Text(
                description,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 16),
          Padding(padding: const EdgeInsets.only(top: 4), child: trailing!),
        ],
      ],
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    this.title,
    this.description,
    required this.children,
    this.padding = const EdgeInsets.all(18),
  });

  final String? title;
  final String? description;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Card(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      backgroundColor: palette.surface,
      borderColor: palette.border,
      borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title!,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        widget.leading ??
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: palette.subtleFill,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                FluentIcons.settings,
                size: 13,
                color: palette.textSecondary,
              ),
            ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.trailing != null) ...<Widget>[
          const SizedBox(width: 14),
          widget.trailing!,
        ],
      ],
    );

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: widget.dense ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          ),
          child: content,
        ),
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(),
    );
  }
}

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.background.withValues(
            alpha: palette.isDark ? 0.35 : 0.5,
          ),
          borderRadius: BorderRadius.circular(FluentTokens.radius),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((SegmentOption<T> option) {
                final bool active = option.value == selected;
                return GestureDetector(
                  onTap: () => onSelected(option.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active ? palette.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        FluentTokens.radiusSmall,
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: active
                            ? palette.accentForeground
                            : palette.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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

class SettingsLabel extends StatelessWidget {
  const SettingsLabel({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class SettingsBanner extends StatelessWidget {
  const SettingsBanner({
    super.key,
    required this.message,
    this.icon = FluentIcons.info,
    this.tone = SettingsBannerTone.info,
  });

  final String message;
  final IconData icon;
  final SettingsBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color color = switch (tone) {
      SettingsBannerTone.info => palette.accent,
      SettingsBannerTone.warning => palette.warning,
      SettingsBannerTone.danger => palette.danger,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(FluentTokens.radius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum SettingsBannerTone { info, warning, danger }
