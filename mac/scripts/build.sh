#!/bin/sh
# Builds build/Orrery.app (ad-hoc signed) with the current ../index.html inside.
# With --install, copies it to /Applications and opens it.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Orrery.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Orrery "$APP/Contents/MacOS/Orrery"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp ../index.html "$APP/Contents/Resources/orrery.html"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"
if [ "$1" = "--install" ]; then
  pkill -x Orrery 2>/dev/null || true
  rm -rf /Applications/Orrery.app
  cp -R "$APP" /Applications/Orrery.app
  open /Applications/Orrery.app
  echo "Installed and opened /Applications/Orrery.app"
fi
