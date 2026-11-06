# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/)。Alpha 阶段版本号可能包含预发布标识。

## 0.1.0-alpha.2 — 2026-11-06 — 界面重做、模块化与功能补全

### 变更

- 移除右上角「演示数据」角标与各页面上的演示标记；演示数据改为设置中的开关，默认关闭，关闭时会真实移除示例条目。
- 顶栏选项卡改为单一滑块，切换时左右滑动跟随；内容区改为从下方位移淡入。
- 设置窗口左侧改为整列共享的选中条，切换分区时上下滑动。
- 列表选中条统一为 16px 短竖条，不再随行高伸缩。
- 库页新增「安装版本」「安装加载器」入口；版本选择改为二级菜单（大版本 → 具体版本）。
- 设置中的版本管理改为纯目录管理：支持多个 `.minecraft` 目录，所有目录的版本合并展示。
- 新增 Steam 式底部进度栏，显示安装阶段与百分比，不可展开。
- 修复版本隔离开关不保存的问题；开关移到库页启动按钮旁。
- 皮肤管理移到设置，作为全局皮肤库。
- 核心能力全部以纯 Dart 实现（Java 扫描、目录统计、SHA-256、密钥存储），构建无需额外工具链。
- 所有安装能力移入同级 `HCL-Plugins/hcl-plugin-installer` 模块，可在插件管理页停用。
- 浏览页新增侧边栏：模组、整合包、光影、加载器与游戏版本安装集中一处。
- 账号页新增皮肤管理：预览当前皮肤，支持个人皮肤、自定义 PNG 与正版玩家皮肤三种来源。
- 全部下拉菜单改为纯白弹层：固定向下展开，过长时滚动并显示滚动条。
- 设置窗格、浏览区块与库详情切换改为 Windows 11 设置风格的入场动画。
- 库侧栏条目去图标；右键菜单新增「彻底删除版本」（含版本文件夹与实例数据）。

## 未发布 — 真实下载与启动

从演示流程升级为可用的启动器：真实下载、真实 Java 启动、加载器与在线内容。

### 新增

- **开箱即用的微软登录**：内置通用公开 client ID（`00000000402b5328`），走 `login.live.com` 设备码流程，输入代码到 microsoft.com/link 即可登录，无需自己注册 Azure 应用；
- **浏览器登录（可选）**：自建 Azure 应用时可用 OAuth 2.0 授权码 + PKCE + 本机回环回调。
- **Minecraft 下载管线**：Mojang 版本清单、版本 JSON（含 `inheritsFrom` 合并）、客户端、libraries（按 `rules` 过滤平台）、natives 解压、资源索引与资源对象；SHA-1 校验、`.part` 断点续传、并发下载与重试。
- **真实启动**：classpath 组装、JVM/游戏参数模板替换、独立启动日志 `logs/hcl-launch-*.log`；进程退出后写入时长与会话记录。
- **Java 运行时**：按版本要求选择最接近的本机 Java；缺失时从 Mojang 下载 JRE 到 `runtime/`。
- **加载器安装**：Fabric（元数据与库文件）、Forge/NeoForge（下载并执行官方安装器）、OptiFine（导入安装文件）。
- **Modrinth**：搜索、按实例游戏版本/加载器选择最新兼容版本并安装；`.mrpack` 整合包安装。
- **社区订阅**：RSS 2.0 / Atom 抓取、解析、已读状态合并，可手动刷新与移除来源。
- **世界修复**：读取 `level.dat`（NBT，gzip），补全缺失字段、创建 region、清理残留 `session.lock`，操作前备份。
- **崩溃分析**：结构化规则集，读取 `latest.log`、`crash-reports` 与启动器自身日志。
- **皮肤上传**：把 PNG 皮肤（经典/纤细）上传到 Microsoft 账户。
- **下载源切换**：版本元数据与游戏文件分别可选官方 / BMCLAPI / MCIM。
- **自动更新**：JSON 更新清单，检查、下载、SHA-256 校验、替换安装目录并重启。
- **系统钥匙串**：`secret-*` 命令集成，Linux 用 Secret Service、Windows 用 DPAPI；不可用时回退 0600 文件。
- 新增真实网络/Java 集成检查 `test/live_*.dart`（`HCL_LIVE=1` 运行）。

