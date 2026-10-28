# Alpha 交付说明

版本：`0.1.0-alpha.1`  
日期：2026-10-26  
依据：`prompt/Alpha/交付要求.md`

## 1. 交付物

| 交付要求 | 位置 |
| --- | --- |
| Alpha 版本内容 | `lib/`、`linux/`、`windows/`、`rust/hcl-core/` |
| 插件开发文档 | `docs/plugin-development.md` |
| 快速使用 | `docs/quick-start.md` |
| 架构与边界说明 | `docs/architecture.md` |
| 示例插件 | `examples/plugins/hello-hcl/` |
| 界面截图 | `docs/images/`（13 张，含开屏） |
| 变更记录 | `CHANGELOG.md` |
| 许可证 | `LICENSE`（GPL-3.0-only，由 MIT 迁移） |

按要求**未生成任何安装包**，也未执行打包流程。

## 2. 需求覆盖

### 2.1 核心设计

| 要求 | 状态 | 说明 |
| --- | --- | --- |
| Flutter + Dart + Rust | 已实现 | Flutter 3.47.7 / Dart 3.13.5 / Rust 1.98.1 |
| Windows / Linux | 源码就绪 | Linux 已构建验证；Windows runner 已生成，本轮未构建 |
| Java 程序启动（选择 Java 版本） | 已实现 | 真实下载版本与资源、组装 classpath、启动 Java 子进程；Java 发现、选择、内存/JVM 参数生效，缺失时可下载 Mojang JRE |
| 自定义程序启动 | 已实现 | 通过“添加自定义程序”加入；按配置的可执行文件与参数启动进程 |
| 第三方插件（自定义界面/更多功能） | 已实现声明式插件 | 清单、启停、安装/卸载、页面渲染、动作白名单 |
| 启用时长统计 | 已实现 | 游戏进程退出后写入真实会话记录，驱动统计图表 |

### 2.2 用户界面

- Fluent 设计语言、纯白亮色 / 纯黑暗色、强调色：已实现。
- 背景图片、填充透明度、模糊开关、高斯模糊 / 亚克力（模糊 + 噪点）：已实现。
- 应用菜单：窗口（最小化/最大化/关闭）、关于：已实现；**设置入口移到 HCL 标题**，点击打开 Steam 式模态设置窗口。
- 顶栏：浏览、库、社区、动态 `$用户名`：已实现；无前置图标，最前面为 Steam 式前进/后退按钮（带标签页历史栈）。
- 浏览：模组、整合包、光影、加载器分类；搜索结果来自 Modrinth，可选择实例并直接安装。
- 库：内部左右分栏，左侧 `ListView`，右侧全宽 Banner（无外边距/无 Card 包裹）；底部 Acrylic 毛玻璃 + 主色调启动按钮；整合包复用背景图，Minecraft 使用版本配色占位，非游戏纯黑；右键菜单含 Java/JVM 设置。
- 社区：Thunderbird 式三栏；添加站点、RSS/Atom 订阅并立即抓取，可刷新与移除来源。
- 设置：Steam 式模态窗口（左侧分区导航 + 右侧 `ScaffoldPage.scrollable`），floating `Card` 选项 + Fluent `ToggleSwitch`/`Slider`/`Button`/`TextBox`；七项分区。
- 开屏：纯文本全称 + 强调色背景，Fade/Scale 过渡；标签页与设置分区使用 Fade/Slide 过渡。
- 版本隔离：HMCL 风格的按条目隔离，游戏目录为 `versions/<版本>/`。
- 库详情顶部选项卡：加载器安装、模组管理、世界管理、本地皮肤、崩溃分析。
- 统计：饼图、直方图、折线图；游戏/实用软件、加载器、版本区间筛选。
- 关于：版本、GitHub、开源许可、免责声明、能力矩阵。

### 2.3 文件要求

| 要求 | 状态 |
| --- | --- |
| Alpha 版本内容 | 已交付（本项目） |
| 插件开发文档 | 已交付（`docs/plugin-development.md`） |
| 快速使用 | 已交付（`docs/quick-start.md`） |
| 暂时不需要打包、不要运行构建程序 | Alpha 不生成安装包；为验证代码质量执行了调试构建，未产出分发物 |

