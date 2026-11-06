import 'package:fluent_ui/fluent_ui.dart';

import '../../../state/app_scope.dart';
import '../../../state/app_state.dart';
import '../../widgets/fluent_widgets.dart';
import 'panes/about_pane.dart';
import 'panes/account_pane.dart';
import 'panes/java_pane.dart';
import 'panes/personalization_pane.dart';
import 'panes/skins_pane.dart';
import 'panes/plugins_pane.dart';
import 'panes/statistics_pane.dart';
import 'panes/versions_pane.dart';

Future<void> showSettingsDialog(BuildContext context, AppState app) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) => SettingsDialog(app: app),
  );
}

/// Steam-style settings window: left navigation, right scrollable section.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.app});

  final AppState app;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    if (!widget.app.settingsOpen && mounted && !_popping) {
      _popping = true;
      Navigator.of(context).maybePop();
    }
  }

  void _close() {
    widget.app.closeSettings();
    if (mounted && !_popping) {
      _popping = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final Size size = MediaQuery.sizeOf(context);
    final double dialogWidth = (size.width - 80).clamp(760.0, 1040.0);
    final double dialogHeight = (size.height - 80).clamp(540.0, 760.0);
    final SettingsSection section = app.settingsSection;
    final Widget pane = switch (section) {
      SettingsSection.account => const AccountPane(),
      SettingsSection.personalization => const PersonalizationPane(),
      SettingsSection.plugins => const PluginsPane(),
      SettingsSection.java => const JavaPane(),
      SettingsSection.versions => const VersionsPane(),
      SettingsSection.skins => const SkinsPane(),
      SettingsSection.statistics => const StatisticsPane(),
      SettingsSection.about => const AboutPane(),
    };

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: dialogWidth,
        maxHeight: dialogHeight,
      ),
      title: Row(
        children: <Widget>[
          const Icon(FluentIcons.settings, size: 16),
          const SizedBox(width: 8),
          const Text('HCL 设置'),
          const Spacer(),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 12),
            onPressed: _close,
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth - 40,
        height: dialogHeight - 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 224,
              child: Card(
                padding: const EdgeInsets.all(6),
                margin: EdgeInsets.zero,
                child: SlidingNavList(
                  itemCount: SettingsSection.values.length,
                  selectedIndex: SettingsSection.values.indexOf(section),
                  itemBuilder: (BuildContext context, int index, Key key) {
                    final SettingsSection item = SettingsSection.values[index];
                    return IndicatorAnchor(
                      key: key,
                      index: index,
                      child: NavListTile(
                        selected: item == section,
                        showIndicator: false,
                        onPressed: () => app.selectSettingsSection(item),
                        leading: Icon(_iconFor(item), size: 14),
                        title: item.label,
                        subtitle: item.description,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              // No key here: keying the scaffold would recreate it (and the
              // entrance inside) before it plays. Only the pane below is
              // keyed; Windows 11 settings replaces the page instantly and
              // plays a single entrance — cheaper than cross-fading two
              // full scrollable panes.
              child: ScaffoldPage.scrollable(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 20),
                children: <Widget>[
                  KeyedSubtree(
                    key: ValueKey<SettingsSection>(section),
                    child: PageBodyEntrance(
                      duration: const Duration(milliseconds: 280),
                      offset: 0.04,
                      child: pane,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(SettingsSection section) {
    switch (section) {
      case SettingsSection.account:
        return FluentIcons.contact;
      case SettingsSection.personalization:
        return FluentIcons.personalize;
      case SettingsSection.plugins:
        return FluentIcons.puzzle;
      case SettingsSection.java:
        return FluentIcons.code;
      case SettingsSection.versions:
        return FluentIcons.library;
      case SettingsSection.skins:
        return FluentIcons.color;
      case SettingsSection.statistics:
        return FluentIcons.chart;
      case SettingsSection.about:
        return FluentIcons.info;
    }
  }
}
