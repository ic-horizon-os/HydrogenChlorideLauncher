import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../core/models/plugin_manifest.dart';
import '../../../core/services/platform_actions.dart';
import '../../../core/utils/json_utils.dart';
import '../../../state/app_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';
import 'settings_widgets.dart';

Future<void> showPluginPageDialog(
  BuildContext context,
  PluginManifest manifest,
  PluginPage page,
) {
  return showFluentDialog<void>(
    context: context,
    title: page.title,
    description: '${manifest.name} ${manifest.version} · 声明式插件页面',
    width: 720,
    child: PluginPageView(manifest: manifest, page: page),
    actions: <Widget>[
      FluentButton(
        label: '关闭',
        style: FluentButtonStyle.primary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

IconData pluginIcon(String name) {
  switch (name) {
    case 'auto_awesome':
      return Icons.auto_awesome;
    case 'extension':
      return Icons.extension_outlined;
    case 'rss_feed':
      return Icons.rss_feed;
    case 'science':
      return Icons.science_outlined;
    case 'settings':
      return Icons.settings_outlined;
    default:
      return Icons.extension_outlined;
  }
}

class PluginPageView extends StatelessWidget {
  const PluginPageView({super.key, required this.manifest, required this.page});

  final PluginManifest manifest;
  final PluginPage page;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    if (page.widgets.isEmpty) {
      return Text(
        '这个页面还没有声明任何组件。',
        style: TextStyle(color: palette.textSecondary, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Map<String, dynamic> node in page.widgets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildNode(context, node),
          ),
        const SizedBox(height: 8),
        SettingsBanner(
          message:
              '声明式页面：组件由启动器渲染，插件代码不会在启动器进程中执行。'
              '声明权限：${manifest.permissions.isEmpty ? '无' : manifest.permissions.join('、')}',
        ),
      ],
    );
  }

  Widget _buildNode(BuildContext context, Map<String, dynamic> node) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final String type = asString(node['type'], 'text');
    switch (type) {
      case 'heading':
        return Text(
          asString(node['text']),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        );
      case 'subheading':
        return Text(
          asString(node['text']),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        );
      case 'paragraph':
      case 'text':
        return Text(
          asString(node['text']),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            height: 1.75,
          ),
        );
      case 'code':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background.withValues(
              alpha: palette.isDark ? 0.45 : 0.6,
            ),
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
            border: Border.all(color: palette.border),
          ),
          child: SelectableText(
            asString(node['text']),
            style: TextStyle(
              color: palette.textPrimary,
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.6,
            ),
          ),
        );
      case 'divider':
        return Divider();
      case 'spacer':
        return SizedBox(height: asDouble(node['height'], 12));
      case 'list':
        final List<Object?> items = node['items'] is List
            ? node['items'] as List
            : const <Object?>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((Object? item) {
                final String text = item is Map
                    ? asString(item['text'])
                    : asString(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
              .toList(growable: false),
        );
      case 'callout':
        return SettingsBanner(
          message: asString(node['text']),
          icon: Icons.lightbulb_outline,
          tone: switch (asString(node['tone'], 'info')) {
            'warning' => SettingsBannerTone.warning,
            'danger' => SettingsBannerTone.danger,
            _ => SettingsBannerTone.info,
          },
        );
      case 'row':
        final List<Map<String, dynamic>> children = asMapList(node['children']);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((Map<String, dynamic> child) => _buildNode(context, child))
              .toList(growable: false),
        );
      case 'column':
        final List<Map<String, dynamic>> children = asMapList(node['children']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .map(
                (Map<String, dynamic> child) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildNode(context, child),
                ),
              )
              .toList(growable: false),
        );
      case 'image':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.subtleFill,
            borderRadius: BorderRadius.circular(FluentTokens.radius),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.image_outlined, size: 18, color: palette.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '图片组件（Alpha 不加载远程图片）：${asString(node['url'])}',
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'button':
        final Map<String, dynamic> action = asMap(node['action']);
        final String actionType = asString(action['type']);
        final bool allowed =
            actionType != 'openUrl' || manifest.permissions.contains('openUrl');
        return Align(
          alignment: Alignment.centerLeft,
          child: FluentButton(
            label: asString(node['label'], '操作'),
            icon: allowed ? Icons.arrow_forward : Icons.block,
            style: FluentButtonStyle.secondary,
            dense: true,
            onPressed: allowed
                ? () => _handleAction(context, action)
                : () => showAppMessage(context, '插件未声明所需权限。'),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(FluentTokens.radiusSmall),
          ),
          child: Text(
            '未知组件类型：$type',
            style: TextStyle(color: palette.warning, fontSize: 11),
          ),
        );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    Map<String, dynamic> action,
  ) async {
    final AppState app = AppScope.of(context);
    switch (asString(action['type'])) {
      case 'openUrl':
        final String url = asString(action['url']);
        if (url.isEmpty) return;
        await PlatformActions.openExternal(url);
        break;
      case 'openSettings':
        final String section = asString(action['section']);
        final SettingsSection target = SettingsSection.values.firstWhere(
          (SettingsSection value) => value.name == section,
          orElse: () => SettingsSection.about,
        );
        app.openSettings(target);
        break;
      case 'showMessage':
        showAppMessage(context, asString(action['text'], '插件消息'));
        break;
      default:
        showAppMessage(context, '插件请求了不支持的动作。');
    }
  }
}