### 变更

- 浏览页改为实时 Modrinth 数据，项目详情可选择安装目标实例。
- 版本管理新增“安装新版本”与下载源设置。
- 库详情“加载器”页提供构建选择、安装进度与 OptiFine 导入。
- 库页启动按钮显示启动阶段与进度，运行时长来自真实进程。
- 启动前自动刷新过期令牌；未登录仍禁止启动 Minecraft。
- 关于页能力矩阵与更新检查、存储位置与免责声明同步更新。

### 修复

- 库页 Minecraft 背景改为拉取 minecraft.net 官方 Minecraft Java & Bedrock 封面并缓存到 `<data>/covers/`，不再使用程序绘制的占位图；离线时回退到绘制图。
- `www.minecraft.net` 的 Akamai 会对自定义 User-Agent 挂起连接，对该域改用浏览器 UA。
- 参数解析丢失带 `rules` 的字符串参数（Windows 专用 JVM 参数被丢弃）。
- 现代版本 JSON 下重复添加默认 JVM 参数与错误的默认游戏参数。
- Forge 版本列表使用错误的 `promotions_slim.json` 地址。
- Java 运行时清单解析（平台优先的 JSON 结构）。

### 已知限制

- NeoForge 仅支持 Minecraft 1.20.2 及以上；`maven.neoforged.net` 在部分网络不可达时会明确报错。
- OptiFine 需要手动提供安装文件。
- 自动更新不含代码签名与增量。
- 仍未产出 Windows 二进制。

## 0.1.0-alpha.1 — 2026-10-26

首个 Alpha 交付。界面按 Fluent UI for Flutter 重构。项目许可证由 MIT 迁移为 GPL-3.0-only。

### 新增

- Fluent 风格桌面界面：基于 `fluent_ui` 的 `FluentApp`、`NavigationView(PaneDisplayMode.top)`、`ScaffoldPage.scrollable`、`Card`、`ToggleSwitch`、`Slider`、`TextBox`；纯白亮色 / 纯黑暗色、强调色、背景图片、填充透明度、高斯模糊与亚克力噪点。
- 自绘标题栏、窗口菜单（最小化/最大化/关闭）、顶部水平导航（浏览/库/社区/用户名）；选项卡去掉前置图标，最前面加入 Steam 式前进/后退；设置入口位于 HCL 标题。
- 开屏动画：Maple Mono NF CN 全称 + 强调色背景，Fade/Scale 过渡。
- 标签页与设置分区加入 Windows 11 风格 Fade/Slide 过渡。
- HMCL 风格版本隔离：按条目开关，`versions/<版本>/` 下创建 mods/config/saves 等目录。
- 库详情顶部选项卡：加载器安装、模组管理、世界管理、本地皮肤、崩溃分析。
- 开屏改为主题黑/白背景，不再使用强调色。
- 浏览页：模组/整合包/光影/加载器分类、搜索、筛选、排序、项目详情（演示数据）。
- 库页：左侧 `ListView` + 右侧全宽 Banner；Banner 底部 Acrylic 毛玻璃启动区；右键菜单、Java/JVM 设置、添加自定义程序、模拟启动。
- 社区页：Thunderbird 式三栏阅读器、站点/订阅管理、已读状态。
- Steam 式模态设置窗口：左侧分区导航，右侧 `ScaffoldPage.scrollable`；登录信息、个性化、插件管理、Java 设置、版本管理、统计信息、关于。
- 微软 OAuth 设备码登录：Xbox Live → XSTS → Minecraft Services → 档案；令牌本地持久化；未登录禁止启动 Minecraft。
- 核心边车：Java 扫描、目录占用、SHA-256；Dart 回退。
- 插件系统：清单校验、启停、安装/卸载、声明式页面与受控动作。
- 统计：会话记录、饼图/直方图/折线图、分类/加载器/版本区间筛选。
- 文档：快速使用、插件开发、架构说明、示例插件。

### 已知限制

- 浏览、社区、下载、启动为演示/模拟流程，不访问真实内容源。
- Forge/NeoForge/OptiFine 自动安装、`.mrpack` 未实现。
- 不生成安装包；不包含自动更新、代码签名、系统钥匙串。
- Windows 构建源码已生成，但未在本轮验证。
