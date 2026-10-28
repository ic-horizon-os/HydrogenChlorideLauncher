# HMCL 功能对照

对照对象：Hello Minecraft Launcher。  
当前版本：`0.1.0-alpha.1`。

| 功能 | 当前状态 | 说明 |
| --- | --- | --- |
| 微软账户登录 | 已实现 | 内置公开 client ID + 设备码（PCL2 同款，输入代码到 microsoft.com/link）；支持自建 Azure 应用的浏览器回环登录 → Xbox Live → XSTS → Minecraft Services；启动前自动刷新过期令牌 |
| 令牌存储 | 已实现 | 优先系统钥匙串（Linux Secret Service），不可用时回退 0600 文件 |
| Java 管理 | 已实现 | 扫描本机 Java、选择默认运行时、手动添加路径 |
| Java 运行时下载 | 已实现 | 本机没有匹配版本时从 Mojang 下载对应 JRE 到 `runtime/`，按版本要求自动选择 |
| 内存与 JVM 参数 | 已实现 | 启动器默认值 + 单条目覆盖；参数按引号拆分后传给 JVM |
| 版本列表 | 已实现 | 扫描 `.minecraft/versions`、显示占用和最后启动 |
| 版本隔离 | 已实现 | 开关后使用 `versions/<版本>/` 作为游戏目录，创建 mods/config/saves 等子目录 |
| 游戏目录管理 | 已实现 | 设置页可添加/移除 `.minecraft` 目录 |
| 运行时长统计 | 已实现 | 进程退出后写入真实会话记录与图表 |
| 游戏下载 | 已实现 | 版本清单 → 版本 JSON、客户端、libraries、natives、资源索引与资源对象；SHA-1 校验、断点续传、并发下载 |
| 真实启动 | 已实现 | 组装 classpath 与 JVM/游戏参数模板，启动 Java 子进程；退出后写会话记录 |
| 加载器安装 | 已实现 | 安装版本时可直接选择 Fabric/Forge/NeoForge 一并安装；OptiFine 需导入安装文件 |
| 整合包安装 | 已实现 | `.mrpack`：解析 `modrinth.index.json`，下载文件并写入覆盖文件 |
| 模组管理 | 部分实现 | 本地 mods 添加、启停、删除；在线安装通过浏览页 |
| 在线内容 | 已实现 | Modrinth 搜索，按实例的游戏版本与加载器选择最新兼容版本并安装到实例 |
| 世界管理 | 已实现 | 本地 saves 列表、备份、删除，以及 `level.dat`（NBT）检查与修复 |
| 皮肤/披风 | 部分实现 | 本地皮肤库、预览，上传 PNG 皮肤到 Microsoft 账户（经典/纤细）；披风未实现 |
| 崩溃分析 | 已实现 | 结构化规则集，扫描 latest.log、crash-reports 与启动器自身日志 |
| 下载源切换 | 已实现 | 版本元数据与游戏文件可分别选择官方 / BMCLAPI / MCIM |
| 多目录管理 | 已实现 | 设置中可添加多个 .minecraft 目录，版本合并展示 |
| 安装模块化 | 已实现 | 安装能力位于同级 `HCL-Plugins/`，可在插件管理中停用 |
| 自动更新 | 已实现 | 可配置 JSON 更新清单：检查、下载、SHA-256 校验、替换安装目录并重启；不含签名与增量 |
| 离线账户 | 不支持 | 按交付要求：未登录 Microsoft 禁止启动 Minecraft |

## 验证方式

以下行为在构建机上用真实网络与真实 Java 运行时验证过（`test/live_*.dart`，需设置 `HCL_LIVE=1`）：

- Mojang 版本清单读取与 Minecraft 1.1 完整安装（版本 JSON、客户端、libraries）。
- Modrinth 搜索与按游戏版本/加载器筛选版本。
- RSS 订阅抓取、解析与入库。
- 从 Mojang 下载 Java 17 运行时，并通过 `java -version` 验证可执行。
- Minecraft 1.20.1 使用下载的 JRE 真实启动，日志到达 Datafixer Bootstrap（未带账户时随后停在在线认证，符合门禁预期）。
- Fabric 版本列表与安装（含原版依赖与 fabric-loader 库）。
- Forge 版本列表。

## 已知限制

- Forge/NeoForge 安装依赖 `maven.neoforged.net` 与 Forge 官方站点；部分网络无法访问时会明确报错。
- NeoForge 仅支持 Minecraft 1.20.2 及以上（更早版本没有 NeoForge 分支）。
- OptiFine 没有公开直链，需要用户从官网下载安装文件后导入。
- 内置 client ID `00000000402b5328` 是第三方 Minecraft 登录应用的公开 ID，不属于本启动器；令牌发给该应用，无法由本启动器控制其生命周期。介意的话请在设置里换成自己注册的 Azure 应用。
- 浏览器回环登录要求自建应用在「移动和桌面应用程序」平台注册 `http://localhost` 重定向。
- 自动更新不做代码签名与二进制增量，更新包只校验 SHA-256。
- 披风上传、CurseForge 整合包、模组更新检测尚未实现。
- 库页 Minecraft 背景使用 minecraft.net 官方 Key Art；仅缓存一张通用 Java & Bedrock 封面，不按单个游戏版本分别取图。
