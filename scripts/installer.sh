#!/bin/bash
# Compile KeepAwake, l'installe dans ~/Applications et le lance.
# Relancer ce script apres toute modification de src/main.swift.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$HOME/Applications/KeepAwake.app"
bundle_id="fr.cadenzia.keep-awake"

# Ne remplace jamais une autre application du meme nom.
if [[ -e "$app_dir" ]]; then
  installed_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_dir/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$installed_id" != "$bundle_id" ]]; then
    echo "Une autre application occupe $app_dir (identifiant : ${installed_id:-inconnu}). Rien n'a ete modifie." >&2
    exit 1
  fi
fi

# Compile d'abord : si la compilation echoue, la version installee reste en place et continue de tourner.
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
swiftc -O -framework AppKit -framework IOKit "$project_dir/src/main.swift" -o "$build_dir/KeepAwake"

pkill -x KeepAwake 2>/dev/null || true

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$build_dir/KeepAwake" "$app_dir/Contents/MacOS/KeepAwake"
cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$bundle_id</string>
  <key>CFBundleName</key><string>KeepAwake</string>
  <key>CFBundleExecutable</key><string>KeepAwake</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app_dir"
open "$app_dir"

echo "KeepAwake installe et lance : $app_dir"
