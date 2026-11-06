# 构建与打包

## Linux

```bash
flutter pub get
flutter build linux --release

tar -C build/linux/x64/release -czf dist/hcl-linux-x64.tar.gz bundle
```

Linux 构建依赖：

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

## Windows

Windows 构建必须在 Windows 上执行，并且安装：

- Flutter 3.47+
- Visual Studio 2022 Build Tools，勾选 **Desktop development with C++**

```powershell
flutter pub get
flutter build windows --release
Compress-Archive -Path build/windows/x64/runner/Release/* `
  -DestinationPath dist/hcl-windows-x64.zip -Force
```

也可以直接运行仓库中的 `tool/build_windows.ps1`。

当前 Linux 构建机没有 Windows 的 Flutter/VS Build Tools，因此本轮只交付 Windows 源码与构建脚本，不提供 Windows 二进制。
