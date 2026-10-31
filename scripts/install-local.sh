#!/bin/bash
# Patched fork: build Release, install over /Applications/Clipbara.app, relaunch.
# Signs ad-hoc without the hardened runtime (library validation rejects the
# ad-hoc Sparkle.framework otherwise) and pins the designated requirement to
# the bundle id, like build-release.sh, so Accessibility survives rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
BUNDLE_ID=com.minsang.PasteClip
APP=scratch/dd-release/Build/Products/Release/Clipbara.app

xcodegen generate -q
xcodebuild -project Clipbara.xcodeproj -scheme Clipbara -configuration Release \
    -derivedDataPath scratch/dd-release CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build \
    | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'

ENT=$(mktemp -t clipbara-ent).plist
codesign -d --entitlements "$ENT" --xml "$APP"
codesign --force --deep --sign - "$APP"
codesign --force --sign - --entitlements "$ENT" \
    --requirements "=designated => identifier \"${BUNDLE_ID}\"" "$APP"

osascript -e "tell application id \"${BUNDLE_ID}\" to quit" || true
sleep 2
[ -e /Applications/Clipbara.app ] && trash /Applications/Clipbara.app
ditto "$APP" /Applications/Clipbara.app
open /Applications/Clipbara.app
codesign -d -r- /Applications/Clipbara.app 2>&1 | grep designated
