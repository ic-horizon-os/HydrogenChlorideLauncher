import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../../core/models/java_runtime.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../settings_widgets.dart';

class JavaPane extends StatefulWidget {
  const JavaPane({super.key});

  @override
  State<JavaPane> createState() => _JavaPaneState();
}

class _JavaPaneState extends State<JavaPane> {
  final TextEditingController _manualPath = TextEditingController();
  final TextEditingController _jvmArgs = TextEditingController();
  bool _loaded = false;
  double _memory = 4096;
  String? _hint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final AppState app = AppScope.read(context);
    _manualPath.text = app.settings.defaultJavaPath ?? '';
    _jvmArgs.text = app.settings.defaultJvmArgs;
    _memory = app.settings.defaultMemoryMb.toDouble();
  }

  @override
  void dispose() {
    _manualPath.dispose();
    _jvmArgs.dispose();
    super.dispose();
  }

  Future<void> _scan(AppState app) async {
    await app.scanJava();
    if (!mounted) return;
    showAppMessage(
      context,
      '扫描完成：发现 ${app.javaRuntimes.length} 个 Java 运行时（${app.javaBackend}）。',
    );
  }

  Future<void> _save(AppState app) async {
    await app.setDefaultMemory(_memory.round());
    await app.setDefaultJvmArgs(_jvmArgs.text.trim());
    if (!mounted) return;
    showAppMessage(context, '默认 JVM 设置已保存。');
  }

  void _setManualPath(AppState app) {
    final String value = _manualPath.text.trim();
    if (value.isEmpty) {
      app.setDefaultJavaPath(null);
      setState(() => _hint = null);
      return;
    }
    final bool exists = File(value).existsSync();
    app.setDefaultJavaPath(value);
    setState(() {
      _hint = exists ? '已设为默认 Java。' : '路径暂不存在，仍已保存；扫描后请确认。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final List<JavaRuntime> runtimes = app.javaRuntimes;
    final bool scanning = app.scanningJava;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: 'Java 设置',
          description: '扫描本机 Java，设置默认运行时、内存和 JVM 参数。',
          trailing: MetaPill(
            label: app.javaBackend,
            icon: Icons.memory,
            dense: true,
          ),
        ),
        const SizedBox(height: 16),
        const SettingsBanner(
          message: '仅保存配置，不分配内存或启动 Java。优先使用 Rust 扫描，缺失时回退 Dart。',
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: '已发现的 Java 运行时',
          description: '扫描 JAVA_HOME、PATH 和常见安装目录。',
          children: <Widget>[
            Row(
              children: <Widget>[
                FluentButton(
                  label: scanning ? '扫描中…' : '重新扫描',
                  icon: Icons.refresh,
                  dense: true,
                  loading: scanning,
                  onPressed: scanning ? null : () => _scan(app),
                ),
                const SizedBox(width: 10),
                Text(
                  runtimes.isEmpty ? '尚未发现运行时' : '共 ${runtimes.length} 个运行时',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
                const Spacer(),
                FluentButton(
                  label: '跟随自动选择',
                  dense: true,
                  style: FluentButtonStyle.ghost,
                  onPressed: () {
                    app.setDefaultJavaPath(null);
                    _manualPath.clear();
                    setState(() => _hint = '将使用启动器的自动选择策略。');
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (scanning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
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
                        '正在扫描 Java 运行时…',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (runtimes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '没有发现 Java。安装 OpenJDK 后重新扫描，或在下方填写 java 路径。',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    height: 1.6,
                  ),
                ),
              )
            else
              for (final JavaRuntime runtime in runtimes)
                _JavaRuntimeRow(
                  runtime: runtime,
                  selected: app.settings.defaultJavaPath == runtime.path,
                  onTap: () {
                    app.setDefaultJavaPath(runtime.path);
                    _manualPath.text = runtime.path;
                    setState(() => _hint = null);
                  },
                ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextBox(
                    controller: _manualPath,
                    placeholder: '手动输入默认 java 可执行文件路径',
                  ),
                ),
                const SizedBox(width: 8),
                FluentButton(
                  label: '设为默认',
                  dense: true,
                  onPressed: () => _setManualPath(app),
                ),
              ],
            ),
            if (_hint != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _hint!,
                style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '默认 JVM 设置',
          description: '库条目的默认值，可按条目覆盖。',
          children: <Widget>[
            SettingsLabel(
              label: '最大内存',
              trailing: Text(
                '${_memory.round()} MB',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Slider(
              value: _memory.clamp(1024, 16384).toDouble(),
              min: 1024,
              max: 16384,
              divisions: 30,
              onChanged: (double value) {
                setState(() => _memory = (value / 512).round() * 512);
              },
            ),
            const SizedBox(height: 6),
            SettingsLabel(label: '默认 JVM 参数'),
            TextBox(
              controller: _jvmArgs,
              placeholder: '-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions',
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                FluentButton(
                  label: '保存默认设置',
                  icon: Icons.check,
                  style: FluentButtonStyle.primary,
                  dense: true,
                  onPressed: () => _save(app),
                ),
                const SizedBox(width: 10),
                Text(
                  '当前默认 Java：${app.settings.defaultJavaPath ?? '自动选择'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsCard(
          title: '启动器默认值与条目覆盖',
          children: <Widget>[
            SettingsRow(
              title: 'Java 版本由游戏版本决定',
              subtitle:
                  'Minecraft 1.17+ 通常需要 Java 17，1.20.5+ 建议 Java 21。'
                  'Alpha 不校验版本兼容性。',
              leading: Icon(
                FluentIcons.info,
                size: 15,
                color: palette.textTertiary,
              ),
            ),
            SettingsDivider(),
            SettingsRow(
              title: '条目级覆盖',
              subtitle: '在库中右键条目 → Java 设置 / JVM 设置，可为单个实例指定不同的 Java 与内存。',
              leading: Icon(Icons.tune, size: 15, color: palette.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

class _JavaRuntimeRow extends StatelessWidget {
  const _JavaRuntimeRow({
    required this.runtime,
    required this.selected,
    required this.onTap,
  });

  final JavaRuntime runtime;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? palette.accent.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(FluentTokens.radius),
            border: Border.all(
              color: selected
                  ? palette.accent.withValues(alpha: 0.35)
                  : palette.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 15,
                color: selected ? palette.accent : palette.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          runtime.label,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        MetaPill(label: runtime.arch, dense: true),
                        const SizedBox(width: 6),
                        MetaPill(label: runtime.source, dense: true),
                        if (selected) ...<Widget>[
                          const SizedBox(width: 6),
                          MetaPill(
                            label: '默认',
                            color: palette.accent,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      runtime.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
