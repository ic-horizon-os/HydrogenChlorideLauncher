import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;

import '../../../../core/models/plugin_manifest.dart';
import '../../../../core/services/platform_actions.dart';
import '../../../../state/app_scope.dart';
import '../../../../core/services/install_module.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../plugin_page_view.dart';
import '../settings_widgets.dart';

class PluginsPane extends StatelessWidget {
  const PluginsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<PluginManifest> plugins = app.plugins.plugins;
    final int enabledCount = plugins
        .where((PluginManifest plugin) => plugin.enabled)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '插件管理',
          description: '安装、启用和卸载插件。页面由启动器渲染，不执行第三方代码。',
          trailing: MetaPill(
            label: '$enabledCount / ${plugins.length} 已启用',
            icon: Icons.extension_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            FluentButton(
              label: '打开插件目录',
              icon: Icons.folder_open_outlined,
              dense: true,
              onPressed: () =>
                  PlatformActions.openDirectory(app.plugins.pluginsPath),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '安装插件',
              icon: Icons.add,
              dense: true,
              style: FluentButtonStyle.primary,
              onPressed: () => _install(context, app),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '重新加载',
              icon: Icons.refresh,
              dense: true,
              style: FluentButtonStyle.ghost,
              onPressed: app.reloadPlugins,
            ),
            const Spacer(),
            Text(
              app.plugins.pluginsPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textTertiary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '功能模块',
          description: '安装能力由独立模块提供，停用后库页的安装入口会隐藏。',
          children: <Widget>[
            for (final InstallModule module in app.installModules.modules)
              SettingsRow(
                title: module.name,
                subtitle: module.description,
                trailing: ToggleSwitch(
                  checked: app.installModules.isEnabled(module),
                  onChanged: (bool value) =>
                      app.installModules.setEnabled(module, value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const SettingsBanner(
          message:
              '插件目录结构：<plugins>/<插件 id>/plugin.json，可附带资源文件。'
              '安装时会校验 id、版本、最低启动器版本与权限。卸载只删除插件目录。',
        ),
        const SizedBox(height: 16),
        if (plugins.isEmpty)
          EmptyState(
            icon: Icons.extension_outlined,
            title: '还没有可用插件',
            message: '安装一个插件目录，或载入仓库中的示例插件体验声明式页面。',
            action: FluentButton(
              label: '安装示例插件',
              icon: Icons.science_outlined,
              style: FluentButtonStyle.primary,
              onPressed: () => _installExample(context, app),
            ),
          )
        else
          for (final PluginManifest plugin in plugins) ...<Widget>[
            _PluginCard(plugin: plugin, app: app),
            const SizedBox(height: 12),
          ],
        if (app.plugins.invalid.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '无法加载的插件',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final PluginLoadResult result in app.plugins.invalid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SettingsBanner(
                message: '${result.directory}\n${result.error ?? '未知错误'}',
                icon: Icons.warning_amber_rounded,
                tone: SettingsBannerTone.warning,
              ),
            ),
        ],
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            FluentButton(
              label: '插件开发文档',
              icon: Icons.menu_book_outlined,
              dense: true,
              style: FluentButtonStyle.ghost,
              onPressed: () => PlatformActions.openExternal(
                'https://github.com/HyaLab/HydrogenChlorideLauncher/blob/main/docs/plugin-development.md',
              ),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '安装示例插件',
              icon: Icons.science_outlined,
              dense: true,
              style: FluentButtonStyle.ghost,
              onPressed: () => _installExample(context, app),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _install(BuildContext context, AppState app) async {
    final String? directory = await getDirectoryPath(confirmButtonText: '安装插件');
    if (directory == null) return;
    final PluginManifest? manifest = await app.installPlugin(
      Directory(directory),
    );
    if (!context.mounted) return;
    showAppMessage(
      context,
      manifest == null
          ? (app.lastError ?? '安装失败。')
          : '已安装插件“${manifest.name}” ${manifest.version}。',
    );
  }

  static Future<void> _installExample(
    BuildContext context,
    AppState app,
  ) async {
    final List<String> candidates = <String>[
      p.join(Directory.current.path, 'examples', 'plugins', 'hello-hcl'),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'examples',
        'plugins',
        'hello-hcl',
      ),
    ];
    String? source;
    for (final String candidate in candidates) {
      if (Directory(candidate).existsSync()) {
        source = candidate;
        break;
      }
    }
    if (source == null) {
      if (!context.mounted) return;
      showAppMessage(
        context,
        '未找到 examples/plugins/hello-hcl。请从仓库根目录运行，或使用“安装插件”选择目录。',
      );
      return;
    }
    final PluginManifest? manifest = await app.installPlugin(Directory(source));
    if (!context.mounted) return;
    showAppMessage(
      context,
      manifest == null
          ? (app.lastError ?? '安装示例插件失败。')
          : '已安装示例插件“${manifest.name}”。',
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin, required this.app});

  final PluginManifest plugin;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final Color base = plugin.isDemo
        ? palette.warning
        : Color.lerp(palette.accent, Colors.black, 0.2)!;
    return Card(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      backgroundColor: palette.surface,
      borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
      borderColor: plugin.enabled
          ? palette.border
          : palette.border.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[base, Color.lerp(base, Colors.black, 0.4)!],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  plugin.pages.isEmpty
                      ? Icons.extension_outlined
                      : pluginIcon(plugin.pages.first.icon),
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            plugin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MetaPill(label: 'v${plugin.version}', dense: true),
                        if (plugin.isDemo) ...<Widget>[
                          const SizedBox(width: 6),
                          const MetaPill(
                            label: '内置示例',
                            icon: Icons.science_outlined,
                            dense: true,
                          ),
                        ],
                        if (!plugin.enabled) ...<Widget>[
                          const SizedBox(width: 6),
                          MetaPill(label: '已禁用', dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${plugin.author} · ${plugin.id}',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ToggleSwitch(
                checked: plugin.enabled,
                onChanged: (bool value) =>
                    app.setPluginEnabled(plugin.id, value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plugin.description.isEmpty ? '该插件没有提供描述。' : plugin.description,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
          if (plugin.permissions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plugin.permissions
                  .map(
                    (String permission) => MetaPill(
                      label: '权限：$permission',
                      icon: Icons.key_outlined,
                      dense: true,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (plugin.pages.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final PluginPage page in plugin.pages)
                  FluentButton(
                    label: '打开页面：${page.title}',
                    icon: pluginIcon(page.icon),
                    dense: true,
                    onPressed: plugin.enabled
                        ? () => showPluginPageDialog(context, plugin, page)
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                plugin.minLauncherVersion == null
                    ? '未声明最低启动器版本'
                    : '最低启动器版本 ${plugin.minLauncherVersion}',
                style: TextStyle(color: palette.textTertiary, fontSize: 10),
              ),
              const Spacer(),
              if (!plugin.isDemo)
                FluentButton(
                  label: '卸载',
                  icon: Icons.delete_outline,
                  dense: true,
                  style: FluentButtonStyle.danger,
                  onPressed: () async {
                    final bool confirmed = await showConfirmDialog(
                      context: context,
                      title: '卸载插件',
                      message:
                          '将删除插件目录：\n${plugin.directory}\n\n不会影响库、统计或账户数据。',
                      confirmLabel: '卸载',
                      destructive: true,
                    );
                    if (!confirmed) return;
                    await app.uninstallPlugin(plugin.id);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
