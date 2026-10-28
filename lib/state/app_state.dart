import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:path/path.dart' show join;

import '../core/config/app_paths.dart';
import '../core/constants.dart';
import '../core/minecraft/download_manager.dart';
import '../core/minecraft/download_source.dart';
import '../core/minecraft/java_runtime_manager.dart';
import '../core/minecraft/loader_installer.dart';
import '../core/minecraft/minecraft_installer.dart';
import '../core/minecraft/modrinth_client.dart';
import '../core/models/account.dart';
import '../core/models/app_entry.dart';
import '../core/models/app_settings.dart';
import '../core/models/browse_item.dart';
import '../core/models/feed.dart';
import '../core/models/java_runtime.dart';
import '../core/models/plugin_manifest.dart';
import '../core/minecraft/version_manifest.dart';
import '../core/services/app_task.dart';
import '../core/services/browse_repository.dart';
import '../core/services/core_bridge.dart';
import '../core/services/cover_art_service.dart';
import '../core/services/feed_store.dart';
import '../core/services/launch_service.dart';
import '../core/services/install_host_adapter.dart';
import 'package:hcl_plugin_installer/installer_module.dart' as plugin;
import '../core/services/install_module_registry.dart';
import '../core/services/library_store.dart';
import '../core/services/microsoft_auth.dart';
import '../core/services/plugin_registry.dart';
import '../core/services/settings_store.dart';
import '../core/services/stats_service.dart';
import '../core/services/token_vault.dart';
import '../core/services/version_isolation.dart';
import '../core/services/version_scanner.dart';
import '../core/services/update_service.dart';

enum HomeTab { browse, library, community, account }

enum SettingsSection {
  account,
  personalization,
  plugins,
  java,
  versions,
  skins,
  statistics,
  about,
}

extension SettingsSectionLabel on SettingsSection {
  String get label {
    switch (this) {
      case SettingsSection.account:
        return '登录信息';
      case SettingsSection.personalization:
        return '个性化';
      case SettingsSection.plugins:
        return '插件管理';
      case SettingsSection.java:
        return 'Java 设置';
      case SettingsSection.versions:
        return '版本管理';
      case SettingsSection.skins:
        return '皮肤';
      case SettingsSection.statistics:
        return '统计信息';
      case SettingsSection.about:
        return '关于';
    }
  }

  String get description {
    switch (this) {
      case SettingsSection.account:
        return 'Microsoft 账户与 Minecraft 正版登录';
      case SettingsSection.personalization:
        return '主题、背景、明暗色与强调色';
      case SettingsSection.plugins:
        return '管理启动器插件与声明式页面';
      case SettingsSection.java:
        return 'Java 运行时、内存与 JVM 参数';
      case SettingsSection.versions:
        return '游戏版本、存储占用与最后启动时间';
      case SettingsSection.skins:
        return '全局皮肤库与上传';
      case SettingsSection.statistics:
        return '运行时长分布与可视化';
      case SettingsSection.about:
        return '开源许可、GitHub 与免责声明';
    }
  }
}

class AppState extends ChangeNotifier {
  AppState._({
    required this.paths,
    required this.settings,
    required this.library,
    required this.stats,
    required this.feeds,
    required this.plugins,
    required this.auth,
    required this.launcher,
    required this.core,
    required this.browse,
    required this.modrinth,
    required this.downloader,
    required this.updates,
    required this.covers,
    required this.installModules,
  });

