import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as p;

import '../../../core/minecraft/loader_installer.dart';
import '../../../core/minecraft/minecraft_installer.dart';
import '../../../core/models/app_entry.dart';
import '../../../core/services/crash_analyzer.dart';
import '../../../core/services/world_repair.dart';
import '../../../core/services/platform_actions.dart';
import '../../../core/services/version_isolation.dart';
import '../../../core/utils/format.dart';
import '../../../state/app_state.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';
import '../../widgets/hcl_combo_box.dart';

class LoaderPanel extends StatefulWidget {
  const LoaderPanel({super.key, required this.entry, required this.app});

  final AppEntry entry;
  final AppState app;

  @override
  State<LoaderPanel> createState() => _LoaderPanelState();
}

class _LoaderPanelState extends State<LoaderPanel> {
  static const Map<String, LoaderKind> _kinds = <String, LoaderKind>{
    'Fabric': LoaderKind.fabric,
    'Forge': LoaderKind.forge,
    'NeoForge': LoaderKind.neoforge,
    'OptiFine': LoaderKind.optifine,
  };

  String _loader = 'Fabric';
  late final TextEditingController _version = TextEditingController(
    text: widget.entry.minecraftVersion ?? '1.21.1',
  );
  String? _error;

  List<LoaderBuild> _builds = <LoaderBuild>[];
  String? _build;
  bool _loadingBuilds = false;
  String? _buildError;
  bool _installing = false;
  String _stage = '';
  String _detail = '';
  double _fraction = 0;

  LoaderKind get _kind => _kinds[_loader] ?? LoaderKind.fabric;

  @override
  void dispose() {
    _version.dispose();
    super.dispose();
  }

