import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../core/constants.dart';
import '../../../core/services/platform_actions.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';

Future<void> showAboutHclDialog(BuildContext context) {
  final FluentPalette palette = FluentColors.of(context).palette;
  return showFluentDialog<void>(
    context: context,
    title: '关于 ${AppInfo.name}',
    description: '跨平台、可扩展的 Java 程序启动器',
    width: 620,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    palette.accent,
                    Color.lerp(palette.accent, Colors.black, 0.42)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.science_outlined,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppInfo.name,
                    style: FluentTheme.of(context).typography.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alpha ${AppInfo.version} · Flutter + Dart',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      MetaPill(label: 'UI 原型', dense: true),
                      MetaPill(label: 'Windows / Linux', dense: true),
                      MetaPill(label: 'Fluent Design', dense: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(FluentTokens.radius),
            border: Border.all(color: palette.warning.withValues(alpha: 0.25)),
          ),
          child: Text(
            AppInfo.demoNotice,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '免责声明',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppInfo.disclaimer,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '技术栈',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const <Widget>[
            MetaPill(
              label: 'Flutter 3.47',
              icon: Icons.flutter_dash,
              dense: true,
            ),
            MetaPill(label: 'Dart 3.13', icon: Icons.code, dense: true),
            MetaPill(label: '纯 Dart 核心', icon: Icons.memory, dense: true),
            MetaPill(
              label: 'GTK 3',
              icon: Icons.desktop_windows_outlined,
              dense: true,
            ),
          ],
        ),
      ],
    ),
    actions: <Widget>[
      FluentButton(
        label: '开源许可',
        icon: Icons.description_outlined,
        onPressed: () => showLicensesDialog(context),
      ),
      FluentButton(
        label: 'GitHub',
        icon: Icons.code,
        onPressed: () => PlatformActions.openExternal(AppInfo.githubUrl),
      ),
      FluentButton(
        label: '关闭',
        style: FluentButtonStyle.primary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

Future<void> showLicensesDialog(BuildContext context) {
  return showFluentDialog<void>(
    context: context,
    title: '开源许可',
    description: 'Hydrogen Chloride Launcher 及其依赖的许可证。',
    width: 760,
    child: SizedBox(
      height: 500,
      child: FutureBuilder<List<LicenseEntry>>(
        future: LicenseRegistry.licenses.toList(),
        builder:
            (BuildContext context, AsyncSnapshot<List<LicenseEntry>> snapshot) {
              if (snapshot.hasError) {
                return Text('无法读取许可证：${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: ProgressRing(strokeWidth: 2));
              }
              final List<LicenseEntry> entries = snapshot.data!;
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int index) {
                  final LicenseEntry entry = entries[index];
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.packages.join(', '),
                          style: FluentTheme.of(context).typography.subtitle,
                        ),
                        const SizedBox(height: 5),
                        for (final LicenseParagraph paragraph
                            in entry.paragraphs)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: 5,
                            ),
                            child: SelectableText(
                              paragraph.text,
                              style: FluentTheme.of(context).typography.caption,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
      ),
    ),
    actions: <Widget>[
      FluentButton(
        label: '关闭',
        style: FluentButtonStyle.primary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
