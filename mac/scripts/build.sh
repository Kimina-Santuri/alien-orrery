#!/bin/sh
# Builds build/Orrery.app (ad-hoc signed) with the current ../index.html inside.
# With --install, copies it to /Applications and opens it.
# With --mine, also puts ../local/setups.js inside: private additions for this Mac only. Never release a --mine build.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Orrery.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Orrery "$APP/Contents/MacOS/Orrery"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp ../index.html "$APP/Contents/Resources/orrery.html"
case " $* " in *" --mine "*)
  if [ -f ../local/setups.js ]; then
    python3 -c "
import sys
page, extra = sys.argv[1], open(sys.argv[2]).read()
assert '</script' not in extra
s = open(page).read()
open(page, 'w').write(s.replace('<script>', '<script>\n' + extra + '\n</script>\n<script>', 1))
" "$APP/Contents/Resources/orrery.html" ../local/setups.js
    echo "Included local/setups.js: this build is private, do not release it"
  fi ;;
esac
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"
case " $* " in *" --install "*)
  pkill -x Orrery 2>/dev/null || true
  rm -rf /Applications/Orrery.app
  cp -R "$APP" /Applications/Orrery.app
  open /Applications/Orrery.app
  echo "Installed and opened /Applications/Orrery.app" ;;
esac
