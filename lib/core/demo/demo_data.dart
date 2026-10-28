import 'dart:math';

import '../models/app_entry.dart';
import '../models/browse_item.dart';
import '../models/feed.dart';
import '../models/play_session.dart';
import '../models/plugin_manifest.dart';

/// Deterministic content used by the Alpha UI prototype.
///
/// Everything here is labelled demo data in the interface. The repository
/// interfaces in `lib/core/services` are the seams where real Modrinth, Mojang
/// and RSS integrations will be plugged in.
class DemoData {
  DemoData._();

  static const List<_DemoApp> _apps = <_DemoApp>[
    _DemoApp(
      id: 'demo-vanilla-1-21-1',
      name: 'Minecraft 1.21.1',
      subtitle: '原版 · Java Edition',
      description: 'Minecraft 1.21.1 原版客户端。',
      kind: AppKind.minecraft,
      loader: null,
      minecraftVersion: '1.21.1',
      iconColor: 0xFF4C9A63,
      weight: 5,
      minMinutes: 25,
      maxMinutes: 120,
    ),
    _DemoApp(
      id: 'demo-fabulously-optimized',
      name: 'Fabulously Optimized',
      subtitle: '整合包 · Fabric · 1.21.1',
      description: 'Fabric 轻量优化整合包，接近原版。',
      kind: AppKind.modpack,
      loader: 'Fabric',
      minecraftVersion: '1.21.1',
      iconColor: 0xFF6D5BD0,
      weight: 9,
      minMinutes: 30,
      maxMinutes: 180,
    ),
    _DemoApp(
      id: 'demo-atm10',
      name: 'All the Mods 10',
      subtitle: '整合包 · NeoForge · 1.21.1',
      description: 'NeoForge 科技与魔法整合包，带任务书。',
      kind: AppKind.modpack,
      loader: 'NeoForge',
      minecraftVersion: '1.21.1',
      iconColor: 0xFF2E7D8F,
      weight: 6,
      minMinutes: 40,
      maxMinutes: 210,
    ),
    _DemoApp(
      id: 'demo-rlcraft',
      name: 'RLCraft',
      subtitle: '整合包 · Forge · 1.12.2',
      description: 'Forge 硬核生存整合包，机制偏真实。',
      kind: AppKind.modpack,
      loader: 'Forge',
      minecraftVersion: '1.12.2',
      iconColor: 0xFFB05A2A,
      weight: 3,
      minMinutes: 20,
      maxMinutes: 95,
    ),
    _DemoApp(
      id: 'demo-create-astral',
      name: 'Create: Astral',
      subtitle: '整合包 · Forge · 1.20.1',
      description: 'Create 机械与空岛生存整合包。',
      kind: AppKind.modpack,
      loader: 'Forge',
      minecraftVersion: '1.20.1',
      iconColor: 0xFFC99A2E,
      weight: 2,
      minMinutes: 35,
      maxMinutes: 150,
    ),
    _DemoApp(
      id: 'demo-blockbench',
      name: 'Blockbench',
      subtitle: '自定义程序 · 3D 建模',
      description: '3D 建模工具，作为自定义程序加入库。',
      kind: AppKind.custom,
      loader: null,
      minecraftVersion: null,
      iconColor: 0xFF3B82F6,
      weight: 2,
      minMinutes: 15,
      maxMinutes: 70,
    ),
    _DemoApp(
      id: 'demo-konsole',
      name: 'Konsole',
      subtitle: '实用软件 · 终端',
      description: '终端应用，按实用软件统计。',
      kind: AppKind.utility,
      loader: null,
      minecraftVersion: null,
      iconColor: 0xFF52525B,
      weight: 2,
      minMinutes: 10,
      maxMinutes: 45,
    ),
    _DemoApp(
      id: 'demo-modrinth-app',
      name: 'Modrinth App',
      subtitle: '实用软件 · 模组管理',
      description: '模组管理工具。',
      kind: AppKind.utility,
      loader: null,
      minecraftVersion: null,
      iconColor: 0xFF1F9D55,
      weight: 1,
      minMinutes: 8,
      maxMinutes: 30,
    ),
  ];

