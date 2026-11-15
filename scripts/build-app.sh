#!/bin/zsh
# 构建 uuvd.app（ad-hoc 签名；每次构建后辅助功能授权会失效，需重新授权）
# 用法：scripts/build-app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION 2>/dev/null || echo 0.1.0)"
APP="build/uuvd.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c release --product uuvd
BIN="$(swift build -c release --show-bin-path)/uuvd"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/uuvd"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.tz.uuvd</string>
  <key>CFBundleName</key><string>uuvd</string>
  <key>CFBundleExecutable</key><string>uuvd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAccessibilityUsageDescription</key><string>uuvd 读取 UU远程 窗口文字以识别控制端设备</string>
</dict>
</plist>
PLIST
codesign --force --sign "$SIGN_IDENTITY" "$APP"
echo "✅ 已构建 $APP（$VERSION，签名：$SIGN_IDENTITY）"

if [[ "${1:-}" == "--install" ]]; then
  cp -R "$APP" /Applications/
  open "/Applications/uuvd.app"
  echo "✅ 已安装并启动"
fi
