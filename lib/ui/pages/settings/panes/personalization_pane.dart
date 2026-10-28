import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;

import '../../../../core/models/app_settings.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/acrylic_background.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../settings_widgets.dart';

const List<int> _accentPalette = <int>[
  0xFF0078D4,
  0xFF7C3AED,
  0xFF0F9D58,
  0xFFE11D48,
  0xFFF59E0B,
  0xFF0EA5E9,
  0xFF64748B,
  0xFFEC4899,
];

class PersonalizationPane extends StatefulWidget {
  const PersonalizationPane({super.key});

  @override
  State<PersonalizationPane> createState() => _PersonalizationPaneState();
}

class _PersonalizationPaneState extends State<PersonalizationPane> {
  double? _opacity;
  double? _sigma;

  double _currentOpacity(AppState app) =>
      _opacity ?? app.settings.backgroundOpacity;

  double _currentSigma(AppState app) =>
      _sigma ?? app.settings.backgroundBlurSigma;

  Future<void> _pickBackground(AppState app) async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: '图片',
          extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        ),
      ],
    );
    if (file == null) return;
    try {
      final String extension = p.extension(file.path).isEmpty
          ? '.png'
          : p.extension(file.path).toLowerCase();
      final String target = p.join(
        app.paths.backgroundsDir.path,
        'background-${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await app.paths.backgroundsDir.create(recursive: true);
      await File(file.path).copy(target);
      await app.setBackgroundImage(target);
      if (!mounted) return;
      showAppMessage(context, '背景图片已复制到启动器数据目录。');
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '无法复制背景图片：${error.message}');
    }
  }

  Future<void> _clearBackground(AppState app) async {
    final String? previous = app.settings.backgroundImagePath;
    await app.setBackgroundImage(null);
    if (previous != null &&
        p.isWithin(app.paths.backgroundsDir.path, previous)) {
      try {
        final File file = File(previous);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The setting is already cleared; a leftover file is harmless.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '个性化',
          description: '主题、背景、明暗色和强调色。',
          trailing: MetaPill(
            label: switch (app.settings.themeMode) {
              AppThemeMode.system => '跟随系统',
              AppThemeMode.light => '亮色',
              AppThemeMode.dark => '暗色',
            },
            icon: Icons.palette_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 18),
        SettingsCard(
          title: '主题',
          description: '亮色使用纯白背景，暗色使用纯黑背景；控件与层级由 Fluent 设计令牌控制。',
          children: <Widget>[
            SettingsRow(
              title: '明暗模式',
              subtitle: '跟随系统，或固定为纯白亮色 / 纯黑暗色。',
              leading: _SettingIcon(icon: FluentIcons.brightness),
              trailing: SizedBox(
                width: 150,
                child: ComboBox<AppThemeMode>(
                  value: app.settings.themeMode,
                  items: const <ComboBoxItem<AppThemeMode>>[
                    ComboBoxItem<AppThemeMode>(
                      value: AppThemeMode.system,
                      child: Text('跟随系统'),
                    ),
                    ComboBoxItem<AppThemeMode>(
                      value: AppThemeMode.light,
                      child: Text('亮色'),
                    ),
                    ComboBoxItem<AppThemeMode>(
                      value: AppThemeMode.dark,
                      child: Text('暗色'),
                    ),
                  ],
                  onChanged: (AppThemeMode? mode) {
                    if (mode != null) app.setThemeMode(mode);
                  },
                ),
              ),
            ),
            SettingsDivider(),
            SettingsRow(
              title: '强调色',
              subtitle: '用于选中态、主按钮与图表。',
              leading: _SettingIcon(icon: FluentIcons.color),
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _accentPalette
                    .map((int value) {
                      final bool selected =
                          app.settings.accentColorValue == value;
                      return Tooltip(
                        message: '强调色',
                        child: GestureDetector(
                          onTap: () => app.setAccentColor(value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? palette.textPrimary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    size: 13,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '背景',
          description:
              '背景图片、填充色透明度以及模糊方式。Alpha 使用 Flutter 的 '
              'BackdropFilter 实现高斯模糊，亚克力模式额外叠加噪点。',
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(FluentTokens.radius),
              child: SizedBox(
                height: 190,
                child: AcrylicBackground(
                  settings: app.settings,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '背景预览',
                          style: TextStyle(
                            color: palette.isDark ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '文本与面板会自动适配亮暗主题',
                          style: TextStyle(
                            color:
                                (palette.isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(
                              FluentTokens.radiusSmall,
                            ),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            '亚克力面板示例',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                FluentButton(
                  label: app.settings.backgroundImagePath == null
                      ? '选择背景图片'
                      : '更换背景图片',
                  icon: Icons.image_outlined,
                  dense: true,
                  onPressed: () => _pickBackground(app),
                ),
                const SizedBox(width: 8),
                if (app.settings.backgroundImagePath != null)
                  FluentButton(
                    label: '清除背景图片',
                    icon: Icons.hide_image_outlined,
                    dense: true,
                    style: FluentButtonStyle.ghost,
                    onPressed: () => _clearBackground(app),
                  ),
                const Spacer(),
                Text(
                  app.settings.backgroundImagePath == null
                      ? '当前使用强调色渐变网格'
                      : '图片已复制到数据目录',
                  style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsLabel(
              label: '背景填充透明度',
              trailing: Text(
                '${(_currentOpacity(app) * 100).round()}%',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Slider(
              value: _currentOpacity(app),
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (double value) {
                setState(() => _opacity = value);
                app.updateSettings(
                  app.settings.copyWith(backgroundOpacity: value),
                  persist: false,
                );
              },
              onChangeEnd: (double value) => app.updateSettings(
                app.settings.copyWith(backgroundOpacity: value),
              ),
            ),
            const SizedBox(height: 6),
            SettingsRow(
              dense: true,
              title: '启用背景模糊',
              subtitle: '关闭后背景图片保持清晰，仅保留填充色。',
              trailing: ToggleSwitch(
                checked: app.settings.backgroundBlur,
                onChanged: (bool value) => app.setBackgroundBlur(value),
              ),
            ),
            if (app.settings.backgroundBlur) ...<Widget>[
              SettingsDivider(),
              SettingsRow(
                title: '模糊实现方式',
                subtitle: '亚克力会在模糊之上叠加噪点。',
                leading: _SettingIcon(icon: FluentIcons.brightness),
                trailing: SizedBox(
                  width: 158,
                  child: ComboBox<BackgroundBlurMode>(
                    value: app.settings.backgroundBlurMode,
                    items: const <ComboBoxItem<BackgroundBlurMode>>[
                      ComboBoxItem<BackgroundBlurMode>(
                        value: BackgroundBlurMode.acrylic,
                        child: Text('亚克力'),
                      ),
                      ComboBoxItem<BackgroundBlurMode>(
                        value: BackgroundBlurMode.gaussian,
                        child: Text('高斯模糊'),
                      ),
                    ],
                    onChanged: (BackgroundBlurMode? mode) {
                      if (mode != null) app.setBackgroundBlurMode(mode);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SettingsLabel(
                label: '模糊强度',
                trailing: Text(
                  _currentSigma(app).toStringAsFixed(0),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Slider(
                value: _currentSigma(app).clamp(0, 64).toDouble(),
                min: 0,
                max: 64,
                divisions: 16,
                onChanged: (double value) {
                  setState(() => _sigma = value);
                  app.updateSettings(
                    app.settings.copyWith(backgroundBlurSigma: value),
                    persist: false,
                  );
                },
                onChangeEnd: (double value) => app.updateSettings(
                  app.settings.copyWith(backgroundBlurSigma: value),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '演示数据',
          children: <Widget>[
            SettingsRow(
              title: '显示演示数据',
              subtitle:
                  '在库、社区与统计中附带内置示例条目。'
                  '关闭时只显示你自己安装、添加的内容。',
              trailing: ToggleSwitch(
                checked: app.settings.demoData,
                onChanged: (bool value) => app.setDemoData(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: palette.subtleFill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 13, color: palette.textSecondary),
    );
  }
}
