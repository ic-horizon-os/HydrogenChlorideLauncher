import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants.dart';
import '../../../../core/services/platform_actions.dart';
import '../../../../core/services/update_service.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../../about/about_dialog.dart';
import '../settings_widgets.dart';

class AboutPane extends StatelessWidget {
  const AboutPane({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '关于',
          description: '开源许可、GitHub 地址与免责声明。',
          trailing: MetaPill(
            label: '${AppInfo.channel} ${AppInfo.version}',
            icon: Icons.science_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                palette.surface,
                Color.lerp(palette.surface, palette.accent, 0.18)!,
              ],
            ),
            borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
            border: Border.all(color: palette.border),
          ),
          child: Row(
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
                  size: 30,
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
                      style: FluentTheme.of(context).typography.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '跨平台、可扩展的 Java 程序启动器 · Flutter + Dart',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<PackageInfo> snapshot,
                          ) {
                            final String version = snapshot.hasData
                                ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                                : AppInfo.version;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                MetaPill(
                                  label: '版本 $version',
                                  icon: Icons.tag,
                                  dense: true,
                                ),
                                const MetaPill(
                                  label: 'GPL-3.0',
                                  icon: Icons.description_outlined,
                                  dense: true,
                                ),
                                MetaPill(
                                  label: Platform.isWindows
                                      ? 'Windows'
                                      : 'Linux',
                                  icon: Icons.desktop_windows_outlined,
                                  dense: true,
                                ),
                              ],
                            );
                          },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            FluentButton(
              label: 'GitHub 仓库',
              icon: Icons.code,
              onPressed: () => PlatformActions.openExternal(AppInfo.githubUrl),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '问题反馈',
              icon: Icons.bug_report_outlined,
              onPressed: () => PlatformActions.openExternal(AppInfo.issuesUrl),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '开源许可',
              icon: Icons.description_outlined,
              onPressed: () => showLicensesDialog(context),
            ),
            const Spacer(),
            FluentButton(
              label: '打开配置目录',
              icon: Icons.folder_open_outlined,
              dense: true,
              style: FluentButtonStyle.ghost,
              onPressed: () =>
                  PlatformActions.openDirectory(app.paths.configDir.path),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '打开数据目录',
              icon: Icons.folder_open_outlined,
              dense: true,
              style: FluentButtonStyle.ghost,
              onPressed: () =>
                  PlatformActions.openDirectory(app.paths.dataDir.path),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 14),
        const _UpdateCard(),
        const SizedBox(height: 14),
        SettingsCard(
          title: '技术栈与依赖',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <Widget>[
                MetaPill(label: 'Flutter 3.47', icon: Icons.flutter_dash),
                MetaPill(label: 'Dart 3.13', icon: Icons.code),
                MetaPill(label: 'window_manager', icon: Icons.window_outlined),
                MetaPill(label: 'file_selector', icon: Icons.folder_outlined),
                MetaPill(label: 'http', icon: Icons.http),
                MetaPill(label: 'url_launcher', icon: Icons.open_in_new),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '完整依赖许可证可在“开源许可”中查看。Flutter 的 LicenseRegistry '
              '会自动汇总应用与包依赖的许可证。',
              style: TextStyle(
                color: palette.textTertiary,
                fontSize: 10.5,
                height: 1.55,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '存储位置',
          children: <Widget>[
            SettingsRow(
              title: '配置',
              subtitle: app.paths.configDir.path,
              trailing: FluentIconButton(
                icon: Icons.folder_open_outlined,
                tooltip: '打开配置目录',
                onPressed: () =>
                    PlatformActions.openDirectory(app.paths.configDir.path),
              ),
            ),
            SettingsDivider(),
            SettingsRow(
              title: '数据与插件',
              subtitle: app.paths.dataDir.path,
              trailing: FluentIconButton(
                icon: Icons.folder_open_outlined,
                tooltip: '打开数据目录',
                onPressed: () =>
                    PlatformActions.openDirectory(app.paths.dataDir.path),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '免责声明',
          children: <Widget>[
            Text(
              AppInfo.disclaimer,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                height: 1.7,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpdateCard extends StatefulWidget {
  const _UpdateCard();

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  late final TextEditingController _url = TextEditingController();
  bool _initialized = false;
  bool _busy = false;
  File? _downloaded;
  String? _summary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _url.text = AppScope.read(context).settings.updateManifestUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final AppState app = AppScope.read(context);
    await app.setUpdates(manifestUrl: _url.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = true;
      _summary = '正在检查…';
      _downloaded = null;
    });
    final UpdateCheckResult result = await app.checkForUpdates();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.error != null) {
        _summary = result.error;
      } else if (result.latest == null) {
        _summary = '没有可用版本信息。';
      } else if (!result.hasUpdate) {
        _summary = '已是最新版本 ${result.currentVersion}。';
      } else {
        _summary = '新版本 ${result.latest!.version}：${result.latest!.notes}';
      }
    });
  }

  Future<void> _download() async {
    final AppState app = AppScope.read(context);
    final UpdateRelease? release = app.updates.lastCheck?.latest;
    if (release == null) return;
    setState(() => _busy = true);
    final File? file = await app.downloadUpdate(release);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _downloaded = file;
      _summary = file == null
          ? (app.updates.message ?? '下载失败。')
          : '更新包已下载并通过校验，可以应用并重启。';
    });
  }

  Future<void> _apply() async {
    final AppState app = AppScope.read(context);
    final File? file = _downloaded;
    if (file == null) return;
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '应用更新',
      message: '启动器会替换当前安装目录中的文件并需要重启。继续？',
      confirmLabel: '应用并重启',
    );
    if (!confirmed) return;
    await app.applyUpdate(
      file,
      executableName:
          app.updates.lastCheck?.latest?.currentPlatform?.executableName,
    );
    if (!mounted) return;
    setState(() => _summary = app.updates.message ?? '更新已就绪。');
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final UpdateService updates = app.updates;
    return SettingsCard(
      title: '更新',
      description: '填写更新清单地址后检查新版本。清单为 JSON，包含 version、notes 与各平台资产。',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextBox(
                controller: _url,
                placeholder: 'https://example.com/hcl/updates.json',
                onSubmitted: (_) => _check(),
              ),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '检查更新',
              icon: Icons.system_update_alt,
              dense: true,
              loading: _busy && updates.stage == UpdateStage.checking,
              onPressed: _busy ? null : _check,
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '下载',
              icon: Icons.download_outlined,
              dense: true,
              onPressed:
                  _busy || (updates.lastCheck?.hasUpdate ?? false) == false
                  ? null
                  : _download,
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '应用',
              icon: Icons.restart_alt,
              dense: true,
              style: FluentButtonStyle.primary,
              onPressed: _downloaded == null ? null : _apply,
            ),
          ],
        ),
        if (updates.stage == UpdateStage.downloading ||
            updates.stage == UpdateStage.applying) ...<Widget>[
          const SizedBox(height: 10),
          ProgressBar(value: updates.progress <= 0 ? null : updates.progress),
        ],
        if (_summary != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            _summary!,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 6),
        SettingsRow(
          dense: true,
          title: '启动时检查更新',
          trailing: ToggleSwitch(
            checked: app.settings.checkUpdatesOnStart,
            onChanged: (bool value) => app.setUpdates(checkOnStart: value),
          ),
        ),
      ],
    );
  }
}
