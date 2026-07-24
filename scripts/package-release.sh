#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/app/macos/sources/todobar/Info.plist")"
APP="$ROOT/dist/TodoBar.app"
RELEASES="$ROOT/releases"
STAGING="$RELEASES/staging/TodoBar"
DMG="$RELEASES/TodoBar-$VERSION.dmg"
ZIP="$RELEASES/TodoBar-$VERSION.zip"
APP_NOTARY_ZIP="$RELEASES/staging/TodoBar-$VERSION-app-notary.zip"
SIGN_IDENTITY="${SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:--}}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

cd "$ROOT"
SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/build-app.sh"

rm -rf "$STAGING" "$DMG" "$ZIP" "$APP_NOTARY_ZIP"
mkdir -p "$STAGING" "$RELEASES"

if [[ "$SIGN_IDENTITY" != "-" && -n "$NOTARY_PROFILE" ]]; then
    ditto -c -k --keepParent "$APP" "$APP_NOTARY_ZIP"
    xcrun notarytool submit "$APP_NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
fi

ditto "$APP" "$STAGING/TodoBar.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "TodoBar" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"

ditto -c -k --keepParent "$APP" "$ZIP"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

    if [[ -n "$NOTARY_PROFILE" ]]; then
        xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG"
    else
        echo "Skipping notarization because NOTARY_PROFILE is not set."
    fi
else
    echo "Created unsigned local packages. Use Developer ID signing before public distribution."
fi

rm -f "$APP_NOTARY_ZIP"

echo "Created $DMG"
echo "Created $ZIP"
