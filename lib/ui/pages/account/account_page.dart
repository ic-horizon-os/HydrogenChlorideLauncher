import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../core/models/account.dart';
import '../../../core/models/app_entry.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/skin_service.dart';
import '../../../core/utils/format.dart';
import '../../../state/app_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/acrylic_background.dart';
import '../../../theme/fluent_theme.dart';
import '../../widgets/fluent_widgets.dart';
import '../../widgets/hcl_combo_box.dart';
import '../../widgets/skin_preview.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final MinecraftAccount? account = app.auth.account;
    final int totalMs = app.visibleEntries.fold<int>(
      0,
      (int value, AppEntry entry) => value + entry.totalPlayMs,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('账户', style: FluentTheme.of(context).typography.titleLarge),
            ],
          ),
          const SizedBox(height: 20),
          PageBodyEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _AccountHero(account: account, app: app),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columns = constraints.maxWidth >= 900 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.85,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        _QuickCard(
                          icon: Icons.videogame_asset_outlined,
                          title: '库',
                          value: '${app.visibleEntries.length} 个条目',
                          subtitle: '累计 ${formatPlaytime(totalMs)}',
                          onTap: () => app.selectTab(HomeTab.library),
                        ),
                        _QuickCard(
                          icon: Icons.insights_outlined,
                          title: '统计信息',
                          value: formatDuration(
                            app.statsSummary.total,
                            compact: true,
                          ),
                          subtitle: '${app.statsSummary.sessionCount} 次会话',
                          onTap: () =>
                              app.openSettings(SettingsSection.statistics),
                        ),
                        _QuickCard(
                          icon: Icons.extension_outlined,
                          title: '插件',
                          value: '${app.plugins.plugins.length} 个',
                          subtitle:
                              '${app.plugins.plugins.where((plugin) => plugin.enabled).length} 个已启用',
                          onTap: () =>
                              app.openSettings(SettingsSection.plugins),
                        ),
                        _QuickCard(
                          icon: Icons.palette_outlined,
                          title: '个性化',
                          value: switch (app.settings.themeMode) {
                            AppThemeMode.system => '跟随系统',
                            AppThemeMode.light => '亮色',
                            AppThemeMode.dark => '暗色',
                          },
                          subtitle: '背景与强调色',
                          onTap: () =>
                              app.openSettings(SettingsSection.personalization),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _SkinCard(app: app),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.account, required this.app});

  final MinecraftAccount? account;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    if (account == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              palette.surface,
              Color.lerp(palette.surface, palette.accent, 0.16)!,
            ],
          ),
          borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.person_outline,
                size: 30,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '登录 Microsoft 账户',
                    style: FluentTheme.of(context).typography.title,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '登录后才能启动 Minecraft。Alpha 使用真实设备码流程，'
                    '需要先配置 Azure 应用 client ID。',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            FluentButton(
              label: '前往登录设置',
              icon: Icons.login,
              style: FluentButtonStyle.primary,
              onPressed: () => app.openSettings(SettingsSection.account),
            ),
          ],
        ),
      );
    }

    final String initial = account!.name.isEmpty
        ? '?'
        : account!.name.substring(0, 1).toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.surface,
            Color.lerp(palette.surface, palette.accent, 0.2)!,
          ],
        ),
        borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  palette.accent,
                  Color.lerp(palette.accent, Colors.black, 0.38)!,
                ],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  account!.name,
                  style: FluentTheme.of(context).typography.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  account!.gamertag == null
                      ? 'Minecraft 账户'
                      : 'Xbox 玩家代号：${account!.gamertag}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: <Widget>[
                    _Info(
                      label: 'UUID',
                      value: account!.uuid.isEmpty ? '—' : account!.uuid,
                    ),
                    _Info(
                      label: '令牌到期',
                      value: account!.expiresAt == null
                          ? '—'
                          : formatDateTime(account!.expiresAt!),
                    ),
                    _Info(label: '登录方式', value: 'OAuth 2.0 设备码'),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              FluentButton(
                label: '刷新令牌',
                icon: Icons.refresh,
                dense: true,
                onPressed: () async {
                  final String? clientId = app.effectiveClientId;
                  if (clientId == null) {
                    showAppMessage(context, '缺少 client ID，无法刷新令牌。');
                    return;
                  }
                  final bool ok = await app.auth.refreshIfNeeded(
                    clientId: clientId,
                  );
                  if (!context.mounted) return;
                  showAppMessage(
                    context,
                    ok ? '令牌已刷新。' : (app.auth.lastError ?? '刷新失败，请重新登录。'),
                  );
                },
              ),
              const SizedBox(height: 8),
              FluentButton(
                label: '退出登录',
                icon: Icons.logout,
                dense: true,
                style: FluentButtonStyle.ghost,
                onPressed: () async {
                  final bool confirmed = await showConfirmDialog(
                    context: context,
                    title: '退出 Microsoft 账户',
                    message: '退出后，Minecraft 条目将无法启动，直到重新登录。',
                    confirmLabel: '退出',
                    destructive: true,
                  );
                  if (confirmed) await app.logout();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label：',
          style: TextStyle(color: palette.textTertiary, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(color: palette.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

/// 皮肤管理: preview the active profile skin and switch between the
/// player's own skin, a custom PNG, or another premium player's skin.
/// Everything becomes the account skin only after an explicit apply.
class _SkinCard extends StatefulWidget {
  const _SkinCard({required this.app});

  final AppState app;

  @override
  State<_SkinCard> createState() => _SkinCardState();
}

class _SkinCardState extends State<_SkinCard> {
  final TextEditingController _username = TextEditingController();

  File? _previewFile;
  String _previewModel = 'classic';
  String _previewLabel = '';
  bool _pending = false;
  bool _busy = false;
  String _variant = 'classic';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwn());
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  bool get _authenticated => widget.app.isAuthenticated;

  /// Pulls the logged-in player's current profile skin; falls back to the
  /// locally cached texture when offline.
  Future<void> _loadOwn() async {
    final MinecraftAccount? account = widget.app.auth.account;
    if (account == null) return;
    final File? cached = widget.app.skins.cachedSkin(account.uuid);
    if (cached != null && mounted) {
      setState(() {
        _previewFile = cached;
        _previewLabel = '你的当前皮肤（缓存）';
        _pending = false;
      });
    }
    await _fetch(
      () => widget.app.skins.fetchOwnSkin(
        uuid: account.uuid,
        name: account.name,
      ),
      successLabel: '你的当前皮肤',
    );
  }

  Future<void> _loadUser() async {
    await _fetch(
      () => widget.app.skins.fetchUserSkin(_username.text),
      successLabel: '${_username.text.trim()} 的皮肤',
    );
  }

  Future<void> _fetch(
    Future<FetchedSkin> Function() task, {
    required String successLabel,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final FetchedSkin fetched = await task();
      if (!mounted) return;
      setState(() {
        _previewFile = fetched.file;
        _previewModel = fetched.model;
        _previewLabel = successLabel;
        _pending = false;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppMessage(context, '拉取皮肤失败：$error');
    }
  }

  Future<void> _pickCustom() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: '皮肤图片', extensions: <String>['png']),
      ],
    );
    if (file == null) return;
    if (!mounted) return;
    if (!file.path.toLowerCase().endsWith('.png')) {
      showAppMessage(context, 'Minecraft 只接受 PNG 皮肤。');
      return;
    }
    setState(() {
      _previewFile = File(file.path);
      _previewModel = _variant;
      _previewLabel = '自定义皮肤（${_variant == 'slim' ? '纤细' : '经典'}）';
      _pending = true;
    });
  }

  Future<void> _applyPreview() async {
    final File? file = _previewFile;
    if (file == null || _busy) return;
    if (!_authenticated) {
      showAppMessage(context, '请先登录 Microsoft 账户，再应用皮肤。');
      return;
    }
    setState(() => _busy = true);
    final String? error = await widget.app.uploadSkin(
      file,
      variant: _previewModel == 'slim' ? 'slim' : 'classic',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = false;
    });
    showAppMessage(context, error ?? '皮肤已应用到账户，重新进入游戏后生效。');
  }

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.palette_outlined, size: 15, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                '皮肤',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              if (_previewLabel.isNotEmpty)
                Text(
                  _previewLabel,
                  style: TextStyle(color: palette.textTertiary, fontSize: 11),
                ),
              const Spacer(),
              if (_pending)
                MetaPill(
                  label: '未应用',
                  icon: Icons.priority_high_rounded,
                  color: palette.warning,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.subtleFill,
                  borderRadius: BorderRadius.circular(FluentTokens.radius),
                  border: Border.all(color: palette.border),
                ),
                child: SkinPreview(
                  file: _previewFile,
                  model: _previewModel,
                  height: 216,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          '手臂模型',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 130,
                          child: HclComboBox<String>(
                            value: _variant,
                            items: const <ComboBoxItem<String>>[
                              ComboBoxItem<String>(
                                value: 'classic',
                                child: Text('经典'),
                              ),
                              ComboBoxItem<String>(
                                value: 'slim',
                                child: Text('纤细'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value == null) return;
                              setState(() => _variant = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        FluentButton(
                          label: '使用个人皮肤',
                          icon: Icons.person_outline,
                          dense: true,
                          loading: _busy,
                          onPressed: _busy ? null : _loadOwn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextBox(
                            controller: _username,
                            placeholder: '正版玩家名，如 Notch',
                            enabled: !_busy,
                            onSubmitted: (_) => _loadUser(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FluentButton(
                          label: '使用该玩家的皮肤',
                          icon: Icons.groups_2_outlined,
                          dense: true,
                          onPressed: _busy
                              ? null
                              : () {
                                  if (_username.text.trim().isEmpty) {
                                    showAppMessage(context, '请输入玩家名。');
                                    return;
                                  }
                                  _loadUser();
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        FluentButton(
                          label: '上传自定义皮肤',
                          icon: Icons.upload_file_outlined,
                          dense: true,
                          onPressed: _busy ? null : _pickCustom,
                        ),
                        const Spacer(),
                        if (_pending) ...<Widget>[
                          Text(
                            '预览中的皮肤尚未生效',
                            style: TextStyle(
                              color: palette.warning,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          FluentButton(
                            label: '应用到账户',
                            icon: Icons.cloud_upload_outlined,
                            style: FluentButtonStyle.primary,
                            dense: true,
                            loading: _busy,
                            onPressed: _busy ? null : _applyPreview,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '「应用到账户」会把皮肤上传到 Microsoft 账户（Mojang 档案），'
                      '正版与离线实例进入游戏后均使用该皮肤。',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatefulWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          padding: const EdgeInsets.all(14),
          margin: EdgeInsets.zero,
          backgroundColor: _hovered ? palette.hover : palette.surface,
          borderRadius: BorderRadius.circular(FluentTokens.radius),
          borderColor: _hovered
              ? palette.accent.withValues(alpha: 0.35)
              : palette.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(widget.icon, size: 15, color: palette.accent),
                  const SizedBox(width: 7),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
