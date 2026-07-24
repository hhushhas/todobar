#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/TodoBar.app"
INSTALL_APP="/Applications/TodoBar.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
# Use ad-hoc signing for local builds unless a Developer ID identity is provided.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
INSTALL_TO_APPLICATIONS="${INSTALL_TO_APPLICATIONS:-0}"
LAUNCH="${LAUNCH:-0}"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/TodoBar" "$MACOS/TodoBar"

# SPM resource bundles ship raw .xcassets/.xcstrings from `swift build`;
# AppKit needs them compiled (Assets.car / .lproj strings) or ClerkKitUI
# renders unstyled.
for bundle in .build/release/*.bundle; do
    dest="$RESOURCES/$(basename "$bundle")"
    cp -R "$bundle" "$dest"

    catalogs=("$dest"/*.xcassets)
    if [[ -d "${catalogs[0]}" ]]; then
        xcrun actool "${catalogs[@]}" --compile "$dest" \
            --platform macosx --minimum-deployment-target 26.0 \
            --output-format human-readable-text > /dev/null
        rm -rf "${catalogs[@]}"
    fi

    for strings in "$dest"/*.xcstrings; do
        [[ -f "$strings" ]] || continue
        xcrun xcstringstool compile "$strings" --output-directory "$dest"
        rm -f "$strings"
    done
done

cp "app/macos/sources/todobar/Info.plist" "$CONTENTS/Info.plist"
cp "app/macos/assets/branding/TodoBarIcon.icns" "$RESOURCES/TodoBarIcon.icns"
cp "app/macos/assets/branding/todobar-menubar-option-3-18.png" "$RESOURCES/TodoBarMenuBarIcon.png"
cp "app/macos/assets/branding/todobar-menubar-option-3-36.png" "$RESOURCES/TodoBarMenuBarIcon@2x.png"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

echo "Built $APP"

if [[ "$INSTALL_TO_APPLICATIONS" == "1" ]]; then
    osascript -e 'tell application id "com.hasanshoaib.todobar" to quit' > /dev/null 2>&1 || true
    sleep 1
    pkill -x TodoBar > /dev/null 2>&1 || true

    rm -rf "$INSTALL_APP"
    ditto "$APP" "$INSTALL_APP"
    echo "Installed $INSTALL_APP"
fi

if [[ "$LAUNCH" == "1" ]]; then
    if [[ "$INSTALL_TO_APPLICATIONS" == "1" ]]; then
        open -n "$INSTALL_APP"
        echo "Launched $INSTALL_APP"
    else
        open -n "$APP"
        echo "Launched $APP"
    fi
fi
