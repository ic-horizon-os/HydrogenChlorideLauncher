$ErrorActionPreference = "Stop"

flutter pub get
flutter build windows --release

# pubspec.yaml 的 version 行（去掉 +build 号）决定压缩包名。
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^\s]+)').Matches[0].Groups[1].Value
$version = $version.Split('+')[0]
$zip = "dist/hydrogen-chloride-launcher-$version-windows-x64.zip"

Copy-Item "LICENSE" "build/windows/x64/runner/Release/" -Force
New-Item -ItemType Directory -Force -Path "build/windows/x64/runner/Release/licenses" | Out-Null
Copy-Item "assets/fonts/MapleMono-LICENSE.txt" "build/windows/x64/runner/Release/licenses/" -Force
New-Item -ItemType Directory -Force -Path "dist" | Out-Null
Compress-Archive -Path "build/windows/x64/runner/Release/*" -DestinationPath $zip -Force

Write-Host "Built $zip"
# 后续 workflow 步骤通过 HCL_WIN_ZIP 引用产物路径。
if ($env:GITHUB_ENV) {
  Add-Content $env:GITHUB_ENV "HCL_WIN_ZIP=$zip"
}
