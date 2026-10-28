# 插件开发文档（Alpha）

适用版本：Hydrogen Chloride Launcher `0.1.0-alpha.1`

Alpha 插件系统只支持**声明式页面**：插件提供 `plugin.json`，启动器负责校验、渲染和动作白名单。插件代码不会在启动器进程中执行，也不会自动获得文件、网络或进程权限。

## 1. 设计原则

1. **先声明，后动态**：Alpha 不加载 Dart/原生动态库，避免权限与稳定性风险。
2. **最小权限**：动作必须显式声明权限；未声明的权限会被拒绝。
3. **可卸载**：插件只是数据目录下的一个文件夹，删除目录即可移除。
4. **可降级**：清单无效或要求更高启动器版本时，插件不会加载，并在插件管理页显示原因。

后续版本计划支持 Wasm 或独立进程宿主；Alpha 的清单格式会尽量保持兼容。

## 2. 目录结构

```text
<数据目录>/plugins/
└── hello-hcl/
    ├── plugin.json
    ├── README.md
    └── assets/            # 预留，Alpha 不渲染本地图片
```

- Linux 数据目录：`~/.local/share/hyalab/hydrogen-chloride-launcher/plugins/`
- Windows 数据目录：`%LOCALAPPDATA%\HyaLab\HydrogenChlorideLauncher\plugins\`

安装时启动器会把整个目录复制到 `<数据目录>/plugins/<插件 id>/`。插件 id 必须与目标目录名一致。

## 3. plugin.json

最小示例：

```json
{
  "id": "hello-hcl",
  "name": "Hello HCL",
  "version": "1.0.0",
  "author": "HyaLab",
  "description": "一个最小可用的声明式插件。",
  "minLauncherVersion": "0.1.0",
  "permissions": ["openUrl"],
  "contributes": {
    "pages": [
      {
        "id": "hello",
        "title": "Hello HCL",
        "icon": "auto_awesome",
        "widgets": [
          { "type": "heading", "text": "欢迎" },
          { "type": "paragraph", "text": "这个页面由启动器渲染。" }
        ]
      }
    ]
  }
}
```

### 3.1 顶层字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 2–64 位小写字母、数字、`.`、`_`、`-`；安装目录名必须一致 |
| `name` | string | 是 | 显示名称 |
| `version` | string | 是 | 插件版本，建议 SemVer |
| `author` | string | 否 | 作者，默认“未知作者” |
| `description` | string | 否 | 插件描述，显示在插件卡片 |
| `minLauncherVersion` | string | 否 | 最低启动器版本；高于当前版本时拒绝加载 |
| `permissions` | string[] | 否 | 动作权限，见第 6 节 |
| `contributes` | object | 否 | 页面等贡献点 |
| `contributes.pages` | array | 否 | 声明式页面列表 |

版本比较只比较数字段（忽略 `-alpha`、`+build` 之类的后缀），例如 `0.1.0-alpha.1` 视为 `0.1.0`。

### 3.2 页面字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 页面在插件内唯一 |
| `title` | string | 否 | 页面标题，默认“插件页面” |
| `icon` | string | 否 | 预置图标名，见 3.3 |
| `widgets` | array | 否 | 组件列表，按顺序渲染 |

预置图标：`auto_awesome`、`extension`、`rss_feed`、`science`、`settings`。其他值会显示默认扩展图标。

## 4. 组件

所有组件都是对象，`type` 决定类型。未知类型会渲染为一条警告，不会导致页面崩溃。

### 4.1 文本

```json
{ "type": "heading", "text": "一级标题" }
{ "type": "subheading", "text": "二级标题" }
{ "type": "paragraph", "text": "正文段落。" }
{ "type": "text", "text": "正文的别名。" }
```

- `heading`：22px 加粗，用于页面主标题。
- `subheading`：15px 半粗。
- `paragraph` / `text`：13px 正文，行高 1.75。

### 4.2 列表、分隔与留白

```json
{ "type": "list", "items": ["第一项", "第二项", { "text": "对象形式也可以" }] }
{ "type": "divider" }
{ "type": "spacer", "height": 20 }
```

### 4.3 代码块

```json
{ "type": "code", "text": "flutter run -d linux" }
```

使用等宽字体，内容可选中复制。

### 4.4 提示块

```json
{ "type": "callout", "tone": "info", "text": "普通提示。" }
{ "type": "callout", "tone": "warning", "text": "需要用户注意。" }
{ "type": "callout", "tone": "danger", "text": "危险或错误信息。" }
```

`tone` 默认 `info`。

### 4.5 布局

```json
{
  "type": "row",
  "children": [
    { "type": "button", "label": "按钮 A", "action": { "type": "showMessage", "text": "A" } },
    { "type": "button", "label": "按钮 B", "action": { "type": "showMessage", "text": "B" } }
  ]
}
```

```json
{
  "type": "column",
  "children": [
    { "type": "paragraph", "text": "第一段" },
    { "type": "divider" },
    { "type": "paragraph", "text": "第二段" }
  ]
}
```

`row` 使用自动换行布局；`column` 垂直排列。目前不支持嵌套深度限制之外的任意布局，建议控制在 5 层以内。

### 4.6 图片

```json
{ "type": "image", "url": "https://example.com/banner.png" }
```

Alpha **不会加载远程图片**，只渲染一个带 URL 的占位块，避免插件绕过网络权限。`assets/` 目录同样暂不渲染。

## 5. 按钮与动作

```json
{
  "type": "button",
  "label": "打开文档",
  "action": { "type": "openUrl", "url": "https://example.com/docs" }
}
```

支持的动作：

| 动作 | 参数 | 权限 | 行为 |
| --- | --- | --- | --- |
| `openUrl` | `url` | `openUrl` | 使用系统浏览器打开 http(s) 地址 |
| `openSettings` | `section` | 无 | 跳转到设置分区 |
| `showMessage` | `text` | 无 | 显示启动器消息条 |

`openSettings.section` 取值：`account`、`personalization`、`plugins`、`java`、`versions`、`statistics`、`about`。未知值回退到 `about`。

未声明 `openUrl` 权限时，按钮会显示为不可用，点击提示缺少权限。Alpha 不提供任意命令执行、文件读写、进程启动或网络请求动作。

## 6. 权限

当前只强制校验 `openUrl`。其余权限名会被记录并显示，但 Alpha 没有对应能力：

- `openUrl`：允许打开外部链接。
- `readPluginAssets`：预留。
- `network`：预留。
- `process`：预留。

请不要在 Alpha 中使用未实现的权限作为安全假设。插件清单中的权限是**上限声明**，启动器仍会按动作类型做白名单校验。

## 7. 生命周期

1. **安装**：从目录复制到 `plugins/<id>`；校验 id、必填字段、最低版本；重复 id 会拒绝。
2. **加载**：启动器扫描 `plugins/*/plugin.json`；无效清单进入“无法加载的插件”列表。
3. **启用/禁用**：状态保存在配置目录 `plugin_state.json`；禁用的插件页面不可打开，但文件保留。
4. **卸载**：删除插件目录并清理状态；不会影响库、统计、账户或订阅数据。
5. **重新加载**：插件管理页的“重新加载”会重新扫描磁盘。

安装后建议在 **插件管理** 点击“重新加载”确认状态。

## 8. 完整示例

仓库中的 `examples/plugins/hello-hcl/` 是一个可直接安装的示例，包含：

- 页面标题与说明；
- 列表组件；
- 权限声明；
- `openUrl` 按钮；
- 插件目录 README。

安装方式：

1. 点击左上角 **HCL** 标题打开设置 → **插件管理 → 安装插件**；
2. 选择 `examples/plugins/hello-hcl/`；
3. 点击 **打开页面：Hello HCL**。

## 9. 安全模型与限制

- 插件是**数据**，不是代码；Alpha 不执行 `plugin.json` 之外的任何内容。
- 插件不能读取库、账户、令牌或文件系统。
- `openUrl` 只接受字符串 URL，由系统浏览器处理；启动器不做下载。
- 声明式页面会由启动器统一套用主题和间距，插件不能注入任意 Widget、CSS 或脚本。
- Alpha 没有插件签名、市场或自动更新；请只安装可信来源的插件目录。
- 版本升级可能新增组件/动作；请用 `minLauncherVersion` 声明依赖。

## 10. 后续路线

- 独立进程或 Wasm 插件宿主，提供受控的文件/网络能力。
- 插件资源图片与本地化字符串。
- 库条目、启动前/后钩子、设置页扩展。
- 插件签名与更新源。
- 更完整的 schema 校验与错误定位（行号/字段路径）。
