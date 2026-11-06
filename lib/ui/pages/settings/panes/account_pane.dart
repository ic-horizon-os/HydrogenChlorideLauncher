import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../../../../core/constants.dart';
import '../../../../core/models/account.dart';
import '../../../../core/services/microsoft_auth.dart';
import '../../../../core/services/platform_actions.dart';
import '../../../../core/utils/format.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/fluent_widgets.dart';
import '../settings_widgets.dart';

class AccountPane extends StatefulWidget {
  const AccountPane({super.key});

  @override
  State<AccountPane> createState() => _AccountPaneState();
}

class _AccountPaneState extends State<AccountPane> {
  final TextEditingController _clientId = TextEditingController();
  bool _clientIdLoaded = false;
  bool _busy = false;
  bool _cancelRequested = false;
  DeviceCodeInfo? _deviceInfo;
  String? _status;
  String? _browserUrl;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_clientIdLoaded) {
      _clientIdLoaded = true;
      final AppState app = AppScope.read(context);
      _clientId.text = app.settings.microsoftClientId ?? '';
    }
  }

  @override
  void dispose() {
    _clientId.dispose();
    super.dispose();
  }

  static String _clientIdNote(AppState app) {
    final String current = app.effectiveClientId ?? '';
    if (current.isEmpty) return '未配置：登录前请填写 Azure 应用 ID';
    if (current == AppInfo.defaultMicrosoftClientId) {
      return '内置 ID：可直接登录；也可换成你自己的 Azure 应用';
    }
    return '自定义 ID：令牌只发给你注册的应用';
  }

  Future<void> _saveClientId(AppState app) async {
    await app.setMicrosoftClientId(_clientId.text);
    if (!mounted) return;
    setState(() => _error = null);
    showAppMessage(context, 'client ID 已保存到本机设置。');
  }

  /// Browser sign-in with a loopback redirect: opens the system browser and
  /// waits for Microsoft to call back into the local listener.
  Future<void> _startBrowserLogin(AppState app) async {
    final String clientId = _clientId.text.trim();
    if (clientId.isEmpty) {
      setState(() => _error = '请先填写 Azure 应用 client ID。');
      return;
    }
    await app.setMicrosoftClientId(clientId);
    if (!mounted) return;
    setState(() {
      _busy = true;
      _cancelRequested = false;
      _error = null;
      _status = '正在启动浏览器登录…';
      _deviceInfo = null;
    });

    BrowserSignInTicket? ticket;
    try {
      ticket = await app.beginBrowserLogin(
        onStatus: (String status) {
          if (mounted) setState(() => _status = status);
        },
        isCancelled: () => _cancelRequested,
      );
      final bool opened = await PlatformActions.openExternal(
        ticket.url.toString(),
      );
      if (!mounted) return;
      setState(() {
        _status = opened ? '请在浏览器中完成登录，完成后会自动返回。' : '浏览器没有打开，请手动访问下面的地址。';
        _browserUrl = ticket!.url.toString();
      });
      final MinecraftAccount account = await ticket.finish();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _browserUrl = null;
        _error = null;
      });
      showAppMessage(context, '登录成功：${account.name}');
    } on MicrosoftAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _browserUrl = null;
        _error = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _browserUrl = null;
        _error = '登录失败：$error';
      });
    }
  }

  Future<void> _startLogin(AppState app) async {
    final String clientId = _clientId.text.trim();
    if (clientId.isEmpty) {
      setState(() => _error = '请先填写 Azure 应用 client ID。');
      return;
    }
    await app.setMicrosoftClientId(clientId);
    if (!mounted) return;
    setState(() {
      _busy = true;
      _cancelRequested = false;
      _error = null;
      _status = '正在向 Microsoft 请求设备码…';
      _deviceInfo = null;
    });

    try {
      final DeviceCodeInfo info = await app.beginLogin();
      if (!mounted) return;
      setState(() {
        _deviceInfo = info;
        _status = '等待你在浏览器中确认登录…';
      });
      unawaited(_poll(app, info));
    } on MicrosoftAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = '登录失败：$error';
      });
    }
  }

  Future<void> _poll(AppState app, DeviceCodeInfo info) async {
    try {
      final MinecraftAccount? account = await app.completeLogin(
        info,
        onStatus: (String status) {
          if (mounted) setState(() => _status = status);
        },
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _deviceInfo = null;
        _status = null;
        _error = null;
      });
      if (account != null) {
        showAppMessage(context, '登录成功：${account.name}');
      }
    } on MicrosoftAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _deviceInfo = null;
        _status = null;
        _error = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _deviceInfo = null;
        _status = null;
        _error = '登录失败：$error';
      });
    }
  }

  void _cancel() {
    setState(() {
      _cancelRequested = true;
      _status = '正在取消登录…';
    });
  }

  Future<void> _refresh(AppState app) async {
    final String? clientId = app.effectiveClientId;
    if (clientId == null) {
      setState(() => _error = '缺少 client ID，无法刷新令牌。');
      return;
    }
    final bool ok = await app.auth.refreshIfNeeded(clientId: clientId);
    if (!mounted) return;
    setState(() => _error = ok ? null : app.auth.lastError);
    showAppMessage(context, ok ? '令牌仍有效。' : (app.auth.lastError ?? '刷新失败。'));
  }

  Future<void> _logout(AppState app) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '退出 Microsoft 账户',
      message: '退出后会删除本机保存的令牌。未登录时禁止启动 Minecraft。',
      confirmLabel: '退出',
      destructive: true,
    );
    if (!confirmed) return;
    await app.logout();
    if (!mounted) return;
    showAppMessage(context, '已退出 Microsoft 账户。');
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final MinecraftAccount? account = app.auth.account;
    final String? envClientId =
        Platform.environment[AppInfo.microsoftClientIdEnv];
    final bool usingEnv =
        (app.settings.microsoftClientId ?? '').isEmpty && envClientId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '登录信息',
          description: 'Microsoft 账户与 Minecraft 登录。未登录时不能启动 Minecraft。',
          trailing: MetaPill(
            label: account == null ? '未登录' : '已登录',
            icon: account == null
                ? Icons.person_outline
                : Icons.verified_user_outlined,
            color: account == null ? palette.warning : palette.success,
          ),
        ),
        const SizedBox(height: 18),
        SettingsBanner(
          message:
              '点「使用设备码登录」，启动器会给出一组代码；'
              '打开 microsoft.com/link 输入即可完成登录。',
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          SettingsBanner(
            message: _error!,
            icon: Icons.error_outline,
            tone: SettingsBannerTone.danger,
          ),
        ],
        if (_deviceInfo != null) ...<Widget>[
          const SizedBox(height: 16),
          _DeviceCodeCard(
            info: _deviceInfo!,
            status: _status,
            onCancel: _cancel,
          ),
        ],
        if (account == null) ...<Widget>[
          const SizedBox(height: 18),
          SettingsCard(
            title: 'Azure 应用 client ID',
            description:
                '默认使用内置 client ID，无需配置即可登录。'
                '也可换成你自己的 Azure 应用：账户类型选「仅个人 Microsoft 账户」，'
                '并在 Authentication 中开启“Allow public client flows”。',
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextBox(
                          controller: _clientId,
                          placeholder:
                              '例如 00000000-0000-0000-0000-000000000000',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          usingEnv
                              ? '当前正在使用环境变量 ${AppInfo.microsoftClientIdEnv}。'
                              : '也可以设置环境变量 ${AppInfo.microsoftClientIdEnv}。',
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FluentButton(
                    label: '保存',
                    dense: true,
                    onPressed: () => _saveClientId(app),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  FluentButton(
                    label: _busy ? '等待登录…' : '使用设备码登录',
                    icon: Icons.login,
                    style: FluentButtonStyle.primary,
                    loading: _busy,
                    onPressed: _busy ? null : () => _startLogin(app),
                  ),
                  const SizedBox(width: 10),
                  FluentButton(
                    label: '浏览器登录',
                    icon: Icons.public,
                    dense: true,
                    onPressed: _busy ? null : () => _startBrowserLogin(app),
                  ),
                  const SizedBox(width: 10),
                  FluentButton(
                    label: '如何配置？',
                    icon: Icons.help_outline,
                    style: FluentButtonStyle.ghost,
                    onPressed: () => showAppMessage(
                      context,
                      'Azure Portal → App registrations → 新建注册 → '
                      'Authentication → 添加平台「移动和桌面应用程序」→ '
                      '勾选 http://localhost；并开启 Allow public client flows。',
                    ),
                  ),
                ],
              ),
              if (_status != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
              if (_browserUrl != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  _browserUrl!,
                  style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
                ),
              ],
              if (_busy) ...<Widget>[
                const SizedBox(height: 10),
                FluentButton(label: '取消登录', dense: true, onPressed: _cancel),
              ],
            ],
          ),
        ] else ...<Widget>[
          const SizedBox(height: 18),
          _SignedInCard(
            account: account,
            onRefresh: () => _refresh(app),
            onLogout: () => _logout(app),
          ),
          if (!account.ownsMinecraft) ...<Widget>[
            const SizedBox(height: 12),
            const SettingsBanner(
              message:
                  '该账户已通过 Xbox 验证，但没有 Minecraft: Java Edition 档案。'
                  'Alpha 会允许登录，但真实启动前仍需要拥有游戏。',
              icon: Icons.warning_amber_rounded,
              tone: SettingsBannerTone.warning,
            ),
          ],
          if (account.isExpired) ...<Widget>[
            const SizedBox(height: 12),
            const SettingsBanner(
              message: 'Minecraft 访问令牌已过期。请点击“刷新令牌”，或重新登录。',
              icon: Icons.schedule,
              tone: SettingsBannerTone.warning,
            ),
          ],
          const SizedBox(height: 18),
          SettingsCard(
            title: 'client ID 与令牌存储',
            children: <Widget>[
              SettingsRow(
                title: 'Azure client ID',
                subtitle:
                    '${app.effectiveClientId ?? '未配置'}\n'
                    '${_clientIdNote(app)}',
                trailing: MetaPill(
                  label: usingEnv
                      ? '环境变量'
                      : app.settings.microsoftClientId ==
                            AppInfo.defaultMicrosoftClientId
                      ? '内置'
                      : '本机设置',
                  dense: true,
                ),
              ),
              SettingsDivider(),
              SettingsRow(
                title: '令牌文件',
                subtitle: app.paths.accountFile.path,
                trailing: FluentButton(
                  label: '打开目录',
                  dense: true,
                  onPressed: () =>
                      PlatformActions.openDirectory(app.paths.configDir.path),
                ),
              ),
              const SizedBox(height: 8),
              SettingsBanner(
                message:
                    '令牌保存在权限为 0600 的本地文件，暂未使用系统钥匙串。'
                    '共享设备上请在用完后退出登录。',
                icon: Icons.security_outlined,
                tone: SettingsBannerTone.warning,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextBox(
                      controller: _clientId,
                      placeholder: '更新 Azure client ID',
                    ),
                  ),
                  const SizedBox(width: 8),
                  FluentButton(
                    label: '保存',
                    dense: true,
                    onPressed: () => _saveClientId(app),
                  ),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        SettingsCard(
          title: '启动门禁',
          children: <Widget>[
            SettingsRow(
              title: '未登录时禁止启动 Minecraft',
              subtitle: '自定义程序与实用软件不受影响；Minecraft 与整合包需要登录。',
              leading: Icon(
                account == null ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 16,
                color: account == null ? palette.warning : palette.success,
              ),
              trailing: MetaPill(
                label: account == null ? '已启用' : '已满足',
                color: account == null ? palette.warning : palette.success,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceCodeCard extends StatelessWidget {
  const _DeviceCodeCard({
    required this.info,
    required this.status,
    required this.onCancel,
  });

  final DeviceCodeInfo info;
  final String? status;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
        border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.phonelink_lock_outlined,
                size: 16,
                color: palette.accent,
              ),
              const SizedBox(width: 8),
              Text(
                '设备码登录',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              MetaPill(
                label: '${info.expiresIn.inMinutes} 分钟内有效',
                icon: Icons.schedule,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '在浏览器打开以下地址，并输入设备码：',
            style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  info.verificationUri,
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FluentButton(
                label: '打开浏览器',
                icon: Icons.open_in_new,
                dense: true,
                onPressed: () =>
                    PlatformActions.openExternal(info.verificationUri),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.background.withValues(
                    alpha: palette.isDark ? 0.4 : 0.7,
                  ),
                  borderRadius: BorderRadius.circular(FluentTokens.radius),
                  border: Border.all(color: palette.border),
                ),
                child: SelectableText(
                  info.userCode,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FluentIconButton(
                icon: Icons.copy,
                tooltip: '复制设备码',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: info.userCode));
                  showAppMessage(context, '已复制设备码。');
                },
              ),
              const Spacer(),
              FluentButton(
                label: '取消登录',
                style: FluentButtonStyle.ghost,
                dense: true,
                onPressed: onCancel,
              ),
            ],
          ),
          if (status != null) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: ProgressRing(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  status!,
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.account,
    required this.onRefresh,
    required this.onLogout,
  });

  final MinecraftAccount account;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    final String initial = account.name.isEmpty
        ? '?'
        : account.name.substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
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
            width: 58,
            height: 58,
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
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      account.name,
                      style: FluentTheme.of(context).typography.title,
                    ),
                    const SizedBox(width: 8),
                    MetaPill(
                      label: account.ownsMinecraft
                          ? 'Minecraft 档案正常'
                          : '无 Minecraft 档案',
                      color: account.ownsMinecraft
                          ? palette.success
                          : palette.warning,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  account.gamertag == null
                      ? 'Microsoft 账户'
                      : 'Xbox 玩家代号：${account.gamertag}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 5,
                  children: <Widget>[
                    Text(
                      'UUID：${account.uuid.isEmpty ? '—' : account.uuid}',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '到期：${account.expiresAt == null ? '—' : formatDateTime(account.expiresAt!)}',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              FluentButton(
                label: '刷新令牌',
                icon: Icons.refresh,
                dense: true,
                onPressed: onRefresh,
              ),
              const SizedBox(height: 8),
              FluentButton(
                label: '退出登录',
                icon: Icons.logout,
                dense: true,
                style: FluentButtonStyle.ghost,
                onPressed: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
