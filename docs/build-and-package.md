# 构建与打包

## Linux

```bash
flutter pub get
cargo build --release --manifest-path rust/hcl-core/Cargo.toml
flutter build linux --release

cp rust/hcl-core/target/release/hcl-core build/linux/x64/release/bundle/
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
- Rust 1.98+（MSVC 工具链）

```powershell
flutter pub get
cargo build --release --manifest-path rust/hcl-core/Cargo.toml
flutter build windows --release
Copy-Item rust/hcl-core/target/release/hcl-core.exe build/windows/x64/runner/Release/
Compress-Archive -Path build/windows/x64/runner/Release/* `
  -DestinationPath dist/hcl-windows-x64.zip -Force
```

也可以直接运行仓库中的 `tool/build_windows.ps1`。

当前 Linux 构建机没有 Windows 的 Flutter/VS Build Tools，因此本轮只交付 Windows 源码与构建脚本，不提供 Windows 二进制。
