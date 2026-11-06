# 架构说明（Alpha）

## 1. 目标与非目标

目标是完整可用的启动流程，而不是只有界面骨架：

- 完整界面、主题、导航与设置；
- 微软设备码登录、启动门禁与令牌钥匙串；
- 真实的游戏下载（版本 JSON、客户端、libraries、natives、资源）与 Java 子进程启动；
- Fabric/Forge/NeoForge/OptiFine 安装、`.mrpack` 整合包安装；
- Modrinth 在线内容、RSS/Atom 订阅；
- 世界修复、崩溃规则、下载源切换、自动更新；
- 可扩展的声明式插件边界；
- 能驱动统计图表的真实会话记录。

非目标：代码签名与增量更新、CurseForge 整合包、披风上传、离线账户（按交付要求，未登录禁止启动 Minecraft）、Windows 实机构建产物。

## 2. 分层

```text
┌──────────────────────────────────────────────┐
│ UI: FluentApp + NavigationView(top)          │
│     shell / browse / library / community     │
│     account / settings modal / widgets       │
├──────────────────────────────────────────────┤
│ State: AppState (ChangeNotifier)             │
│        AppScope (InheritedNotifier)          │
├──────────────────────────────────────────────┤
│ Core services                                │
│  SettingsStore  LibraryStore  FeedStore      │
│  StatsService   PluginRegistry               │
│  MicrosoftAuthService  TokenVault            │
│  LaunchService  UpdateService                │
│  CrashAnalyzer  WorldRepair  FeedParser      │
│  InstallModuleRegistry  VersionScanner       │
│  CoreBridge → JavaScanner / 密钥 / 哈希      │
├──────────────────────────────────────────────┤
│ core/minecraft (下载与启动管线)              │
│  VersionManifest  VersionJson  DownloadSource│
│  DownloadManager  MinecraftInstaller         │
│  JavaRuntimeManager  GameLauncher            │
│  LoaderInstaller  ModrinthClient             │
├──────────────────────────────────────────────┤
│ Persistence: JsonStore + AppPaths            │
├──────────────────────────────────────────────┤
│ Platform: window_manager, file_selector,     │
│           url_launcher, http                 │
└──────────────────────────────────────────────┘
```

UI 不直接读写文件，所有状态变更通过 `AppState` 进入服务层。`AppState` 订阅子服务（库、统计、订阅、插件、登录、启动）的 `ChangeNotifier` 并统一触发重建。应用壳由 `fluent_ui` 的 `FluentApp + NavigationView(PaneDisplayMode.top)` 组成；设置是叠加在主界面上的 Steam 式 `ContentDialog`，内部左侧分区、右侧 `ScaffoldPage.scrollable`。

## 3. 启动流程

```text
main()
  ├─ windowManager.ensureInitialized()
  ├─ AppState.bootstrap()
  │    ├─ AppPaths.ensure()
  │    ├─ SettingsStore.load()
  │    ├─ LibraryStore.load()   → 首次写入演示条目
  │    ├─ StatsService.load()   → 首次写入演示会话
  │    ├─ FeedStore.load()      → 首次写入演示来源/文章
  │    ├─ PluginRegistry.load() → 扫描插件目录 + 内置示例
  │    ├─ MicrosoftAuthService.load() → 读取钥匙串或 account.json
  │    └─ 异步 Java 扫描
  └─ runApp(AppScope → HclApp → FluentApp → HomeShell)
```

`HclApp` 根据设置构建亮/暗两套 Fluent 主题；`HomeShell` 负责标题栏、导航栏、页面切换与全局错误提示。

## 4. 微软登录

```text
requestDeviceCode(clientId)
  → POST /consumers/oauth2/v2.0/devicecode
  → 返回 user_code / verification_uri / interval

waitForLogin()
  → 轮询 /token (device_code)
  → authorization_pending / slow_down 继续
  → MS access token
  → POST user.auth.xboxlive.com/user/authenticate
  → POST xsts.auth.xboxlive.com/xsts/authorize
  → POST api.minecraftservices.com/authentication/login_with_xbox
  → GET  api.minecraftservices.com/minecraft/profile
  → MinecraftAccount → TokenVault
       ├─ hcl-core secret-set（Secret Service / DPAPI）
       └─ 回退 account.json (0600)
```

关键实现：

- `MicrosoftAuthService` 通过注入的 `http.Client` 与 `sleep` 函数支持单元测试。
- 错误映射：`authorization_declined`、`expired_token`、XSTS `2148916233/2148916238/2148916235`、HTTP 429/5xx。
- `refreshIfNeeded()` 在令牌临近过期时使用 refresh token 重新走 Xbox/XSTS 链路。
- `ownsMinecraft` 表示是否拿到 Minecraft 档案；未拥有时仍可登录，但界面提示。
- `prepareForLaunch()` 在启动前自动刷新过期令牌并给出明确失败原因。
- 启动门禁在 `AppState.launch()` 中检查登录状态，Minecraft/整合包未登录直接抛 `NotAuthenticatedException`。
- 皮肤上传走 `POST /minecraft/profile/skins`（multipart）。

## 5. 下载与启动管线