  /// Builds roughly 150 sessions across the previous six weeks.
  static List<PlaySession> buildSessions({DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);
    final Random random = Random(20261026);
    final List<PlaySession> sessions = <PlaySession>[];

    for (int dayOffset = 44; dayOffset >= 0; dayOffset--) {
      final DateTime day = today.subtract(Duration(days: dayOffset));
      for (int appIndex = 0; appIndex < _apps.length; appIndex++) {
        final _DemoApp app = _apps[appIndex];
        final double chance =
            (app.weight / 10.0) * (dayOffset.isEven ? 0.9 : 0.55);
        if (random.nextDouble() > chance) continue;
        final int duration =
            app.minMinutes +
            random.nextInt(app.maxMinutes - app.minMinutes + 1);
        final DateTime start = day.add(
          Duration(hours: 16 + random.nextInt(6), minutes: random.nextInt(60)),
        );
        sessions.add(
          PlaySession(
            appId: app.id,
            appName: app.name,
            kind: app.kind.name,
            startedAt: start,
            durationSeconds: duration * 60,
            loader: app.loader,
            minecraftVersion: app.minecraftVersion,
            isDemo: true,
          ),
        );
      }
    }

    sessions.sort(
      (PlaySession a, PlaySession b) => b.startedAt.compareTo(a.startedAt),
    );
    return sessions;
  }

  /// Builds library entries whose playtime matches [sessions].
  static List<AppEntry> buildEntries({
    List<PlaySession>? sessions,
    DateTime? now,
  }) {
    final List<PlaySession> source = sessions ?? buildSessions(now: now);
    final Map<String, int> totals = <String, int>{};
    final Map<String, DateTime> lastPlayed = <String, DateTime>{};
    for (final PlaySession session in source) {
      totals.update(
        session.appId,
        (int value) => value + session.durationSeconds * 1000,
        ifAbsent: () => session.durationSeconds * 1000,
      );
      final DateTime? previous = lastPlayed[session.appId];
      if (previous == null || session.startedAt.isAfter(previous)) {
        lastPlayed[session.appId] = session.startedAt;
      }
    }

    return _apps
        .map((_DemoApp app) {
          return AppEntry(
            id: app.id,
            name: app.name,
            subtitle: app.subtitle,
            description: app.description,
            kind: app.kind,
            isDemo: true,
            versionId: app.minecraftVersion,
            loader: app.loader,
            minecraftVersion: app.minecraftVersion,
            executablePath: app.kind == AppKind.custom
                ? '/opt/blockbench/Blockbench'
                : null,
            workingDir: app.kind == AppKind.custom ? '/opt/blockbench' : null,
            iconColorValue: app.iconColor,
            totalPlayMs: totals[app.id] ?? 0,
            lastPlayed: lastPlayed[app.id],
            trackPlaytime: app.kind != AppKind.utility,
            isolated: app.kind == AppKind.modpack,
          );
        })
        .toList(growable: false);
  }

  static List<FeedSource> buildFeedSources() {
    return <FeedSource>[
      FeedSource(
        id: 'demo-feed-minecraft',
        title: 'Minecraft.net 新闻',
        url: 'https://www.minecraft.net/en-us/feeds/community-content/rss',
        siteUrl: 'https://www.minecraft.net/',
        description: '官方社区与版本公告',
        isFeed: true,
        isDemo: true,
      ),
      FeedSource(
        id: 'demo-feed-modrinth',
        title: 'Modrinth 博客',
        url: 'https://blog.modrinth.com/rss.xml',
        siteUrl: 'https://blog.modrinth.com/',
        description: 'Modrinth 平台更新与生态文章',
        isFeed: true,
        isDemo: true,
      ),
      FeedSource(
        id: 'demo-feed-fabric',
        title: 'Fabric 博客',
        url: 'https://fabricmc.net/blog/feed.xml',
        siteUrl: 'https://fabricmc.net/blog/',
        description: 'Fabric 加载器与工具链动态',
        isFeed: true,
        isDemo: true,
      ),
      FeedSource(
        id: 'demo-feed-hyalab',
        title: 'HyaLab 开发者博客',
        url: 'https://hyalab.dev/feed.xml',
        siteUrl: 'https://hyalab.dev/',
        description: 'Hydrogen Chloride Launcher 开发记录',
        isFeed: true,
        isDemo: true,
      ),
    ];
  }

