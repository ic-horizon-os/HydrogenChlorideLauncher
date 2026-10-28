# Hello HCL

可安装的 Alpha 示例插件，用于验证声明式插件页面。

## 安装

1. 启动 Hydrogen Chloride Launcher。
2. 打开 **设置 → 插件管理**。
3. 点击 **安装插件**，选择本目录（`examples/plugins/hello-hcl/`）。
4. 点击 **打开页面：Hello HCL**。

也可以从仓库根目录运行启动器，然后使用插件管理页的 **安装示例插件** 按钮。

## 结构

```text
hello-hcl/
└── plugin.json
```

`plugin.json` 包含：

- 元数据：id、名称、版本、作者、最低启动器版本；
- 权限：`openUrl`；
- 一个声明式页面：标题、说明、列表、提示块、代码块与按钮动作。

## 说明

- 插件不会执行代码，页面由启动器渲染。
- `openUrl` 按钮只有在声明权限后才可用。
- 卸载会删除插件目录，不影响其他数据。

完整规范见仓库 `docs/plugin-development.md`。
