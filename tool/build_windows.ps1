$ErrorActionPreference = "Stop"

flutter pub get
flutter build windows --release

Copy-Item "LICENSE" "build/windows/x64/runner/Release/" -Force
New-Item -ItemType Directory -Force -Path "build/windows/x64/runner/Release/licenses" | Out-Null
Copy-Item "assets/fonts/MapleMono-LICENSE.txt" "build/windows/x64/runner/Release/licenses/" -Force
New-Item -ItemType Directory -Force -Path "dist" | Out-Null
Compress-Archive -Path "build/windows/x64/runner/Release/*" `
  -DestinationPath "dist/hydrogen-chloride-launcher-0.1.0-alpha.1-windows-x64.zip" -Force

Write-Host "Built dist/hydrogen-chloride-launcher-0.1.0-alpha.1-windows-x64.zip"