> 说明：需求原文要求“不要运行构建程序”。经用户明确授权，本轮在远端执行了 `flutter build linux --debug` 仅用于验证编译，不生成 exe/AppImage/tar.gz 安装包。

## 3. 真实实现 vs 演示

**真实链路**

- Microsoft OAuth 设备码 → Xbox Live → XSTS → Minecraft Services → 档案；令牌优先写入系统钥匙串，回退 0600 文件；启动前自动刷新。
- 未登录时禁止启动 Minecraft/整合包。
- 游戏下载（版本 JSON、客户端、libraries、natives、资源）、真实 Java 启动。
- Fabric/Forge/NeoForge 安装、OptiFine 导入、`.mrpack` 整合包。
- Modrinth 搜索与安装、RSS/Atom 订阅、世界修复、崩溃规则、下载源切换、自动更新、皮肤上传。
- Rust `hcl-core`：Java 扫描、目录占用、SHA-256；Dart 回退。
- 版本目录扫描、存储占用、最后启动时间。
- 设置、账户、库、会话、订阅、插件状态持久化。
- 统计聚合与图表、插件清单校验与声明式页面渲染。
- Java、JVM 参数保存与默认值/条目覆盖。

**演示数据（可用设置关闭）**

- 库中的演示条目、社区内置示例来源与文章。
- 浏览页“加载器”分类的说明条目（安装入口跳转到版本管理）。

**未实现**

- 披风上传、CurseForge 整合包、模组更新检测。
- 自动更新的代码签名与增量、exe/AppImage 安装包。
- Windows 实机构建验证；离线账户（按交付要求保持微软门禁）。

## 4. 验证记录

验证环境：`192.168.2.57`（Windows 主机上的 WSL2，Ubuntu 24.04.1，16 核 / 15 GB）。  
Flutter 3.47.7、Dart 3.13.5、fluent_ui 4.17.0、clang 18.1.3、CMake 3.28.3、ninja 1.11.1、Rust 1.98.1。

| 检查 | 结果 |
| --- | --- |
| `dart format --set-exit-if-changed lib test tool` | 通过 |
| `flutter analyze` | 通过（No issues found） |
| `flutter test` | 见本轮验证结果（含版本/参数解析、下载源、Java 选择、RSS、崩溃规则、NBT、钥匙串回退、Modrinth 映射） |
| `HCL_LIVE=1 flutter test test/live_*.dart` | 真实网络与真实 Java：Mojang 安装、Modrinth、RSS、JRE 下载、Minecraft 1.20.1 启动、Fabric 安装 |
| `flutter build linux --release` | 见本轮验证结果 |
| `cargo fmt --all -- --check` | 通过 |
| `cargo clippy --all-targets -- -D warnings` | 通过 |
| `cargo test` | 9 个测试通过（含钥匙串账户名校验） |
| `cargo build --release` | 成功 |
| `tool/screenshots_test.dart --update-goldens` | 13 张页面截图生成并通过 |
| Rust 边车识别 | Java 设置页显示 `Rust hcl-core`，说明二进制被真实调用 |

测试覆盖：设置序列化/边界、Java 版本解析、插件清单/安装/启停/卸载/版本兼容、统计聚合与筛选、微软设备码/轮询/慢速/错误映射/刷新、界面导航冒烟、未登录启动门禁。

## 5. 运行

```bash
flutter pub get
cargo build --release --manifest-path rust/hcl-core/Cargo.toml
flutter run -d linux
```

微软登录需自备 Azure client ID，见 `docs/quick-start.md` 第 3 节。插件安装见第 5 节。

## 6. 已知限制

- Windows 产物未在本轮构建；`windows/` runner 由 Flutter 官方模板生成。
- 截图来自 widget golden 渲染，图标与字体使用测试加载的 Noto Sans CJK、Material Icons 与 FluentIcons；实际运行使用系统字体。
- 令牌优先存入系统钥匙串；钥匙串不可用时回退 0600 文件。
- NeoForge 仅支持 1.20.2+；`maven.neoforged.net` 在部分网络不可达时安装页会明确报错。
- 插件声明式页面不支持动态代码、网络、文件与进程能力。
- 演示数据可在“HCL 标题 → 设置 → 个性化”中关闭，关闭后库/浏览/社区/统计只显示实际数据。

## 7. Git 状态

本轮未提交 Git。所有改动位于工作区，`prompt/` 原文未修改。
