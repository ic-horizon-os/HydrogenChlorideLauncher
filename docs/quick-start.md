# 快速使用

本文档对应 Alpha `0.1.0-alpha.1`。当前版本用于试用界面和登录，**不生成安装包**。

## 1. 环境要求

| 平台 | 要求 |
| --- | --- |
| Windows 10/11 | Flutter 3.47+、Visual Studio 2022（Desktop development with C++）、Rust 1.98+ |
| Linux | Flutter 3.47+、Rust 1.98+、`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` |

Ubuntu/Debian 安装 Linux 桌面依赖：

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev unzip
```

Arch Linux：

```bash
sudo pacman -S --needed clang cmake ninja pkg-config gtk3
```

检查工具链：

```bash
flutter doctor -v
rustc --version
```

`flutter doctor` 中 Android Studio、Chrome 的报错可以忽略，只要 Linux toolchain 或 Visual Studio 一行通过。

## 2. 获取依赖并运行

在仓库根目录：

```bash
flutter pub get

# 可选：构建 Rust 边车。不构建时启动器会自动使用纯 Dart 回退。
cargo build --release --manifest-path rust/hcl-core/Cargo.toml

flutter run -d linux
# Windows 上：
flutter run -d windows
```

Rust 二进制查找顺序：

1. 环境变量 `HCL_CORE_PATH`
2. 启动器可执行文件同目录
3. `rust/hcl-core/target/release` 或 `debug`
4. 找不到时使用 Dart 回退

点击左上角 **HCL** 标题打开设置，在 **Java 设置** 查看当前使用的后端（`Rust hcl-core` 或 `Dart 回退`）。

## 3. 配置微软登录

Alpha 不内置 Azure client ID，也不保存任何密钥。需要你创建自己的应用：

1. 打开 [Azure Portal](https://portal.azure.com/) → **App registrations** → **New registration**。
2. 支持的账户类型选择包含**个人 Microsoft 账户**的选项。
3. 进入 **Authentication**，把 **Allow public client flows** 设为 **Yes**。
4. 复制 **Application (client) ID**。
5. 点击左上角 **HCL** 标题打开设置，在 **登录信息** 填入并保存，或在启动前设置环境变量：

```bash
export HCL_MS_CLIENT_ID="00000000-0000-0000-0000-000000000000"
```

6. 点击 **开始设备码登录**，在浏览器打开 `https://microsoft.com/link`，输入界面显示的代码。

登录链路：

```text
Microsoft OAuth 设备码
  → Xbox Live 用户认证
  → XSTS 授权
  → Minecraft Services 登录
  → Minecraft 档案
```

注意事项：

- 默认**不需要任何配置**：点「使用设备码登录」，把显示的代码输入到 `microsoft.com/link` 即可。
- 内置的是通用公开 client ID（`00000000402b5328`），令牌发给该应用而非本启动器，介意请换成自建应用。
- 想用「浏览器登录」：在 Azure Portal 新建应用，账户类型含个人账户，Authentication 添加平台「移动和桌面应用程序」并勾选 `http://localhost`，然后把 client ID 填进设置。
- 两种流程都**不需要 client secret**，不要把 secret 提交到仓库。
- 未登录时，Minecraft 与整合包条目会被禁止启动；自定义程序与实用软件不受影响。
- 令牌优先存入系统钥匙串（Linux Secret Service / Windows DPAPI）；钥匙串不可用时回退到本机 `account.json`（0600）。共享设备上请在使用后退出登录。
- 如果账户没有 Minecraft: Java Edition 档案，界面会提示“无 Minecraft 档案”。

## 4. 试用界面

首次启动会写入一套演示数据（库、浏览、社区、会话），UI 中会显示“演示数据”标签。

