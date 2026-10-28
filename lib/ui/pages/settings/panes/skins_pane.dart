import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;

import '../../../../core/services/platform_actions.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../settings_widgets.dart';

/// Settings → 皮肤. Holds one library of skins shared by every instance.
class SkinsPane extends StatefulWidget {
  const SkinsPane({super.key});

  @override
  State<SkinsPane> createState() => _SkinsPaneState();
}

class _SkinsPaneState extends State<SkinsPane> {
  List<File> _skins = <File>[];
  File? _selected;
  String _variant = 'classic';
  bool _uploading = false;

  Directory get _dir =>
      Directory(p.join(AppScope.read(context).paths.dataDir.path, 'skins'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_skins.isEmpty && _selected == null) _reload();
  }

  void _reload() {
    final List<File> files = <File>[];
    try {
      if (_dir.existsSync()) {
        for (final FileSystemEntity entity in _dir.listSync()) {
          if (entity is File &&
              RegExp(
                r'\.(png|jpg|jpeg)$',
                caseSensitive: false,
              ).hasMatch(entity.path)) {
            files.add(entity);
          }
        }
      }
    } on FileSystemException {
      // Keep the previous list when the folder cannot be read.
    }
    files.sort((File a, File b) => a.path.compareTo(b.path));
    if (!mounted) return;
    setState(() {
      _skins = files;
      if (_selected == null ||
          !files.any((File f) => f.path == _selected!.path)) {
        _selected = files.isEmpty ? null : files.first;
      }
    });
  }

  Future<void> _import() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: '皮肤图片', extensions: <String>['png', 'jpg', 'jpeg']),
      ],
    );
    if (file == null) return;
    try {
      await _dir.create(recursive: true);
      final File target = File(p.join(_dir.path, p.basename(file.path)));
      await File(file.path).copy(target.path);
      _selected = target;
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '导入失败：${error.message}');
    }
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '删除失败：${error.message}');
    }
  }

  Future<void> _upload() async {
    final File? file = _selected;
    if (file == null) return;
    final AppState app = AppScope.read(context);
    if (!app.isAuthenticated) {
      showAppMessage(context, '请先在「登录信息」中登录 Microsoft 账户。');
      return;
    }
    if (p.extension(file.path).toLowerCase() != '.png') {
      showAppMessage(context, 'Minecraft 只接受 PNG 皮肤。');
      return;
    }
    setState(() => _uploading = true);
    final String? error = await app.uploadSkin(file, variant: _variant);
    if (!mounted) return;
    setState(() => _uploading = false);
    showAppMessage(context, error ?? '已上传皮肤，重新进入游戏后生效。');
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '皮肤',
          description: '所有实例共用的皮肤库；可导入图片，或上传到已登录的 Microsoft 账户。',
          trailing: MetaPill(
            label: '${_skins.length} 个皮肤',
            icon: Icons.palette_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            FluentButton(
              label: '导入皮肤',
              icon: Icons.add,
              dense: true,
              style: FluentButtonStyle.primary,
              onPressed: _import,
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '打开皮肤目录',
              icon: Icons.folder_open_outlined,
              dense: true,
              onPressed: () {
                _dir.createSync(recursive: true);
                PlatformActions.openDirectory(_dir.path);
              },
            ),
            const Spacer(),
            SizedBox(
              width: 130,
              child: ComboBox<String>(
                value: _variant,
                isExpanded: true,
                items: const <ComboBoxItem<String>>[
                  ComboBoxItem<String>(value: 'classic', child: Text('经典')),
                  ComboBoxItem<String>(value: 'slim', child: Text('纤细')),
                ],
                onChanged: _uploading
                    ? null
                    : (String? value) {
                        if (value != null) setState(() => _variant = value);
                      },
              ),
            ),
            const SizedBox(width: 8),
            FluentButton(
              label: '上传到账户',
              icon: Icons.cloud_upload_outlined,
              dense: true,
              loading: _uploading,
              onPressed: _uploading || _selected == null ? null : _upload,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // The settings page scrolls, so its children have unbounded height;
        // Expanded would collapse to zero. Give the list a fixed height.
        SizedBox(
          height: 360,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 240,
                child: Card(
                  padding: const EdgeInsets.all(6),
                  margin: EdgeInsets.zero,
                  child: _skins.isEmpty
                      ? Center(
                          child: Text(
                            '还没有皮肤',
                            style: TextStyle(
                              color: palette.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _skins.length,
                          itemBuilder: (BuildContext context, int index) {
                            final File file = _skins[index];
                            return ListTile.selectable(
                              selected: _selected?.path == file.path,
                              onPressed: () => setState(() => _selected = file),
                              title: Text(p.basename(file.path)),
                              trailing: FluentIconButton(
                                icon: Icons.delete_outline,
                                tooltip: '删除',
                                onPressed: () => _delete(file),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  padding: const EdgeInsets.all(16),
                  margin: EdgeInsets.zero,
                  child: _selected == null
                      ? EmptyState(
                          icon: Icons.palette_outlined,
                          title: '尚未选择皮肤',
                          message: app.isAuthenticated
                              ? '导入一张 PNG 后即可上传到账户。'
                              : '登录 Microsoft 账户后可以上传皮肤。',
                        )
                      : Column(
                          children: <Widget>[
                            Expanded(
                              child: Image.file(
                                _selected!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              p.basename(_selected!.path),
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