```text
MinecraftInstaller.installVanilla(versionId)
  ├─ fetchManifest()               版本清单（可缓存 30 分钟）
  ├─ fetchJson(version.url)        版本 JSON，写入 versions/<id>/<id>.json
  ├─ libraries + natives           按 rules 过滤平台，SHA-1 校验
  ├─ assetIndex → objects/         资源对象按哈希目录存放
  └─ virtual/legacy（旧版本）      资源索引标记 virtual 时建立目录

DownloadManager.run(requests)
  ├─ 已存在且 SHA-1 匹配 → 复用
  ├─ .part 断点续传 + Range
  ├─ 8 并发、3 次重试、每块超时
  └─ 校验通过后 rename，绝不留下半截文件
```

`DownloadMirror` 把官方 URL 重写到 BMCLAPI / MCIM；版本元数据与游戏文件可分别选择。`JavaRuntimeManager` 按版本 JSON 的 `javaVersion.majorVersion` 选择最接近的本机 Java，找不到时从 Mojang 下载对应 JRE 到 `runtime/`。

```text
GameLauncher.plan()
  ├─ classpath = 客户端 jar + 规则匹配的 libraries
  ├─ JVM 参数：-Xmx/-Xms + 版本 JSON 的 jvm 参数（去重、补齐缺项）
  ├─ 游戏参数：规则过滤 + ${auth_player_name} 等变量替换
  └─ LaunchVariables.features → has_custom_resolution 等

LaunchService.start()
  ├─ 未登录且是 Minecraft → NotAuthenticatedException
  ├─ 加载版本 JSON（含 inheritsFrom 合并）
  ├─ 解析 Java → Process.start(java, args)
  ├─ 监听 stdout/stderr → logs/hcl-launch-*.log
  └─ 进程退出 → LibraryStore.recordPlaytime + StatsService.record
```

`PlaySession` 冗余保存 `appName`、`kind`、`loader`、`minecraftVersion`，因此删除库条目后历史统计仍然完整。`StatsService.summary()` 支持包含/排除演示数据、游戏/实用软件、加载器、版本年代与最近 14 天聚合。图表由 `CustomPainter` 绘制，不依赖图表库。

## 6. 平台层（纯 Dart）

平台能力全部由 Dart 直接实现，构建不需要额外工具链：

```text
CoreBridge
  scanJava()          → JavaScanner（JAVA_HOME、PATH、常见目录）
  directorySize()     → 递归遍历，跳过符号链接
  hashFile()          → crypto 流式 SHA-256
  secretGet/Set/Delete → secret-tool（Linux Secret Service）
```

`CoreBridge` 的公开 API 保持稳定，所有调用点无需改动。

## 7. 持久化

| 文件 | 内容 |
| --- | --- |
| `settings.json` | 主题、背景、强调色、client ID、默认 Java/JVM、Minecraft 目录、演示数据开关、下载源、自动下载 Java、更新清单 |
| 钥匙串条目 | Minecraft 令牌与档案（Linux Secret Service） |
| `account.json` | 钥匙串不可用时的令牌回退存储（0600） |
| `library.json` | 库条目与累计时长 |
| `sessions.json` | 会话记录（最多 5000 条） |
| `feeds.json` | 站点/订阅与文章已读状态 |
| `plugin_state.json` | 插件启用状态 |
| `install_modules.json` | 功能模块（安装器）启用状态 |
| `plugins/<id>/plugin.json` | 插件清单 |

写入使用临时文件 + rename，避免半写文件。所有路径集中在 `AppPaths`。

## 8. 真实与演示边界

| 区域 | 实现 |
| --- | --- |
| 浏览 | 真实 Modrinth 搜索与安装；“加载器”分类仍是内置说明条目 |
| 社区 | 用户添加的 RSS/Atom 订阅真实抓取、解析与入库；内置示例来源仍为演示数据 |
| 启动 | 真实 Java 子进程；自定义程序按配置的命令行启动 |
| 版本 | 真实读取 `.minecraft/versions`，可从 Mojang 安装新版本 |
| Java | 真实扫描；缺失时从 Mojang 下载 JRE |
| 统计 | 真实会话 + 演示会话（可关闭演示数据） |
| 更新 | 需在关于页配置更新清单地址；未配置时不检查 |

`AppInfo.demoNotice` 与 UI 中的“演示数据”标签用于避免验收误解。

## 9. 插件运行时

```text
PluginRegistry.load()
  → 扫描 plugins/*/plugin.json
  → PluginManifest.fromJson() 校验
  → 版本兼容检查
  → 读取 plugin_state.json
  → 合并内置示例（演示数据开启时）

PluginPageView
  → 递归渲染声明式组件
  → Button 动作白名单
  → openUrl 检查 permissions
```

没有动态代码加载、反射或平台通道暴露给插件。详细 schema 见 `docs/plugin-development.md`。

## 10. 质量门

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux --release

# 真实网络与真实 Java 的集成检查（可选）
HCL_LIVE=1 flutter test test/live_network_test.dart test/live_launch_test.dart
```

Windows runner 由 `flutter create` 生成，本轮不构建 Windows 产物。

## 11. 后续里程碑

1. Windows 实机构建与安装包（`tool/build_windows.ps1`、`.github/workflows/build.yml`）。
2. CurseForge 整合包、模组更新检测与在线模组详情。
3. 自动更新的代码签名与增量更新；AppImage / exe 自解压安装包。
4. 插件宿主沙箱（Wasm/独立进程）与插件市场。
5. 披风上传与更完整的世界修复（区块级）。