  static Future<AppState> bootstrap({
    AppPaths? paths,
    CoreBridge? coreBridge,
    http.Client? httpClient,
    bool scanJavaOnStart = true,
  }) async {
    final AppPaths resolvedPaths = paths ?? AppPaths.platform();
    await resolvedPaths.ensure();
    final AppSettings settings = await SettingsStore(resolvedPaths).load();
    final LibraryStore library = LibraryStore(resolvedPaths);
    final StatsService stats = StatsService(resolvedPaths);
    final CoreBridge core = coreBridge ?? CoreBridge();
    final DownloadManager downloader = DownloadManager(client: httpClient);
    final FeedStore feeds = FeedStore(resolvedPaths, downloader: downloader);
    final PluginRegistry plugins = PluginRegistry(resolvedPaths);
    final TokenVault vault = TokenVault(paths: resolvedPaths, core: core);
    final MicrosoftAuthService auth = MicrosoftAuthService(
      paths: resolvedPaths,
      vault: vault,
      client: httpClient,
    );

    await library.load();
    await stats.load();
    await feeds.load();
    await plugins.load(includeDemo: settings.demoData);
    if (settings.demoData) {
      await library.addDemoEntries();
      await stats.addDemoSessions();
      await feeds.addDemoSources();
    }
    await auth.load();

    final AppState state = AppState._(
      paths: resolvedPaths,
      settings: settings,
      library: library,
      stats: stats,
      feeds: feeds,
      plugins: plugins,
      auth: auth,
      launcher: LaunchService(library: library, stats: stats),
      core: core,
      browse: BrowseRepository(),
      modrinth: ModrinthClient(downloader: downloader),
      downloader: downloader,
      updates: UpdateService(currentVersion: AppInfo.version),
      covers: CoverArtService(paths: resolvedPaths, downloader: downloader),
      installModules: InstallModuleRegistry(resolvedPaths),
    );
    state.installModules
      ..register(const BuiltinInstallerModule())
      ..addListener(state._childChanged);
    await state.installModules.load();
    state._vault = vault;

    library.addListener(state._childChanged);
    stats.addListener(state._childChanged);
    feeds.addListener(state._childChanged);
    plugins.addListener(state._childChanged);
    auth.addListener(state._childChanged);
    state.launcher.addListener(state._childChanged);
    state._selectDefaults();

    if (scanJavaOnStart) {
      unawaited(state.scanJava());
    }
    unawaited(state.ensureCoverArt());
    unawaited(state.scanVersions());
    if (auth.isLoggedIn && auth.account!.isExpired) {
      final String? clientId = state.effectiveClientId;
      if (clientId != null) {
        unawaited(auth.refreshIfNeeded(clientId: clientId));
      }
    }
    return state;
  }

  final AppPaths paths;
  final LibraryStore library;
  final StatsService stats;
  final FeedStore feeds;
  final PluginRegistry plugins;
  final MicrosoftAuthService auth;
  final LaunchService launcher;
  final CoreBridge core;
  final BrowseRepository browse;
  final ModrinthClient modrinth;
  final DownloadManager downloader;
  final UpdateService updates;
  final CoverArtService covers;
  final InstallModuleRegistry installModules;

  /// Whether the built-in installer module is enabled.
  bool get installModuleEnabled =>
      installModules.supportsVanilla || installModules.supportsLoader;
  late final TokenVault _vault;

  TokenVault get vault => _vault;

  AppSettings settings;

  HomeTab tab = HomeTab.browse;
  final List<HomeTab> _tabHistory = <HomeTab>[HomeTab.browse];
  int _tabHistoryIndex = 0;
  bool settingsOpen = false;
  SettingsSection settingsSection = SettingsSection.account;

  String? librarySelectionId;
  String? communitySourceId;
  String? communityArticleId;
  String? lastError;

  List<JavaRuntime> javaRuntimes = <JavaRuntime>[];

  /// Long-running installs shown in the Steam-style bottom bar.
  final List<AppTask> tasks = <AppTask>[];

  /// Active or recently finished task driving the bottom progress bar.
  AppTask? get activeTask {
    for (final AppTask task in tasks.reversed) {
      if (task.running) return task;
    }
    return null;
  }

  AppTask beginTask(String title) {
    final AppTask task = AppTask(title: title);
    tasks.add(task);
    notifyListeners();
    return task;
  }

  void updateTask(AppTask task) => notifyListeners();

  void finishTask(AppTask task, {bool success = true, String? error}) {
    task
      ..running = false
      ..fraction = 1
      ..error = error
      ..success = success;
    tasks.removeWhere(
      (AppTask t) =>
          !t.running && t != task && tasks.indexOf(t) < tasks.length - 4,
    );
    notifyListeners();
  }

  void dismissTask(AppTask task) {
    tasks.remove(task);
    notifyListeners();
  }

  /// Versions found across every configured `.minecraft` directory.
  List<InstalledVersion> installedVersions = <InstalledVersion>[];
  bool scanningVersions = false;
  String javaBackend = '检测中…';
  bool scanningJava = false;
  StatsFilter statsFilter = const StatsFilter();

  bool _disposed = false;

  void _childChanged() {
    if (!_disposed) notifyListeners();
  }