- **浏览**：切换模组/整合包/光影/加载器，使用搜索与筛选；点击卡片查看详情。
- **库**：左侧列表选择条目，右侧主视觉；右键条目打开 Steam 式菜单。条目设置里可以打开**版本隔离**。
- **启动**：库中点击“启动”会先在状态栏显示阶段（检查版本 → 准备 Java → 下载运行时），随后启动真实的游戏进程；退出或点击“停止”后写入会话，统计页立即更新。游戏日志写到实例目录的 `logs/hcl-launch-*.log`。
- **社区**：三栏阅读器；右上角“添加站点/添加订阅”。
- 点击左上角 **HCL** 标题打开设置；**个性化**：切换亮/暗色、强调色、背景图片、透明度、模糊方式。
- **插件管理**：安装示例插件并打开声明式页面。
- **关于**：能力矩阵、GitHub、开源许可与免责声明。

点击左上角 **HCL** 标题打开设置，在 **个性化** 中关闭 **显示演示数据** 后，库、浏览、社区和统计只显示你实际添加的数据。

## 5. 安装示例插件

1. 点击左上角 **HCL** 标题打开设置，进入 **插件管理**。
2. 点击 **安装示例插件**（从仓库根目录运行时可用），或点击 **安装插件** 选择 `examples/plugins/hello-hcl/`。
3. 在插件卡片上点击 **打开页面：Hello HCL**。
4. 卸载会删除插件目录，不影响库、统计与账户数据。

插件目录位于数据目录下的 `plugins/`，可在插件管理页直接打开。

## 6. 数据与重置

| 内容 | Linux | Windows |
| --- | --- | --- |
| 设置/账户/库/统计/订阅 | `~/.config/hyalab/hydrogen-chloride-launcher/` | `%APPDATA%\HyaLab\HydrogenChlorideLauncher\` |
| 插件/背景图/日志 | `~/.local/share/hyalab/hydrogen-chloride-launcher/` | `%LOCALAPPDATA%\HyaLab\HydrogenChlorideLauncher\` |

完整重置（会删除登录令牌与所有本地数据）：

```bash
rm -rf ~/.config/hyalab/hydrogen-chloride-launcher \
       ~/.local/share/hyalab/hydrogen-chloride-launcher
```

## 7. 常见问题

**`flutter doctor` 提示缺少 clang**

```bash
sudo apt install -y clang
```

**构建时报 GTK 头文件缺失**

```bash
sudo apt install -y libgtk-3-dev
```

**Java 设置里没有运行时**

安装任意 JDK/JRE 后点击“重新扫描”：

```bash
sudo apt install -y openjdk-21-jre-headless
```

也可以手动填写 `java` 可执行文件路径。Alpha 只保存配置，不会真正拉起 Java 进程。

**登录时提示缺少 client ID**

确认已在设置中保存，或环境变量 `HCL_MS_CLIENT_ID` 在启动器启动前生效。

**登录返回 XSTS 2148916233 / 2148916238**

前者表示账户没有 Xbox 档案（先在 xbox.com 登录一次），后者表示儿童账户需要家庭组授权。

**窗口没有标题栏按钮**

启动器使用自绘标题栏。Windows/Linux 需要 `window_manager` 插件；调试时若插件未注册，标题栏按钮会静默失效。

## 8. 边界

- 安装新版本：**库** → 右上角 **安装版本**，二级菜单选版本；可在同一对话框选择 Fabric/Forge/NeoForge 一并安装。
- 多目录：设置 → **版本管理** 添加多个 `.minecraft` 目录，版本列表会合并展示；下载源也在这一页。
- 加载器：库详情 → **加载器**，选择加载器与版本后安装；OptiFine 需要先导入官网下载的安装文件。
- 在线内容：浏览页来自 Modrinth；社区订阅会真实抓取 RSS/Atom。
- 世界修复：库详情 → **世界** → 修复按钮，会检查 `level.dat` 并备份后修复。
- 自动更新：设置 → **关于** → 更新，填写更新清单地址后可检查、下载并应用。
- 披风上传、CurseForge 整合包、离线账户、代码签名与增量更新尚未实现。
- Windows 构建源码已生成，但本轮验证环境为 Linux/WSL。
