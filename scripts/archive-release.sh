#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
release_root=${project_root}/build/release
archive_path=${release_root}/Spellbook.xcarchive

: "${SPELLBOOK_DEVELOPMENT_TEAM:?Set SPELLBOOK_DEVELOPMENT_TEAM to the Apple team identifier.}"

signing_identity=${SPELLBOOK_SIGNING_IDENTITY:-Developer ID Application}

mkdir -p "${release_root}"

DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer} \
  xcodebuild \
  -project "${project_root}/Spellbook.xcodeproj" \
  -scheme Spellbook \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${archive_path}" \
  DEVELOPMENT_TEAM="${SPELLBOOK_DEVELOPMENT_TEAM}" \
  CODE_SIGN_IDENTITY="${signing_identity}" \
  archive

app_path=${archive_path}/Products/Applications/Spellbook.app
codesign --verify --deep --strict --verbose=2 "${app_path}"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app_path}/Contents/Info.plist")
zip_path=${release_root}/Spellbook-${version}.zip
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${zip_path}"

echo "Created ${zip_path}"