  void _selectDefaults() {
    final List<AppEntry> entries = visibleEntries;
    if (entries.isNotEmpty) {
      librarySelectionId ??= entries.first.id;
    }
    final List<FeedSource> sources = visibleFeedSources;
    if (sources.isNotEmpty) {
      communitySourceId ??= sources.first.id;
      final List<FeedArticle> articles = feeds.articlesFor(
        communitySourceId!,
        includeDemo: settings.demoData,
      );
      if (articles.isNotEmpty) {
        communityArticleId ??= articles.first.id;
      }
    }
  }

  String? get effectiveClientId {
    final String? fromSettings = settings.microsoftClientId;
    if (fromSettings != null && fromSettings.trim().isNotEmpty) {
      return fromSettings.trim();
    }
    final String fromEnv =
        Platform.environment[AppInfo.microsoftClientIdEnv] ?? '';
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
    return null;
  }

  List<AppEntry> get visibleEntries {
    final List<AppEntry> entries = library.entries
        .where((AppEntry entry) => settings.demoData || !entry.isDemo)
        .toList(growable: false);
    final List<AppEntry> sorted = List<AppEntry>.of(entries);
    sorted.sort((AppEntry a, AppEntry b) {
      final DateTime? left = a.lastPlayed;
      final DateTime? right = b.lastPlayed;
      if (left != null && right != null) {
        final int byDate = right.compareTo(left);
        if (byDate != 0) return byDate;
      } else if (left != null) {
        return -1;
      } else if (right != null) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  AppEntry? get selectedEntry {
    final List<AppEntry> entries = visibleEntries;
    if (entries.isEmpty) return null;
    for (final AppEntry entry in entries) {
      if (entry.id == librarySelectionId) return entry;
    }
    return entries.first;
  }

  List<FeedSource> get visibleFeedSources =>
      feeds.visibleSources(settings.demoData);

  FeedSource? get selectedFeedSource {
    final List<FeedSource> sources = visibleFeedSources;
    if (sources.isEmpty) return null;
    for (final FeedSource source in sources) {
      if (source.id == communitySourceId) return source;
    }
    return sources.first;
  }

  List<FeedArticle> get currentArticles {
    final FeedSource? source = selectedFeedSource;
    if (source == null) return const <FeedArticle>[];
    return feeds.articlesFor(source.id, includeDemo: settings.demoData);
  }

  FeedArticle? get selectedArticle {
    final List<FeedArticle> articles = currentArticles;
    if (articles.isEmpty) return null;
    for (final FeedArticle article in articles) {
      if (article.id == communityArticleId) return article;
    }
    return articles.first;
  }

  StatsSummary get statsSummary =>
      stats.summary(includeDemo: settings.demoData, filter: statsFilter);

  bool get isAuthenticated => auth.isLoggedIn;

  String get accountDisplayName => auth.account?.name ?? '登录';

  bool get canGoBack => _tabHistoryIndex > 0;

  bool get canGoForward => _tabHistoryIndex < _tabHistory.length - 1;

  void selectTab(HomeTab next) {
    if (next == tab) return;
    if (_tabHistoryIndex < _tabHistory.length - 1) {
      _tabHistory.removeRange(_tabHistoryIndex + 1, _tabHistory.length);
    }
    _tabHistory.add(next);
    _tabHistoryIndex = _tabHistory.length - 1;
    if (_tabHistory.length > 24) {
      _tabHistory.removeAt(0);
      _tabHistoryIndex--;
    }
    tab = next;
    if (next == HomeTab.community) _selectDefaults();
    notifyListeners();
  }

  void goBack() {
    if (!canGoBack) return;
    _tabHistoryIndex--;
    tab = _tabHistory[_tabHistoryIndex];
    if (tab == HomeTab.community) _selectDefaults();
    notifyListeners();
  }

  void goForward() {
    if (!canGoForward) return;
    _tabHistoryIndex++;
    tab = _tabHistory[_tabHistoryIndex];
    if (tab == HomeTab.community) _selectDefaults();
    notifyListeners();
  }

  void openSettings([SettingsSection? section]) {
    if (section != null) settingsSection = section;
    settingsOpen = true;
    notifyListeners();
  }

  void closeSettings() {
    settingsOpen = false;
    notifyListeners();
  }

  void selectSettingsSection(SettingsSection section) {
    settingsSection = section;
    notifyListeners();
  }

  void focusAccountLogin() {
    settingsSection = SettingsSection.account;
    settingsOpen = true;
    notifyListeners();
  }

  void selectLibraryEntry(String id) {
    librarySelectionId = id;
    notifyListeners();
  }

  void selectFeedSource(String id) {
    communitySourceId = id;
    final List<FeedArticle> articles = feeds.articlesFor(
      id,
      includeDemo: settings.demoData,
    );
    communityArticleId = articles.isEmpty ? null : articles.first.id;
    notifyListeners();
  }

  Future<void> selectArticle(String id) async {
    communityArticleId = id;
    notifyListeners();
    await feeds.markRead(id);
  }

  Future<void> updateSettings(AppSettings next, {bool persist = true}) async {
    final bool demoChanged = next.demoData != settings.demoData;
    settings = next;
    if (persist) {
      await SettingsStore(paths).save(settings);
    }
    if (demoChanged) {
      if (settings.demoData) {
        await library.addDemoEntries();
        await stats.addDemoSessions();
        await feeds.addDemoSources();
      } else {
        await library.removeDemoEntries();
        await stats.removeDemoSessions();
        await feeds.removeDemoSources();
        if (librarySelectionId != null &&
            library.byId(librarySelectionId!) == null) {
          librarySelectionId = null;
        }
      }
      await plugins.load(includeDemo: settings.demoData);
      _selectDefaults();
    }
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      updateSettings(settings.copyWith(themeMode: mode));

  Future<void> setAccentColor(int color) =>
      updateSettings(settings.copyWith(accentColorValue: color));

  Future<void> setBackgroundImage(String? path) =>
      updateSettings(settings.copyWith(backgroundImagePath: path));

  Future<void> setBackgroundOpacity(double value) =>
      updateSettings(settings.copyWith(backgroundOpacity: value));

  Future<void> setBackgroundBlur(bool enabled) =>
      updateSettings(settings.copyWith(backgroundBlur: enabled));

  Future<void> setBackgroundBlurMode(BackgroundBlurMode mode) =>
      updateSettings(settings.copyWith(backgroundBlurMode: mode));

  Future<void> setDemoData(bool enabled) =>
      updateSettings(settings.copyWith(demoData: enabled));

  Future<void> setMicrosoftClientId(String? value) => updateSettings(
    settings.copyWith(
      microsoftClientId: value == null || value.trim().isEmpty
          ? null
          : value.trim(),
    ),
  );

  Future<void> setDefaultJavaPath(String? path) =>
      updateSettings(settings.copyWith(defaultJavaPath: path));

  Future<void> setDefaultMemory(int megabytes) =>
      updateSettings(settings.copyWith(defaultMemoryMb: megabytes));

  Future<void> setDefaultJvmArgs(String arguments) =>
      updateSettings(settings.copyWith(defaultJvmArgs: arguments));

  Future<void> setMinecraftDirs(List<String> directories) async {
    await updateSettings(settings.copyWith(minecraftDirs: directories));
    await scanVersions();
  }

  Future<void> setMetaDownloadSource(DownloadSource source) =>
      updateSettings(settings.copyWith(metaDownloadSource: source));

  Future<void> setFileDownloadSource(DownloadSource source) =>
      updateSettings(settings.copyWith(fileDownloadSource: source));

  Future<void> setAutoDownloadJava(bool enabled) =>
      updateSettings(settings.copyWith(autoDownloadJava: enabled));

  Future<void> setUpdates({String? manifestUrl, bool? checkOnStart}) =>
      updateSettings(
        settings.copyWith(
          updateManifestUrl: manifestUrl,
          checkUpdatesOnStart: checkOnStart,
        ),
      );

  /// Downloads the official Minecraft key art used as the library banner.
  /// Failures are ignored: the banner falls back to its drawn gradient.
  /// Rescans all configured Minecraft directories. Safe to call often.
  Future<void> scanVersions() async {
    if (scanningVersions) return;
    scanningVersions = true;
    notifyListeners();
    try {
      installedVersions = await VersionScanner.scan(settings.minecraftDirs);
    } on Object {
      installedVersions = <InstalledVersion>[];
    }
    scanningVersions = false;
    notifyListeners();
  }

  Future<void> ensureCoverArt() async {
    try {
      await covers.ensure();
      notifyListeners();
    } on Object {
      // Offline or blocked network: keep the placeholder artwork.
    }
  }

  /// Builds the module context for one install run.
  InstallHostAdapter _moduleContext(
    AppTask task, {
    void Function(String stage, double fraction, String detail)? onProgress,
    required Future<String?> Function(String version) downloader,
    Future<String?> Function(String loader, String game, String build)?
    loader,
    Future<String?> Function(String pack, String dir)? modpack,
  }) {
    return InstallHostAdapter(
      root: minecraftRoot,
      onProgress: (String stage, double fraction, String detail) {
        task.update(stage: stage, detail: detail, fraction: fraction);
        updateTask(task);
        onProgress?.call(stage, fraction, detail);
      },
      downloadVanilla: downloader,
      installLoader:
          loader ?? (String _, String _, String _) async => null,
      installModpackHandler: modpack ?? (String _, String _) async => null,
    );
  }

  Future<void> scanJava() async {
    if (scanningJava) return;
    scanningJava = true;
    notifyListeners();
    final JavaScanResult result = await core.scanJava();
    javaRuntimes = List<JavaRuntime>.of(result.runtimes);
    javaBackend = result.backend;
    scanningJava = false;
    notifyListeners();
  }

  /// Launch progress shown by the library hero button while Java resolves
  /// and the process starts. Null when idle.
  String? launchStage;
  double launchFraction = 0;
  bool _launching = false;

  bool get launching => _launching;

  /// Game directory for an entry, respecting version isolation.
  String gameDirectory(AppEntry entry) =>
      VersionIsolation.instanceDir(entry, settings);

  String get minecraftRoot => settings.minecraftDirs.isNotEmpty
      ? settings.minecraftDirs.first
      : AppPaths.defaultMinecraftDir();

  DownloadMirror get downloadMirror => settings.mirror;

  MinecraftInstaller get vanillaInstaller => MinecraftInstaller(
    root: minecraftRoot,
    mirror: downloadMirror,
    downloader: downloader,
  );

  LoaderInstaller get loaderInstaller => LoaderInstaller(
    root: minecraftRoot,
    mirror: downloadMirror,
    downloader: downloader,
  );

  JavaRuntimeManager javaManagerFor(String root) => JavaRuntimeManager(
    root: root,
    mirror: downloadMirror,
    downloader: downloader,
  );

  LaunchContext get launchContext => LaunchContext(
    settings: settings,
    account: auth.account,
    javaRuntimes: javaRuntimes,
    javaManagerFor: javaManagerFor,
  );

  Future<void> launch(AppEntry entry) async {
    if (_launching) return;
    lastError = null;
    try {
      if (entry.isMinecraft) {
        final String? problem = await auth.prepareForLaunch(
          clientId: effectiveClientId,
        );
        if (problem != null) {
          lastError = problem;
          focusAccountLogin();
          notifyListeners();
          return;
        }
      }
      _launching = true;
      launchStage = entry.isMinecraft ? '检查版本与 Java' : '启动进程';
      launchFraction = 0.05;
      notifyListeners();
      await launcher.start(
        entry,
        authenticated: isAuthenticated,
        context: launchContext,
        onProgress: (String stage, double fraction) {
          launchStage = stage;
          launchFraction = fraction;
          notifyListeners();
        },
      );
      notifyListeners();
    } on NotAuthenticatedException catch (error) {
      lastError = error.toString();
      focusAccountLogin();
    } on StateError catch (error) {
      lastError = error.message;
      notifyListeners();
    } on Object catch (error) {
      lastError = error.toString();
      notifyListeners();
    } finally {
      _launching = false;
      launchStage = null;
      launchFraction = 0;
      notifyListeners();
    }
  }

  Future<void> stopActive() async {
    await launcher.stop();
    notifyListeners();
  }

  /// Starts the browser (loopback) sign-in used by PCL2/HMCL. The caller
  /// opens [BrowserSignInTicket.url] and then awaits [BrowserSignInTicket.finish].
  Future<BrowserSignInTicket> beginBrowserLogin({
    void Function(String status)? onStatus,
    bool Function()? isCancelled,
  }) async {
    final String? clientId = effectiveClientId;
    if (clientId == null) {
      throw const MicrosoftAuthException(
        '请填写 Azure 应用 client ID，或设置 HCL_MS_CLIENT_ID 环境变量。',
        code: 'missing_client_id',
      );
    }
    return auth.beginBrowserSignIn(
      clientId,
      onStatus: onStatus,
      isCancelled: isCancelled,
    );
  }

  Future<DeviceCodeInfo> beginLogin() async {
    final String? clientId = effectiveClientId;
    if (clientId == null) {
      throw const MicrosoftAuthException(
        '请填写 Azure 应用 client ID，或设置 HCL_MS_CLIENT_ID 环境变量。',
        code: 'missing_client_id',
      );
    }
    return auth.requestDeviceCode(clientId);
  }

  Future<MinecraftAccount?> completeLogin(
    DeviceCodeInfo info, {
    void Function(String status)? onStatus,
    bool Function()? isCancelled,
  }) async {
    final String? clientId = effectiveClientId;
    if (clientId == null) return null;
    try {
      final MinecraftAccount account = await auth.waitForLogin(
        info,
        clientId: clientId,
        onStatus: onStatus,
        isCancelled: isCancelled,
      );
      lastError = null;
      notifyListeners();
      if (!account.ownsMinecraft) {
        lastError = '登录成功，但该账户没有 Minecraft: Java Edition 档案。';
      }
      return account;
    } on MicrosoftAuthException catch (error) {
      lastError = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await auth.logout();
    notifyListeners();
  }

  Future<void> reloadPlugins() => plugins.load(includeDemo: settings.demoData);

  Future<void> setPluginEnabled(String id, bool enabled) =>
      plugins.setEnabled(id, enabled);

  Future<PluginManifest?> installPlugin(Directory directory) async {
    try {
      final PluginManifest manifest = await plugins.installFromDirectory(
        directory,
      );
      lastError = null;
      notifyListeners();
      return manifest;
    } on FormatException catch (error) {
      lastError = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> uninstallPlugin(String id) async {
    try {
      await plugins.uninstall(id);
      lastError = null;
      notifyListeners();
    } on FormatException catch (error) {
      lastError = error.message;
      notifyListeners();
    }
  }

  Future<void> addFeed({
    required String title,
    required String url,
    required bool isFeed,
  }) async {
    final FeedSource source = await feeds.addSource(
      title: title,
      url: url,
      isFeed: isFeed,
    );
    communitySourceId = source.id;
    communityArticleId = null;
    _selectDefaults();
    notifyListeners();
  }

  Future<void> addEntry(AppEntry entry) async {
    await library.add(entry);
    librarySelectionId = entry.id;
    notifyListeners();
  }

  Future<void> updateEntry(AppEntry entry) async {
    await library.update(entry);
    notifyListeners();
  }

  Future<void> removeEntry(String id) async {
    if (launcher.activeApp?.id == id) return;
    await library.remove(id);
    if (librarySelectionId == id) {
      librarySelectionId = null;
      _selectDefaults();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- 版本安装

  VersionManifest? _manifest;

  VersionManifest? get manifest => _manifest;

  Future<VersionManifest> loadManifest({bool force = false}) async {
    final VersionManifest manifest = await vanillaInstaller.fetchManifest(
      force: force,
    );
    _manifest = manifest;
    notifyListeners();
    return manifest;
  }

  /// Installs a vanilla version and adds a library entry for it.
  Future<AppEntry?> installVersion(
    String versionId, {
    void Function(String stage, double fraction, String detail)? onProgress,
  }) async {
    lastError = null;
    notifyListeners();
    if (!installModuleEnabled) {
      lastError = '安装模块已停用，请在「插件管理」中启用。';
      notifyListeners();
      return null;
    }
    final AppTask task = beginTask('安装 Minecraft $versionId');
    try {
      final String? moduleError = await plugin.runInstall(
        plugin.InstallRequest(
          capability: plugin.InstallCapability.vanilla,
          version: versionId,
        ),
        _moduleContext(task, onProgress: onProgress, downloader: (String v) async {
          await vanillaInstaller.installVanilla(
            v,
            onProgress: (InstallProgress progress) {
              task.update(
                stage: progress.stage,
                detail: progress.detail,
                fraction: progress.fraction,
              );
              updateTask(task);
            },
          );
          return null;
        }),
      );
      if (moduleError != null) {
        throw InstallException(moduleError);
      }
      final AppEntry entry = AppEntry(
        id: 'vanilla-$versionId',
        name: 'Minecraft $versionId',
        subtitle: '原版 · $versionId',
        description: '',
        kind: AppKind.minecraft,
        versionId: versionId,
        loader: 'Vanilla',
        minecraftVersion: versionId,
        isolated: true,
      );
      final AppEntry created = await _upsertEntry(entry);
      await scanVersions();
      finishTask(task);
      notifyListeners();
      return created;
    } on Object catch (error) {
      lastError = error.toString();
      finishTask(task, success: false, error: lastError);
      notifyListeners();
      return null;
    }
  }

  /// Installs a loader build and adds a library entry. The vanilla version is
  /// installed first when missing.
  Future<AppEntry?> installLoader(
    LoaderKind loader,
    String gameVersion,
    String loaderVersion, {
    void Function(String stage, double fraction, String detail)? onProgress,
  }) async {
    if (_launching) return null;
    _launching = true;
    lastError = null;
    notifyListeners();
    if (!installModuleEnabled) {
      lastError = '安装模块已停用，请在「插件管理」中启用。';
      notifyListeners();
      return null;
    }
    final AppTask task = beginTask('安装 ${loader.label} $gameVersion');
    try {
      JavaRuntime? java = javaManagerFor(minecraftRoot).pickInstalled(
        javaRuntimes,
        defaultPath: settings.defaultJavaPath,
        requiredMajor: _majorFor(gameVersion),
      );
      late final LoaderInstallResult result;
      final String? moduleError = await plugin.runInstall(
        plugin.InstallRequest(
          capability: plugin.InstallCapability.loader,
          version: gameVersion,
          loader: loader.slug,
          loaderVersion: loaderVersion,
        ),
        _moduleContext(
          task,
          onProgress: onProgress,
          downloader: (String _) async => null,
          loader: (String _, String _, String _) async {
            result = await loaderInstaller.install(
              loader,
              gameVersion,
              loaderVersion,
              javaExecutable: java?.path,
              onProgress: (InstallProgress progress) {
                task.update(
                  stage: progress.stage,
                  detail: progress.detail,
                  fraction: progress.fraction,
                );
                updateTask(task);
              },
            );
            return null;
          },
        ),
      );
      if (moduleError != null) {
        throw InstallException(moduleError);
      }
      if (result.warnings.isNotEmpty) {
        lastError = result.warnings.join(' ');
      }
      final AppEntry entry = AppEntry(
        id: '${result.loader.slug}-${result.gameVersion}-${result.loaderVersion}',
        name: result.loader.slug == 'fabric'
            ? 'Fabric $result.loaderVersion'
            : '${result.loader.label} $result.loaderVersion',
        subtitle: '${result.loader.label} · ${result.gameVersion}',
        description: '',
        kind: AppKind.minecraft,
        versionId: result.versionId,
        loader: result.loader.label,
        minecraftVersion: result.gameVersion,
        isolated: true,
      );
      final AppEntry created = await _upsertEntry(entry);
      finishTask(task);
      notifyListeners();
      return created;
    } on Object catch (error) {
      lastError = error.toString();
      finishTask(task, success: false, error: lastError);
      notifyListeners();
      return null;
    } finally {
      _launching = false;
      notifyListeners();
    }
  }

  /// Java major used to run a loader installer for [gameVersion].
  static int _majorFor(String gameVersion) {
    final Match? match = RegExp(r'^1\.(\d+)(?:\.(\d+))?')
        .firstMatch(gameVersion);
    if (match == null) return 17;
    final int minor = int.parse(match.group(1)!);
    if (minor >= 20) return 21;
    if (minor >= 18) return 17;
    if (minor == 17) return 16;
    return 8;
  }

  Future<AppEntry> _upsertEntry(AppEntry entry) async {
    for (final AppEntry existing in library.entries) {
      if (existing.id == entry.id) {
        await library.update(entry);
        librarySelectionId = entry.id;
        return entry;
      }
    }
    await library.add(entry);
    librarySelectionId = entry.id;
    return entry;
  }

  // ------------------------------------------------------------- Modrinth

  Future<List<BrowseItem>> searchModrinth({
    required BrowseCategory category,
    String query = '',
    String? loader,
    BrowseSort sort = BrowseSort.popular,
    int offset = 0,
  }) => modrinth.search(
    category: category,
    query: query,
    loader: loader,
    sort: sort,
    offset: offset,
  );

  /// Downloads the newest compatible file of [item] into [entry]'s instance.
  /// `.mrpack` projects are installed as a full modpack.
  Future<String?> installFromModrinth({
    required BrowseItem item,
    required AppEntry entry,
    void Function(String stage, double fraction)? onProgress,
  }) async {
    lastError = null;
    notifyListeners();
    try {
      final String? loader = entry.isolated ? _loaderSlug(entry.loader) : null;
      final String gameVersion = entry.minecraftVersion ?? '';
      final List<ModrinthVersion> versions = await modrinth.versions(
        item.id,
        gameVersion: gameVersion.isEmpty ? null : gameVersion,
        loader: loader,
      );
      final ModrinthVersion? version = ModrinthClient.pick(
        versions,
        gameVersion: gameVersion,
        loader: loader,
      );
      if (version == null) {
        lastError = '${item.name} 没有适用于该实例的版本。';
        notifyListeners();
        return null;
      }
      final String gameDir = gameDirectory(entry);
      final String subdir = switch (item.category) {
        BrowseCategory.shader => 'shaderpacks',
        BrowseCategory.modpack => '',
        _ => 'mods',
      };
      final File file = await modrinth.download(
        version,
        join(gameDir, subdir),
        onProgress: onProgress,
      );
      if (item.category == BrowseCategory.modpack ||
          file.path.toLowerCase().endsWith('.mrpack')) {
        final ModpackInstaller pack = ModpackInstaller(downloader: downloader);
        final ModpackManifest manifest = await pack.install(
          file,
          gameDir,
          onProgress: (String stage, double fraction, String detail) {
            onProgress?.call(stage, fraction);
          },
        );
        notifyListeners();
        return '已安装整合包 ${manifest.name} ${manifest.versionId}';
      }
      notifyListeners();
      return '已安装 ${version.fileName}';
    } on Object catch (error) {
      lastError = error.toString();
      notifyListeners();
      return null;
    }
  }

  static String? _loaderSlug(String? loader) {
    switch (loader?.toLowerCase()) {
      case 'fabric':
        return 'fabric';
      case 'forge':
        return 'forge';
      case 'neoforge':
        return 'neoforge';
      default:
        return null;
    }
  }

  // ------------------------------------------------------------ 社区

  Future<void> refreshFeeds([String? sourceId]) async {
    await feeds.refresh(sourceId);
    notifyListeners();
  }

  Future<void> removeFeedSource(String id) async {
    await feeds.removeSource(id);
    if (communitySourceId == id) {
      communitySourceId = null;
      _selectDefaults();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ 皮肤

  Future<String?> uploadSkin(File file, {String variant = 'classic'}) async {
    lastError = null;
    try {
      await auth.uploadSkin(file, variant: variant);
      return null;
    } on MicrosoftAuthException catch (error) {
      lastError = error.message;
      notifyListeners();
      return error.message;
    } on Object catch (error) {
      lastError = error.toString();
      notifyListeners();
      return error.toString();
    }
  }

  // ------------------------------------------------------------ 更新

  Future<UpdateCheckResult> checkForUpdates() async {
    final UpdateCheckResult result = await updates.check(
      settings.updateManifestUrl,
    );
    notifyListeners();
    return result;
  }

  Future<File?> downloadUpdate(UpdateRelease release) async {
    final File? file = await updates.download(release);
    notifyListeners();
    return file;
  }

  Future<void> applyUpdate(File file, {String? executableName}) =>
      updates.apply(file, executableName: executableName);

  void setStatsFilter(StatsFilter filter) {
    statsFilter = filter;
    notifyListeners();
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    library.removeListener(_childChanged);
    stats.removeListener(_childChanged);
    feeds.removeListener(_childChanged);
    plugins.removeListener(_childChanged);
    auth.removeListener(_childChanged);
    installModules.removeListener(_childChanged);
    launcher.removeListener(_childChanged);
    launcher.dispose();
    library.dispose();
    stats.dispose();
    feeds.dispose();
    plugins.dispose();
    auth.dispose();
    super.dispose();
  }
}
