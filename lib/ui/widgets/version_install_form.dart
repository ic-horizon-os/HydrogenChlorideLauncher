import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/minecraft/loader_installer.dart' show LoaderBuild, LoaderKind;
import '../../../core/minecraft/version_manifest.dart';
import '../../../core/models/app_entry.dart';
import '../../../core/utils/format.dart';
import '../../../state/app_state.dart';
import '../../../theme/fluent_theme.dart';
import 'fluent_widgets.dart';
import 'hcl_combo_box.dart';

/// Vanilla + optional loader install flow with the two-column version
/// picker and a staged progress readout. Used by the library install
/// dialog and embedded in the browse page's 游戏版本 section.
///
/// [onFinished] replaces the dialog's Navigator.pop: the library pops its
/// route, the browse page just shows a toast.
class VersionInstallForm extends StatefulWidget {
  const VersionInstallForm({
    super.key,
    required this.app,
    this.onFinished,
    this.showCancel = true,
  });

  final AppState app;

  /// Called with the created entry after a successful install. When null
  /// the route is popped with the entry (dialog behaviour).
  final ValueChanged<AppEntry>? onFinished;
  final bool showCancel;

  @override
  State<VersionInstallForm> createState() => _VersionInstallFormState();
}

class _VersionInstallFormState extends State<VersionInstallForm> {
  static const Map<String, LoaderKind?> _loaders = <String, LoaderKind?>{
    '不安装加载器': null,
    'Fabric': LoaderKind.fabric,
    'Forge': LoaderKind.forge,
    'NeoForge': LoaderKind.neoforge,
  };

  String? _selected;
  bool _loading = true;
  String? _error;
  bool _installing = false;
  String _stage = '';
  String _detail = '';
  double _fraction = 0;

  String _loaderChoice = '不安装加载器';
  List<LoaderBuild> _builds = <LoaderBuild>[];
  String? _build;
  bool _loadingBuilds = false;
  String? _buildError;

  LoaderKind? get _loader => _loaders[_loaderChoice];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loader builds for the currently selected game version.
  Future<void> _loadBuilds() async {
    final LoaderKind? loader = _loader;
    final String? version = _selected;
    if (loader == null || version == null) {
      if (!mounted) return;
      setState(() {
        _builds = <LoaderBuild>[];
        _build = null;
        _buildError = null;
        _loadingBuilds = false;
      });
      return;
    }
    setState(() {
      _loadingBuilds = true;
      _buildError = null;
      _builds = <LoaderBuild>[];
      _build = null;
    });
    try {
      final List<LoaderBuild> builds = await widget.app.loaderInstaller
          .listBuilds(loader, version);
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _builds = builds;
        _build = builds.isEmpty ? null : builds.first.loaderVersion;
        if (builds.isEmpty) _buildError = '该版本没有可用的 $loader 构建。';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBuilds = false;
        _buildError = error.toString();
      });
    }
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final VersionManifest manifest = await widget.app.loadManifest(
        force: force,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _selected ??= manifest.latestRelease.isNotEmpty
            ? manifest.latestRelease
            : manifest.releases.firstOrNull?.id;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取版本清单失败：$error';
      });
    }
  }

  Future<void> _install() async {
    final String? version = _selected;
    if (version == null || _installing) return;
    setState(() {
      _installing = true;
      _stage = '准备';
      _detail = '';
      _fraction = 0;
    });
    final AppEntry? created = await widget.app.installVersion(
      version,
      onProgress: (String stage, double fraction, String detail) {
        if (!mounted) return;
        setState(() {
          // The loader install runs after vanilla; show it as a second phase.
          _stage = _loader == null ? stage : '原版 · $stage';
          _fraction = _loader == null ? fraction : fraction * 0.6;
          _detail = detail;
        });
      },
    );
    if (!mounted) return;
    if (created == null) {
      setState(() {
        _installing = false;
        _error = widget.app.lastError ?? '安装失败。';
      });
      return;
    }

    final LoaderKind? loader = _loader;
    final String? build = _build;
    if (loader != null && build != null) {
      final AppEntry? withLoader = await widget.app.installLoader(
        loader,
        version,
        build,
        onProgress: (String stage, double fraction, String detail) {
          if (!mounted) return;
          setState(() {
            _stage = '加载器 · $stage';
            _fraction = 0.6 + fraction * 0.4;
            _detail = detail;
          });
        },
      );
      if (!mounted) return;
      setState(() => _installing = false);
      if (withLoader == null) {
        setState(
          () => _error = '原版已安装，但加载器安装失败：${widget.app.lastError ?? '未知错误'}',
        );
        return;
      }
      _finish(withLoader);
      return;
    }

    setState(() => _installing = false);
    _finish(created);
  }

  void _finish(AppEntry entry) {
    final ValueChanged<AppEntry>? onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished(entry);
    } else {
      Navigator.of(context).pop(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final VersionManifest? manifest = widget.app.manifest;
    final List<VersionManifestEntry> releases =
        manifest?.releases ?? const <VersionManifestEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_loading && manifest == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: ProgressRing(strokeWidth: 2)),
          )
        else
          VersionPicker(
            versions: releases
                .map((VersionManifestEntry entry) => entry.id)
                .toList(growable: false),
            selected: _selected,
            subtitleOf: (String id) {
              final VersionManifestEntry? entry = manifest?.find(id);
              return entry == null
                  ? null
                  : formatRelativeTime(entry.releaseTime);
            },
            onSelected: _installing
                ? (String _) {}
                : (String id) {
                    setState(() => _selected = id);
                    _loadBuilds();
                  },
          ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Text(
              '加载器',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: HclComboBox<String>(
                value: _loaderChoice,
                isExpanded: true,
                items: _loaders.keys
                    .map(
                      (String name) =>
                          ComboBoxItem<String>(value: name, child: Text(name)),
                    )
                    .toList(growable: false),
                onChanged: _installing
                    ? null
                    : (String? value) {
                        if (value == null) return;
                        setState(() => _loaderChoice = value);
                        _loadBuilds();
                      },
              ),
            ),
          ],
        ),
        if (_loader != null) ...<Widget>[
          const SizedBox(height: 10),
          if (_loadingBuilds)
            Text(
              '正在获取加载器构建…',
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            )
          else if (_buildError != null)
            Text(
              _buildError!,
              style: TextStyle(color: palette.danger, fontSize: 11),
            )
          else
            VersionPicker(
              height: 130,
              versions: _builds
                  .map((LoaderBuild build) => build.loaderVersion)
                  .toList(growable: false),
              selected: _build,
              onSelected: _installing
                  ? (String _) {}
                  : (String value) => setState(() => _build = value),
            ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: palette.danger, fontSize: 11.5),
          ),
        ],
        if (_installing) ...<Widget>[
          const SizedBox(height: 16),
          InstallStageProgress(
            stage: _stage,
            detail: _detail,
            fraction: _fraction,
          ),
        ],
        const SizedBox(height: 16),
        if (widget.showCancel)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Button(
                  onPressed: _installing
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _installing || _selected == null ? null : _install,
                  child: Text(_installing ? '安装中…' : '安装'),
                ),
              ],
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: _installing || _selected == null ? null : _install,
              child: Text(_installing ? '安装中…' : '安装版本'),
            ),
          ),
      ],
    );
  }
}
