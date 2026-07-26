#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
VERSION="${1:-2.0-beta.2}"
STAGE="$ROOT/.build/dmg-root"
OUT="$ROOT/dist/LangPilot-$VERSION.dmg"
mkdir -p "$STAGE/.background"
ditto "$ROOT/dist/LangPilot.app" "$STAGE/LangPilot.app"
ln -sfn /Applications "$STAGE/Applications"
cp "$ROOT/App/DMGBackground.png" "$STAGE/.background/background.png"
if ! hdiutil create -volname "LangPilot $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$OUT"; then
  hdiutil makehybrid -hfs -hfs-volume-name "LangPilot $VERSION" -o "$OUT" "$STAGE"
fi
shasum -a 256 "$OUT" > "$OUT.sha256"
echo "$OUT"