  static List<FeedArticle> buildFeedArticles({DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    final List<_DemoArticle> seeds = <_DemoArticle>[
      _DemoArticle(
        sourceId: 'demo-feed-hyalab',
        title: 'Alpha 版本说明',
        author: 'HyaLab',
        hoursAgo: 3,
        summary: '这一版先做界面和登录，浏览、社区和启动仍是演示数据。',
        content:
            'Alpha 先把界面、设置和微软登录跑通。浏览、社区和启动流程暂时使用演示数据，界面上会标明。\n\n'
            '下载、模组安装和真正的游戏启动还没接入。插件目前只能提供声明式页面，不会执行代码。\n\n'
            '登录是这一版唯一会访问外部服务的功能，需要自己填 Azure client ID。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-hyalab',
        title: '插件页面为什么先做声明式',
        author: 'HyaLab',
        hoursAgo: 26,
        summary: '插件只提供清单，启动器负责渲染，避免在主进程执行第三方代码。',
        content:
            '启动器直接加载第三方 Dart 或原生代码，权限和稳定性都不好控制。Alpha 先只支持清单加声明式页面。\n\n'
            '插件通过 plugin.json 描述界面和动作，启动器校验后渲染。打开链接需要声明 openUrl 权限。\n\n'
            '后续会评估独立进程或 Wasm 宿主，再把动态能力放开。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-modrinth',
        title: 'Modrinth API 的几个限制',
        author: 'Modrinth',
        hoursAgo: 49,
        summary: '公开 API 可以不登录读取项目，但要注意 User-Agent、缓存和 429 退避。',
        content:
            'Modrinth 的公开 API 不登录也能读取项目和版本。请求时带上 User-Agent，并缓存短时间内的相同查询。\n\n'
            '遇到 429 按 Retry-After 等待。整合包下载文件多，最好限制并发。\n\n'
            'Alpha 还没接真实 API，数据模型已经按项目、版本、加载器拆开。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-fabric',
        title: 'Fabric Loader 0.16 兼容性',
        author: 'FabricMC',
        hoursAgo: 74,
        summary: '新版本对模组元数据校验更严格，整合包应锁定加载器版本。',
        content:
            'Fabric Loader 0.16 仍兼容大多数旧模组，但对无效元数据更严格。\n\n'
            '整合包最好锁定验证过的加载器版本，不要自动追新。\n\n'
            '启动器需要同时记录游戏版本和加载器版本，版本管理里目前已经分开显示。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-minecraft',
        title: '社区建筑：山谷轨道小镇',
        author: 'Minecraft Community',
        hoursAgo: 101,
        summary: '一个围绕环形铁路展开的生存小镇。',
        content:
            '本周社区建筑是一座沿山谷建的生存小镇。车站、仓库和农田由高架桥连在一起。\n\n'
            '作者没有装模组，材料都是手动采集的。\n\n'
            '社区标签页可以添加任意站点的 RSS，后续会在阅读器里直接打开原文。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-minecraft',
        title: '1.21.1 更新与服务器升级',
        author: 'Minecraft',
        hoursAgo: 150,
        summary: '1.21.1 主要修区块、红石和崩溃问题，服务器建议等插件兼容后再升。',
        content:
            '1.21.1 以修复为主，涉及区块加载、红石顺序和部分崩溃。\n\n'
            '升级服务器前确认核心插件和数据包兼容，并备份世界。客户端升级后不能直接进旧版服务器。\n\n'
            '版本管理会显示每个实例的占用空间和最后启动时间。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-modrinth',
        title: '光影包的版本管理',
        author: 'Modrinth',
        hoursAgo: 210,
        summary: '光影开始从论坛附件转向可版本化的项目页面。',
        content:
            '光影以前多放在论坛和网盘，版本很难追溯。现在越来越多作者在项目平台发布，并标注游戏版本和加载器。\n\n'
            '光影更接近资源包，安装路径固定，但要记录来源和版本。\n\n'
            '浏览页已经把光影单独分类，之后会接真实项目数据。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-fabric',
        title: 'Java 版本和 JVM 参数是两件事',
        author: 'FabricMC',
        hoursAgo: 300,
        summary: 'Java 版本决定能不能启动，JVM 参数决定运行时稳不稳。',
        content:
            '1.17 之后 Minecraft 需要 Java 17，1.20.5 之后建议 Java 21。选错版本通常启动就崩。\n\n'
            'JVM 参数影响内存、GC 和卡顿，和 Java 版本无关。\n\n'
            '库的右键菜单里分别有 Java 设置和 JVM 设置，设置页可以改默认值。',
      ),
      _DemoArticle(
        sourceId: 'demo-feed-hyalab',
        title: 'Fluent 和 Steam 布局怎么放在一起',
        author: 'HyaLab',
        hoursAgo: 420,
        summary: '材质和动效按 Fluent，库的信息密度按 Steam。',
        content:
            'Steam 的库是列表加主视觉，Fluent 提供材质、层级和动效。两者可以叠在一起。\n\n'
            'Alpha 去掉了浏览全部游戏的卡片视图，只保留列表和详情。整合包用启动器背景图，非游戏条目用纯黑。\n\n'
            '主题层用 Fluent 的颜色和控件，没有额外引入 UI 框架。',
      ),
    ];

    return seeds
        .map(
          (_DemoArticle seed) => FeedArticle(
            id: 'demo-article-${seed.title.hashCode.abs()}',
            sourceId: seed.sourceId,
            title: seed.title,
            author: seed.author,
            publishedAt: anchor.subtract(Duration(hours: seed.hoursAgo)),
            summary: seed.summary,
            content: seed.content,
            isDemo: true,
            read: seed.hoursAgo > 200,
          ),
        )
        .toList(growable: false);
  }

  static List<BrowseItem> buildBrowseItems({DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    int daysAgo(int days) =>
        anchor.subtract(Duration(days: days)).millisecondsSinceEpoch;

    return <BrowseItem>[
      BrowseItem(
        id: 'demo-jei',
        name: 'Just Enough Items',
        summary: '查看物品配方与用途，模组整合包的基础设施。',
        description: '物品清单、配方查询与搜索。',
        author: 'mezz',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'Forge', 'NeoForge'],
        downloads: 482000000,
        followers: 128000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(4)),
        accentStartValue: 0xFF3B82F6,
        accentEndValue: 0xFF1E3A8A,
        tags: <String>['实用', '配方', '客户端'],
        versions: <String>['1.21.1', '1.20.1', '1.19.2'],
        featured: true,
      ),
      BrowseItem(
        id: 'demo-sodium',
        name: 'Sodium',
        summary: '重写渲染管线，大幅提升帧率并减少卡顿。',
        description: '重写区块渲染与光照，提升帧率。',
        author: 'CaffeineMC',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'NeoForge'],
        downloads: 312000000,
        followers: 96000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(2)),
        accentStartValue: 0xFF22C55E,
        accentEndValue: 0xFF14532D,
        tags: <String>['优化', '性能', '客户端'],
        versions: <String>['1.21.1', '1.20.1'],
        featured: true,
      ),
      BrowseItem(
        id: 'demo-iris',
        name: 'Iris Shaders',
        summary: '为 Fabric 带来光影支持，兼容主流光影包。',
        description: '兼容 OptiFine 光影格式，可配合 Sodium。',
        author: 'Iris Team',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'NeoForge'],
        downloads: 188000000,
        followers: 74000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(6)),
        accentStartValue: 0xFF8B5CF6,
        accentEndValue: 0xFF4C1D95,
        tags: <String>['光影', '渲染', '客户端'],
        versions: <String>['1.21.1', '1.20.1'],
        featured: true,
      ),
      BrowseItem(
        id: 'demo-create',
        name: 'Create',
        summary: '旋转动力、齿轮与自动化机械的完整系统。',
        description: '旋转动力、齿轮与列车系统。',
        author: 'simibubi',
        category: BrowseCategory.mod,
        loaders: <String>['Forge', 'NeoForge', 'Fabric'],
        downloads: 97000000,
        followers: 52000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(9)),
        accentStartValue: 0xFFF59E0B,
        accentEndValue: 0xFF7C2D12,
        tags: <String>['科技', '机械', '自动化'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-farmers-delight',
        name: "Farmer's Delight",
        summary: '扩展农业与烹饪，用更丰富的食物支撑冒险。',
        description: '作物、厨具和食物。',
        author: 'vectorwing',
        category: BrowseCategory.mod,
        loaders: <String>['Forge', 'NeoForge', 'Fabric'],
        downloads: 76000000,
        followers: 41000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(12)),
        accentStartValue: 0xFF84CC16,
        accentEndValue: 0xFF365314,
        tags: <String>['农业', '食物', '装饰'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-terralith',
        name: 'Terralith',
        summary: '用数据包生成更丰富的地形与生物群系。',
        description: '用数据包重写地形生成。',
        author: 'Starmute',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'NeoForge', 'Forge'],
        downloads: 64000000,
        followers: 38000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(15)),
        accentStartValue: 0xFF06B6D4,
        accentEndValue: 0xFF164E63,
        tags: <String>['世界生成', '地形', '数据包'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-distant-horizons',
        name: 'Distant Horizons',
        summary: '在远处渲染简化地形，显著提升视距。',
        description: '用 LOD 扩展视距。',
        author: 'jeseibel',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'Forge', 'NeoForge'],
        downloads: 51000000,
        followers: 33000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(18)),
        accentStartValue: 0xFF0EA5E9,
        accentEndValue: 0xFF0C4A6E,
        tags: <String>['优化', '视距', '客户端'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-xaeros-minimap',
        name: "Xaero's Minimap",
        summary: '小地图、路径点与多人服务器坐标共享。',
        description: '小地图与路径点。',
        author: 'xaero96',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'Forge', 'NeoForge'],
        downloads: 89000000,
        followers: 45000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(21)),
        accentStartValue: 0xFFEF4444,
        accentEndValue: 0xFF7F1D1D,
        tags: <String>['地图', '实用', '客户端'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-modmenu',
        name: 'Mod Menu',
        summary: '在游戏内查看和管理已安装模组。',
        description: '查看和管理已安装模组。',
        author: 'Terraformers',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric'],
        downloads: 156000000,
        followers: 61000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(7)),
        accentStartValue: 0xFF64748B,
        accentEndValue: 0xFF1E293B,
        tags: <String>['管理', '配置', '客户端'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-lithium',
        name: 'Lithium',
        summary: '优化游戏逻辑与实体 AI，减少服务端与客户端开销。',
        description: '优化实体、方块与 AI 逻辑。',
        author: 'CaffeineMC',
        category: BrowseCategory.mod,
        loaders: <String>['Fabric', 'NeoForge'],
        downloads: 143000000,
        followers: 58000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(5)),
        accentStartValue: 0xFF14B8A6,
        accentEndValue: 0xFF134E4A,
        tags: <String>['优化', '性能'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-fabulously-optimized',
        name: 'Fabulously Optimized',
        summary: '轻量、稳定、保留原版体验的优化整合包。',
        description: '性能与体验模组，画面接近原版。',
        author: 'FTB Team',
        category: BrowseCategory.modpack,
        loaders: <String>['Fabric'],
        downloads: 24000000,
        followers: 29000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(3)),
        accentStartValue: 0xFF6D5BD0,
        accentEndValue: 0xFF2E1065,
        tags: <String>['优化', '原版', '轻量'],
        versions: <String>['1.21.1', '1.20.1'],
        featured: true,
      ),
      BrowseItem(
        id: 'demo-atm10',
        name: 'All the Mods 10',
        summary: '科技、魔法与冒险并存的大型整合包。',
        description: '任务书驱动，模组数量多。',
        author: 'ATM Team',
        category: BrowseCategory.modpack,
        loaders: <String>['NeoForge'],
        downloads: 9800000,
        followers: 21000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(1)),
        accentStartValue: 0xFF2E7D8F,
        accentEndValue: 0xFF083344,
        tags: <String>['大型', '科技', '魔法'],
        versions: <String>['1.21.1'],
        featured: true,
      ),
      BrowseItem(
        id: 'demo-rlcraft',
        name: 'RLCraft',
        summary: '硬核生存与真实化机制的高难度整合包。',
        description: '温度、口渴和高难度怪物。',
        author: 'Shivaxi',
        category: BrowseCategory.modpack,
        loaders: <String>['Forge'],
        downloads: 31000000,
        followers: 64000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(30)),
        accentStartValue: 0xFFB05A2A,
        accentEndValue: 0xFF431407,
        tags: <String>['硬核', '生存', '冒险'],
        versions: <String>['1.12.2'],
      ),
      BrowseItem(
        id: 'demo-create-astral',
        name: 'Create: Astral',
        summary: '围绕 Create 构建的天空岛屿整合包。',
        description: 'Create 机械与空岛生存。',
        author: 'LudoCrypt',
        category: BrowseCategory.modpack,
        loaders: <String>['Forge'],
        downloads: 4200000,
        followers: 12000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(11)),
        accentStartValue: 0xFFC99A2E,
        accentEndValue: 0xFF422006,
        tags: <String>['空岛', '机械', '慢节奏'],
        versions: <String>['1.20.1'],
      ),
      BrowseItem(
        id: 'demo-cobblemon',
        name: 'Cobblemon',
        summary: '在 Minecraft 中收集、对战与培养宝可梦。',
        description: '在 Minecraft 里收集和对战宝可梦。',
        author: 'Cobblemon Team',
        category: BrowseCategory.modpack,
        loaders: <String>['Fabric', 'Forge'],
        downloads: 15600000,
        followers: 47000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(8)),
        accentStartValue: 0xFFF97316,
        accentEndValue: 0xFF7C2D12,
        tags: <String>['冒险', '收集', '轻量'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-complementary',
        name: 'Complementary Shaders',
        summary: '兼顾画面与性能的通用光影包。',
        description: '多档画质预设，兼顾性能。',
        author: 'EminGT',
        category: BrowseCategory.shader,
        loaders: <String>['Iris', 'OptiFine'],
        downloads: 58000000,
        followers: 36000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(10)),
        accentStartValue: 0xFF38BDF8,
        accentEndValue: 0xFF075985,
        tags: <String>['光影', '性能', '通用'],
        versions: <String>['1.21.1', '1.20.1'],
        featured: true,
      ),
      BrowseItem(
        id: 'demo-bsl',
        name: 'BSL Shaders',
        summary: '偏写实、色彩柔和的经典光影。',
        description: '柔和光照，可调项多。',
        author: 'CaptTatsu',
        category: BrowseCategory.shader,
        loaders: <String>['Iris', 'OptiFine'],
        downloads: 44000000,
        followers: 27000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(40)),
        accentStartValue: 0xFFFB923C,
        accentEndValue: 0xFF7C2D12,
        tags: <String>['光影', '写实'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-seus',
        name: 'SEUS Renewed',
        summary: '经典写实光影，强调反射与体积光。',
        description: '反射和大气效果较重。',
        author: 'Sonic Ether',
        category: BrowseCategory.shader,
        loaders: <String>['Iris', 'OptiFine'],
        downloads: 39000000,
        followers: 25000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(90)),
        accentStartValue: 0xFF10B981,
        accentEndValue: 0xFF064E3B,
        tags: <String>['光影', '写实', '高配'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-makeup',
        name: 'MakeUp Ultra Fast Shaders',
        summary: '面向低配设备的轻量光影。',
        description: '低开销光影，适合轻薄本。',
        author: 'XT_Xaya',
        category: BrowseCategory.shader,
        loaders: <String>['Iris', 'OptiFine'],
        downloads: 21000000,
        followers: 14000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(60)),
        accentStartValue: 0xFFEC4899,
        accentEndValue: 0xFF831843,
        tags: <String>['光影', '低配', '性能'],
        versions: <String>['1.21.1', '1.20.1'],
      ),
      BrowseItem(
        id: 'demo-loader-fabric',
        name: 'Fabric Loader',
        summary: '轻量、快速更新的模组加载器。',
        description: '轻量加载器，更新快。',
        author: 'FabricMC',
        category: BrowseCategory.loader,
        loaders: <String>['Fabric'],
        downloads: 120000000,
        followers: 88000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(2)),
        accentStartValue: 0xFFD6B4FC,
        accentEndValue: 0xFF4C1D95,
        tags: <String>['加载器', '轻量'],
        versions: <String>['0.16.10', '0.15.11'],
        loaderId: 'fabric',
        featured: true,
      ),
      BrowseItem(
        id: 'demo-loader-forge',
        name: 'Forge',
        summary: '历史最悠久、整合包生态最广的加载器。',
        description: '模组和整合包生态大。',
        author: 'MinecraftForge',
        category: BrowseCategory.loader,
        loaders: <String>['Forge'],
        downloads: 210000000,
        followers: 120000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(6)),
        accentStartValue: 0xFFF59E0B,
        accentEndValue: 0xFF451A03,
        tags: <String>['加载器', '整合包'],
        versions: <String>['1.21.1-52.0.2', '1.20.1-47.3.0'],
        loaderId: 'forge',
      ),
      BrowseItem(
        id: 'demo-loader-neoforge',
        name: 'NeoForge',
        summary: 'Forge 社区分叉，面向新版本与现代化工具链。',
        description: 'Forge 社区分叉，面向新版本。',
        author: 'NeoForged',
        category: BrowseCategory.loader,
        loaders: <String>['NeoForge'],
        downloads: 64000000,
        followers: 39000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(3)),
        accentStartValue: 0xFF2DD4BF,
        accentEndValue: 0xFF134E4A,
        tags: <String>['加载器', '新版本'],
        versions: <String>['21.1.80', '21.0.167'],
        loaderId: 'neoforge',
        featured: true,
      ),
      BrowseItem(
        id: 'demo-loader-optifine',
        name: 'OptiFine',
        summary: '经典性能与光影整合方案。',
        description: '优化与光影，部分功能与 Fabric 重叠。',
        author: 'sp614x',
        category: BrowseCategory.loader,
        loaders: <String>['OptiFine'],
        downloads: 180000000,
        followers: 95000,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(daysAgo(20)),
        accentStartValue: 0xFF84CC16,
        accentEndValue: 0xFF1A2E05,
        tags: <String>['加载器', '优化', '光影'],
        versions: <String>['1.21.1 HD U J3', '1.20.1 HD U I6'],
        loaderId: 'optifine',
      ),
    ];
  }

  /// A small in-memory plugin used to demonstrate the declarative page format.
  static PluginManifest buildDemoPlugin() {
    return PluginManifest(
      id: 'hcl-example-hello',
      name: 'Hello HCL',
      version: '1.0.0',
      author: 'HyaLab',
      description: '示例插件：声明式页面、文本、列表和链接。',
      minLauncherVersion: '0.1.0',
      permissions: <String>['openUrl'],
      directory: '',
      isDemo: true,
      pages: <PluginPage>[
        PluginPage(
          id: 'hello',
          title: 'Hello HCL',
          icon: 'auto_awesome',
          widgets: <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'heading',
              'text': '欢迎使用 Hydrogen Chloride Launcher',
            },
            <String, dynamic>{
              'type': 'paragraph',
              'text': '页面内容来自插件清单，启动器只负责渲染。插件拿不到账户、库或文件。',
            },
            <String, dynamic>{'type': 'divider'},
            <String, dynamic>{
              'type': 'list',
              'items': <String>[
                '插件只能读取自己的清单和资源',
                '打开链接需要声明 openUrl 权限',
                '组件由启动器渲染，不加载动态代码',
              ],
            },
            <String, dynamic>{
              'type': 'button',
              'label': '查看插件开发文档',
              'action': <String, dynamic>{
                'type': 'openUrl',
                'url': 'https://github.com/HyaLab/HydrogenChlorideLauncher',
              },
            },
          ],
        ),
      ],
    );
  }
}

class _DemoApp {
  const _DemoApp({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.kind,
    required this.loader,
    required this.minecraftVersion,
    required this.iconColor,
    required this.weight,
    required this.minMinutes,
    required this.maxMinutes,
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final AppKind kind;
  final String? loader;
  final String? minecraftVersion;
  final int iconColor;
  final int weight;
  final int minMinutes;
  final int maxMinutes;
}

class _DemoArticle {
  const _DemoArticle({
    required this.sourceId,
    required this.title,
    required this.author,
    required this.hoursAgo,
    required this.summary,
    required this.content,
  });

  final String sourceId;
  final String title;
  final String author;
  final int hoursAgo;
  final String summary;
  final String content;
}
