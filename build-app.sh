#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/swift-cache"
export XDG_CACHE_HOME="$ROOT/.build/xdg-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE" "$XDG_CACHE_HOME"
swift build --disable-sandbox -c release
APP="$ROOT/dist/LangPilot.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/release/LangPilot "$APP/Contents/MacOS/LangPilot"
cp App/Info.plist "$APP/Contents/Info.plist"
cp App/LangPilotIcon.png "$APP/Contents/Resources/LangPilotIcon.png"
cp "$ROOT/App/LangPilot.iconset"/*.png "$ROOT/App/Assets.xcassets/AppIcon.appiconset/"
xcrun actool "$ROOT/App/Assets.xcassets" \
  --compile "$APP/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$ROOT/.build/asset-info.plist"
codesign --force --deep --sign - "$APP"
echo "$APP"
