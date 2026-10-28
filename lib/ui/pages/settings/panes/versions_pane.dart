import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../../core/minecraft/download_source.dart';
import '../../../../core/models/app_entry.dart';
import '../../../../core/services/platform_actions.dart';
import '../../../../core/services/version_scanner.dart';
import '../../../../core/utils/format.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../settings_widgets.dart';

/// Settings → 版本管理.
///
/// Manages the Minecraft directories only. Versions found in every configured
/// directory are listed together; installing a version or a loader lives on
/// the 库 page.
class VersionsPane extends StatelessWidget {
  const VersionsPane({super.key});

  Future<void> _addDirectory(AppState app) async {
    final String? directory = await getDirectoryPath(confirmButtonText: '添加目录');
    if (directory == null) return;
    if (app.settings.minecraftDirs.contains(directory)) return;
    await app.setMinecraftDirs(<String>[
      ...app.settings.minecraftDirs,
      directory,
    ]);
  }

  Future<void> _removeDirectory(
    BuildContext context,
    AppState app,
    String path,
  ) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '移除 Minecraft 目录',
      message: '只会从启动器配置中移除：\n$path\n\n不会删除磁盘上的任何文件。',
      confirmLabel: '移除',
      destructive: true,
    );
    if (!confirmed) return;
    await app.setMinecraftDirs(
      app.settings.minecraftDirs.where((String item) => item != path).toList(),
    );
  }

  Future<void> _deleteVersion(
    BuildContext context,
    AppState app,
    InstalledVersion version,
  ) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '删除游戏版本',
      message:
          '将永久删除目录：\n${version.directory.path}\n\n'
          '这是真实文件删除，无法撤销。请确认该版本不再需要。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await version.directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      if (!context.mounted) return;
      showAppMessage(context, '删除失败：${error.message}');
      return;
    }
    await app.scanVersions();
    if (!context.mounted) return;
    showAppMessage(context, '已删除版本“${version.id}”。');
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<InstalledVersion> versions = app.installedVersions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '版本管理',
          description: '管理 Minecraft 目录；所有目录中的版本会合并显示。安装与启动在「库」页面。',
          trailing: MetaPill(
            label: '${versions.length} 个版本',
            icon: Icons.storage_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            FluentButton(
              label: '添加 .minecraft 目录',
              icon: Icons.add,
              dense: true,
              onPressed: () => _addDirectory(app),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: app.scanningVersions ? '扫描中…' : '刷新扫描',
              icon: Icons.refresh,
              dense: true,
              loading: app.scanningVersions,
              onPressed: app.scanningVersions ? null : app.scanVersions,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: 'Minecraft 目录',
          description: '可以添加多个目录，版本列表会把它们合并展示。',
          children: <Widget>[
            if (app.settings.minecraftDirs.isEmpty)
              Text(
                '尚未配置目录。',
                style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
              )
            else
              for (final String directory in app.settings.minecraftDirs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        FluentTokens.radiusSmall,
                      ),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Directory(directory).existsSync()
                              ? Icons.folder_outlined
                              : Icons.folder_off_outlined,
                          size: 14,
                          color: Directory(directory).existsSync()
                              ? palette.textSecondary
                              : palette.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            directory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          '${versions.where((InstalledVersion v) => v.rootDir == directory).length} 个版本',
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 6),
                        FluentIconButton(
                          icon: Icons.folder_open_outlined,
                          tooltip: '打开目录',
                          onPressed: () =>
                              PlatformActions.openDirectory(directory),
                        ),
                        FluentIconButton(
                          icon: Icons.close,
                          tooltip: '从配置中移除',
                          onPressed: () =>
                              _removeDirectory(context, app, directory),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '全部版本',
          description: '合并所有目录后按游戏版本排序，存储空间由目录遍历计算。',
          children: <Widget>[
            if (app.scanningVersions && versions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '正在扫描版本目录…',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (versions.isEmpty)
              Text(
                '目录中没有版本。请在「库」页面安装，或添加包含 versions 的目录。',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11.5,
                  height: 1.6,
                ),
              )
            else
              for (final InstalledVersion version in versions)
                _VersionRow(
                  version: version,
                  app: app,
                  onDelete: () => _deleteVersion(context, app, version),
                ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '下载源',
          description: '版本清单、库文件与资源可以走镜像；Java 运行时跟随版本源。',
          children: <Widget>[
            SettingsRow(
              title: '版本与 Java 元数据',
              subtitle: app.settings.metaDownloadSource.description,
              trailing: SizedBox(
                width: 180,
                child: ComboBox<DownloadSource>(
                  value: app.settings.metaDownloadSource,
                  isExpanded: true,
                  items: DownloadSource.values
                      .map(
                        (DownloadSource source) => ComboBoxItem<DownloadSource>(
                          value: source,
                          child: Text(source.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (DownloadSource? value) {
                    if (value != null) app.setMetaDownloadSource(value);
                  },
                ),
              ),
            ),
            SettingsDivider(),
            SettingsRow(
              title: '游戏文件',
              subtitle: app.settings.fileDownloadSource.description,
              trailing: SizedBox(
                width: 180,
                child: ComboBox<DownloadSource>(
                  value: app.settings.fileDownloadSource,
                  isExpanded: true,
                  items: DownloadSource.values
                      .map(
                        (DownloadSource source) => ComboBoxItem<DownloadSource>(
                          value: source,
                          child: Text(source.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (DownloadSource? value) {
                    if (value != null) app.setFileDownloadSource(value);
                  },
                ),
              ),
            ),
            SettingsDivider(),
            SettingsRow(
              title: '自动下载 Java',
              subtitle: '本机没有匹配版本时，从 Mojang 下载对应运行时到 runtime/。',
              trailing: ToggleSwitch(
                checked: app.settings.autoDownloadJava,
                onChanged: (bool value) => app.setAutoDownloadJava(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.app,
    required this.onDelete,
  });

  final InstalledVersion version;
  final AppState app;
  final VoidCallback onDelete;

  DateTime? get _lastPlayed {
    DateTime? result;
    for (final AppEntry entry in app.library.entries) {
      if (entry.versionId != version.id) continue;
      final DateTime? candidate = entry.lastPlayed;
      if (candidate == null) continue;
      if (result == null || candidate.isAfter(result)) {
        result = candidate;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(FluentTokens.radius),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 15,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  version.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  version.loader == 'Vanilla'
                      ? 'Minecraft ${version.minecraftVersion}'
                      : '${version.loader} · Minecraft ${version.minecraftVersion}',
                  style: TextStyle(color: palette.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
          MetaPill(label: version.loader, dense: true),
          if (!version.hasJson) ...<Widget>[
            const SizedBox(width: 6),
            MetaPill(label: '缺少 JSON', dense: true),
          ],
          const SizedBox(width: 14),
          SizedBox(
            width: 120,
            child: Text(
              version.rootDir,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(color: palette.textTertiary, fontSize: 10),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: FutureBuilder<int>(
              future: app.core.directorySize(version.directory.path),
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                return Text(
                  snapshot.hasData ? formatBytes(snapshot.data!) : '…',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              formatRelativeTime(_lastPlayed),
              style: TextStyle(color: palette.textTertiary, fontSize: 10),
            ),
          ),
          FluentIconButton(
            icon: Icons.folder_open_outlined,
            tooltip: '打开版本目录',
            onPressed: () =>
                PlatformActions.openDirectory(version.directory.path),
          ),
          FluentIconButton(
            icon: Icons.delete_outline,
            tooltip: '删除版本目录',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