  Future<void> _loadBuilds() async {
    final String version = _version.text.trim();
    if (version.isEmpty) {
      setState(() => _error = '请填写 Minecraft 版本。');
      return;
    }
    if (_kind == LoaderKind.optifine) {
      setState(() {
        _builds = <LoaderBuild>[];
        _build = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loadingBuilds = true;
      _buildError = null;
      _error = null;
    });
    try {
      final List<LoaderBuild> builds = await widget.app.loaderInstaller
          .listBuilds(_kind, version);
      if (!mounted) return;
      setState(() {
        _builds = builds;
        _build = builds.isEmpty ? null : builds.first.loaderVersion;
        _loadingBuilds = false;
        if (builds.isEmpty) {
          _buildError = '没有找到 $_loader $version 的可用构建。';
        }
      });
    } on InstallException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _builds = <LoaderBuild>[];
        _buildError = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _builds = <LoaderBuild>[];
        _buildError = '获取构建列表失败：$error';
      });
    }
  }

  Future<void> _install() async {
    final String version = _version.text.trim();
    if (version.isEmpty) {
      setState(() => _error = '请填写 Minecraft 版本。');
      return;
    }
    final String? build = _build;
    if (_kind != LoaderKind.optifine && (build == null || build.isEmpty)) {
      setState(() => _error = '请先选择加载器版本。');
      return;
    }
    setState(() {
      _installing = true;
      _stage = '准备安装';
      _detail = '';
      _fraction = 0;
      _error = null;
    });

    final AppEntry? created;
    if (_kind == LoaderKind.optifine) {
      created = await _installOptifine(version);
    } else {
      created = await widget.app.installLoader(
        _kind,
        version,
        build!,
        onProgress: (String stage, double fraction, String detail) {
          if (!mounted) return;
          setState(() {
            _stage = stage;
            _fraction = fraction;
            _detail = detail;
          });
        },
      );
    }
    if (!mounted) return;
    setState(() => _installing = false);
    if (created == null) {
      setState(() => _error = widget.app.lastError ?? '安装失败。');
      return;
    }
    showAppMessage(context, '已安装 $_loader，库中新增「${created.name}」。');
  }

  Future<AppEntry?> _installOptifine(String version) async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'OptiFine 安装文件', extensions: <String>['jar']),
      ],
    );
    if (file == null) return null;
    try {
      final LoaderInstallResult result = await widget.app.loaderInstaller
          .installOptifineFromJar(
            File(file.path),
            version,
            onProgress: (InstallProgress progress) {
              if (!mounted) return;
              setState(() {
                _stage = progress.stage;
                _fraction = progress.fraction;
                _detail = progress.detail;
              });
            },
          );
      final AppEntry entry = AppEntry(
        id: 'optifine-${result.versionId}',
        name: 'OptiFine ${result.loaderVersion}',
        subtitle: 'OptiFine · ${result.gameVersion}',
        description: '',
        kind: AppKind.minecraft,
        versionId: result.versionId,
        loader: 'OptiFine',
        minecraftVersion: result.gameVersion,
        isolated: true,
      );
      for (final AppEntry existing in widget.app.library.entries) {
        if (existing.id == entry.id) {
          await widget.app.updateEntry(entry);
          return entry;
        }
      }
      await widget.app.addEntry(entry);
      return entry;
    } on Object catch (error) {
      setState(() => _error = error.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final bool optifine = _kind == LoaderKind.optifine;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('安装加载器', style: FluentTheme.of(context).typography.titleLarge),
          const SizedBox(height: 5),
          Text(
            '安装后会写入新的版本 JSON 并自动加入库，版本隔离默认开启。',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Card(
            padding: const EdgeInsets.all(18),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '加载器',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          HclComboBox<String>(
                            value: _loader,
                            items: _kinds.keys
                                .map(
                                  (String name) => ComboBoxItem<String>(
                                    value: name,
                                    child: Text(name),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _installing
                                ? null
                                : (String? value) {
                                    if (value == null) return;
                                    setState(() {
                                      _loader = value;
                                      _builds = <LoaderBuild>[];
                                      _build = null;
                                      _buildError = null;
                                      _error = null;
                                    });
                                    _loadBuilds();
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Minecraft 版本',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextBox(
                            controller: _version,
                            placeholder: '例如 1.21.1',
                            onChanged: (_) => setState(() {
                              _builds = <LoaderBuild>[];
                              _build = null;
                            }),
                            onSubmitted: (_) => _loadBuilds(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!optifine) ...<Widget>[
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '$_loader 版本',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _loadingBuilds
                                ? Text(
                                    '正在获取构建列表…',
                                    style: TextStyle(
                                      color: palette.textTertiary,
                                      fontSize: 11.5,
                                    ),
                                  )
                                : HclComboBox<String>(
                                    value: _build,
                                    isExpanded: true,
                                    placeholder: const Text('读取构建'),
                                    items: _builds
                                        .map(
                                          (
                                            LoaderBuild build,
                                          ) => ComboBoxItem<String>(
                                            value: build.loaderVersion,
                                            child: Text(
                                              '${build.loaderVersion}'
                                              '${build.channel.isEmpty ? '' : ' · ${build.channel}'}',
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: _installing
                                        ? null
                                        : (String? value) =>
                                              setState(() => _build = value),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: FluentButton(
                          label: '获取构建',
                          icon: FluentIcons.refresh,
                          dense: true,
                          loading: _loadingBuilds,
                          onPressed: _installing ? null : _loadBuilds,
                        ),
                      ),
                    ],
                  ),
                ],
                if (optifine) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    'OptiFine 需要你从官网下载安装文件后导入。',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                if (_buildError != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _buildError!,
                    style: TextStyle(color: palette.warning, fontSize: 11.5),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: palette.danger, fontSize: 11.5),
                  ),
                ],
                if (_installing) ...<Widget>[
                  const SizedBox(height: 14),
                  ProgressBar(value: _fraction <= 0 ? null : _fraction),
                  const SizedBox(height: 6),
                  Text(
                    _detail.isEmpty ? _stage : '$_stage · $_detail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FluentButton(
                    label: optifine ? '导入 OptiFine 文件' : '安装',
                    icon: optifine
                        ? FluentIcons.open_file
                        : FluentIcons.download,
                    style: FluentButtonStyle.primary,
                    loading: _installing,
                    onPressed: _installing ? null : _install,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SettingsBanner(
            message:
                'Forge、NeoForge 会下载官方安装器并在后台用 Java 执行，'
                '需要几分钟；Fabric 直接下载元数据与库文件。',
          ),
        ],
      ),
    );
  }
}

class ModsPanel extends StatefulWidget {
  const ModsPanel({super.key, required this.entry, required this.app});

  final AppEntry entry;
  final AppState app;

  @override
  State<ModsPanel> createState() => _ModsPanelState();
}

class _ModsPanelState extends State<ModsPanel> {
  List<File> _mods = <File>[];

  Directory get _dir => Directory(
    p.join(
      VersionIsolation.instanceDir(widget.entry, widget.app.settings),
      'mods',
    ),
  );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ModsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _reload();
  }

  void _reload() {
    final List<File> files = <File>[];
    try {
      if (_dir.existsSync()) {
        for (final FileSystemEntity entity in _dir.listSync()) {
          if (entity is File && entity.path.endsWith('.jar')) {
            files.add(entity);
          } else if (entity is File && entity.path.endsWith('.jar.disabled')) {
            files.add(entity);
          }
        }
      }
    } on FileSystemException {
      // Keep the previous list if the directory cannot be read.
    }
    files.sort((File a, File b) => a.path.compareTo(b.path));
    setState(() => _mods = files);
  }

  Future<void> _addMod() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: '模组文件', extensions: <String>['jar', 'zip']),
      ],
    );
    if (file == null) return;
    try {
      await _dir.create(recursive: true);
      final File target = File(p.join(_dir.path, file.name));
      if (await target.exists()) {
        if (!mounted) return;
        showAppMessage(context, '${file.name} 已存在。');
        return;
      }
      await File(file.path).copy(target.path);
      _reload();
      if (!mounted) return;
      showAppMessage(context, '已添加 ${file.name}。');
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '添加失败：${error.message}');
    }
  }

  Future<void> _toggle(File file) async {
    final bool disabled = file.path.endsWith('.disabled');
    final String target = disabled
        ? file.path.substring(0, file.path.length - '.disabled'.length)
        : '${file.path}.disabled';
    try {
      await file.rename(target);
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '操作失败：${error.message}');
    }
  }

  Future<void> _delete(File file) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '删除模组',
      message: '将删除 ${p.basename(file.path)}，无法撤销。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await file.delete();
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '删除失败：${error.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '模组管理',
                      style: FluentTheme.of(context).typography.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dir.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              FluentButton(
                label: '添加模组',
                icon: FluentIcons.add,
                dense: true,
                style: FluentButtonStyle.primary,
                onPressed: _addMod,
              ),
              const SizedBox(width: 8),
              FluentIconButton(
                icon: FluentIcons.refresh,
                tooltip: '刷新',
                onPressed: _reload,
              ),
              FluentIconButton(
                icon: FluentIcons.folder,
                tooltip: '打开 mods',
                onPressed: () {
                  _dir.createSync(recursive: true);
                  PlatformActions.openDirectory(_dir.path);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!widget.entry.isolated)
            const SettingsBanner(
              message: '该条目未开启版本隔离，模组放在共享的 .minecraft/mods 下。',
              icon: FluentIcons.info,
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _mods.isEmpty
                ? const EmptyState(
                    icon: FluentIcons.puzzle,
                    title: '没有模组',
                    message: '添加 .jar 文件后，会显示在这里。',
                  )
                : Card(
                    padding: const EdgeInsets.all(6),
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: _mods.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Divider(),
                      itemBuilder: (BuildContext context, int index) {
                        final File file = _mods[index];
                        final bool disabled = file.path.endsWith('.disabled');
                        final String name = p.basename(
                          disabled
                              ? file.path.substring(
                                  0,
                                  file.path.length - '.disabled'.length,
                                )
                              : file.path,
                        );
                        final int bytes = file.lengthSync();
                        return ListTile(
                          leading: Icon(
                            disabled ? FluentIcons.cancel : FluentIcons.puzzle,
                            size: 16,
                          ),
                          title: Text(name),
                          subtitle: Text(
                            '${formatBytes(bytes)} · ${disabled ? '已禁用' : '已启用'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ToggleSwitch(
                                checked: !disabled,
                                onChanged: (_) => _toggle(file),
                              ),
                              const SizedBox(width: 6),
                              FluentIconButton(
                                icon: FluentIcons.delete,
                                tooltip: '删除',
                                onPressed: () => _delete(file),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class WorldsPanel extends StatefulWidget {
  const WorldsPanel({super.key, required this.entry, required this.app});

  final AppEntry entry;
  final AppState app;

  @override
  State<WorldsPanel> createState() => _WorldsPanelState();
}

class _WorldsPanelState extends State<WorldsPanel> {
  List<Directory> _worlds = <Directory>[];

  Directory get _dir => Directory(
    p.join(
      VersionIsolation.instanceDir(widget.entry, widget.app.settings),
      'saves',
    ),
  );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(WorldsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _reload();
  }

  void _reload() {
    final List<Directory> worlds = <Directory>[];
    try {
      if (_dir.existsSync()) {
        for (final FileSystemEntity entity in _dir.listSync()) {
          if (entity is Directory) worlds.add(entity);
        }
      }
    } on FileSystemException {
      // Keep the previous list.
    }
    worlds.sort((Directory a, Directory b) => a.path.compareTo(b.path));
    setState(() => _worlds = worlds);
  }

  Future<void> _backup(Directory world) async {
    final String name = p.basename(world.path);
    final String stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final Directory target = Directory(
      p.join(
        VersionIsolation.instanceDir(widget.entry, widget.app.settings),
        'backups',
        'worlds',
        '$name-$stamp',
      ),
    );
    try {
      await _copyDirectory(world, target);
      if (!mounted) return;
      showAppMessage(context, '已备份到 ${target.path}');
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '备份失败：${error.message}');
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final FileSystemEntity entity in source.list()) {
      final String name = p.basename(entity.path);
      if (entity is File) {
        await entity.copy(p.join(target.path, name));
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(target.path, name)));
      }
    }
  }

  Future<void> _delete(Directory world) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '删除世界',
      message: '将删除 ${p.basename(world.path)} 及其全部存档数据，无法撤销。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await world.delete(recursive: true);
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '删除失败：${error.message}');
    }
  }

  Future<void> _repair(Directory world) async {
    final WorldRepairReport report = await WorldRepair.analyze(world);
    if (!mounted) return;
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '修复世界 · ${p.basename(world.path)}',
      message:
          '检查结果：\n\n'
          '${report.issues.isEmpty ? '没有发现问题。' : report.issues.map((String issue) => '· $issue').join('\n')}'
          '\n\n'
          '${report.canRepair ? '可自动修复：\n${report.autoFixable.map((String item) => '· $item').join('\n')}\n\n修复前会备份 level.dat。' : '没有可自动修复的项目。'}',
      confirmLabel: report.canRepair ? '修复' : '关闭',
    );
    if (!confirmed || !report.canRepair) return;
    final List<String> applied = await WorldRepair.repair(
      world,
      fallbackName: p.basename(world.path),
      fallbackVersion: widget.entry.minecraftVersion ?? '',
    );
    if (!mounted) return;
    showAppMessage(context, applied.isEmpty ? '没有需要修复的项目。' : applied.join('；'));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '世界管理',
                      style: FluentTheme.of(context).typography.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dir.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              FluentIconButton(
                icon: FluentIcons.refresh,
                tooltip: '刷新',
                onPressed: _reload,
              ),
              FluentIconButton(
                icon: FluentIcons.folder,
                tooltip: '打开 saves',
                onPressed: () {
                  _dir.createSync(recursive: true);
                  PlatformActions.openDirectory(_dir.path);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _worlds.isEmpty
                ? const EmptyState(
                    icon: FluentIcons.globe,
                    title: '没有世界',
                    message: '启动游戏生成存档后，会显示在这里。',
                  )
                : Card(
                    padding: const EdgeInsets.all(6),
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: _worlds.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Divider(),
                      itemBuilder: (BuildContext context, int index) {
                        final Directory world = _worlds[index];
                        final DateTime modified = world.statSync().modified;
                        return ListTile(
                          leading: const Icon(FluentIcons.globe, size: 16),
                          title: Text(p.basename(world.path)),
                          subtitle: Text('修改于 ${formatRelativeTime(modified)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              FluentIconButton(
                                icon: FluentIcons.save,
                                tooltip: '备份',
                                onPressed: () => _backup(world),
                              ),
                              FluentIconButton(
                                icon: FluentIcons.repair,
                                tooltip: '检查并修复',
                                onPressed: () => _repair(world),
                              ),
                              FluentIconButton(
                                icon: FluentIcons.folder,
                                tooltip: '打开',
                                onPressed: () =>
                                    PlatformActions.openDirectory(world.path),
                              ),
                              FluentIconButton(
                                icon: FluentIcons.delete,
                                tooltip: '删除',
                                onPressed: () => _delete(world),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class SkinsPanel extends StatefulWidget {
  const SkinsPanel({super.key, required this.app});

  final AppState app;

  @override
  State<SkinsPanel> createState() => _SkinsPanelState();
}

class _SkinsPanelState extends State<SkinsPanel> {
  List<File> _skins = <File>[];
  File? _selected;
  String _variant = 'classic';
  bool _uploading = false;

  Directory get _dir =>
      Directory(p.join(widget.app.paths.dataDir.path, 'skins'));

  @override
  void initState() {
    super.initState();
    _reload();
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
      // Keep the previous list.
    }
    files.sort((File a, File b) => a.path.compareTo(b.path));
    setState(() {
      _skins = files;
      if (_selected == null && files.isNotEmpty) _selected = files.first;
    });
  }

  Future<void> _addSkin() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: '皮肤图片', extensions: <String>['png', 'jpg', 'jpeg']),
      ],
    );
    if (file == null) return;
    try {
      await _dir.create(recursive: true);
      final File target = File(p.join(_dir.path, file.name));
      await File(file.path).copy(target.path);
      _selected = target;
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '导入失败：${error.message}');
    }
  }

  Future<void> _upload() async {
    final File? file = _selected;
    if (file == null) return;
    if (!widget.app.isAuthenticated) {
      showAppMessage(context, '请先在设置中登录 Microsoft 账户。');
      return;
    }
    if (p.extension(file.path).toLowerCase() != '.png') {
      showAppMessage(context, 'Minecraft 只接受 PNG 皮肤。');
      return;
    }
    setState(() => _uploading = true);
    final String? error = await widget.app.uploadSkin(file, variant: _variant);
    if (!mounted) return;
    setState(() => _uploading = false);
    showAppMessage(context, error ?? '已上传皮肤，重新进入游戏后生效。');
  }

  Future<void> _deleteSkin(File file) async {
    try {
      await file.delete();
      if (_selected?.path == file.path) _selected = null;
      _reload();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showAppMessage(context, '删除失败：${error.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '皮肤',
                      style: FluentTheme.of(context).typography.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selected == null
                          ? '本地皮肤库。'
                          : '本地皮肤库 · ${p.basename(_selected!.path)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selected != null) ...<Widget>[
                SizedBox(
                  width: 128,
                  child: HclComboBox<String>(
                    value: _variant,
                    items: const <ComboBoxItem<String>>[
                      ComboBoxItem<String>(
                        value: 'classic',
                        child: Text('经典（4 格臂）'),
                      ),
                      ComboBoxItem<String>(
                        value: 'slim',
                        child: Text('纤细（3 格臂）'),
                      ),
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
                  icon: FluentIcons.cloud_upload,
                  dense: true,
                  loading: _uploading,
                  onPressed: _uploading ? null : _upload,
                ),
                const SizedBox(width: 8),
              ],
              FluentButton(
                label: '导入皮肤',
                icon: FluentIcons.add,
                dense: true,
                style: FluentButtonStyle.primary,
                onPressed: _addSkin,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 260,
                  child: Card(
                    padding: const EdgeInsets.all(6),
                    margin: EdgeInsets.zero,
                    child: _skins.isEmpty
                        ? Center(
                            child: Text(
                              '没有皮肤',
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
                                onPressed: () => setState(() {
                                  _selected = file;
                                }),
                                title: Text(p.basename(file.path)),
                                trailing: FluentIconButton(
                                  icon: FluentIcons.delete,
                                  tooltip: '删除',
                                  onPressed: () => _deleteSkin(file),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Card(
                    padding: const EdgeInsets.all(18),
                    margin: EdgeInsets.zero,
                    child: _selected == null
                        ? const EmptyState(
                            icon: FluentIcons.photo,
                            title: '选择皮肤',
                            message: '导入一张 PNG 或 JPG 预览。',
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
      ),
    );
  }
}

class CrashPanel extends StatefulWidget {
  const CrashPanel({super.key, required this.entry, required this.app});

  final AppEntry entry;
  final AppState app;

  @override
  State<CrashPanel> createState() => _CrashPanelState();
}

class _CrashPanelState extends State<CrashPanel> {
  final List<CrashFinding> _findings = <CrashFinding>[];
  String? _source;
  bool _loading = false;

  String get _gameDir =>
      VersionIsolation.instanceDir(widget.entry, widget.app.settings);

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _loading = true);
    final CrashSource source = await CrashAnalyzer.collect(_gameDir);
    final List<CrashFinding> findings = CrashAnalyzer().analyze(source.content);
    if (!mounted) return;
    setState(() {
      _findings
        ..clear()
        ..addAll(findings);
      _source = source.primaryPath;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '崩溃分析',
                      style: FluentTheme.of(context).typography.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _source ?? '未找到 latest.log 或 crash-reports',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              FluentButton(
                label: _loading ? '分析中…' : '重新分析',
                icon: FluentIcons.refresh,
                dense: true,
                onPressed: _loading ? null : _analyze,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: ProgressRing(strokeWidth: 2))
                : _findings.isEmpty
                ? EmptyState(
                    icon: FluentIcons.check_mark,
                    title: _source == null ? '没有日志' : '没有发现常见问题',
                    message: _source == null
                        ? '启动过一次游戏并产生日志后再试。'
                        : '日志中没有匹配到已知的崩溃模式。',
                  )
                : ListView.separated(
                    itemCount: _findings.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final CrashFinding finding = _findings[index];
                      final bool warning =
                          finding.severity == CrashSeverity.warning;
                      return Card(
                        padding: const EdgeInsets.all(14),
                        margin: EdgeInsets.zero,
                        borderColor: warning ? palette.accent : palette.warning,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              finding.title,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              finding.suggestion,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
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
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
