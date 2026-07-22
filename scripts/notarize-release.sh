#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/notarize-release.sh <notarytool-keychain-profile>" >&2
  exit 64
fi

script_dir=${0:A:h}
project_root=${script_dir:h}
release_root=${project_root}/build/release
archive_path=${release_root}/Spellbook.xcarchive
app_path=${archive_path}/Products/Applications/Spellbook.app
profile=$1

if [[ ! -d "${app_path}" ]]; then
  echo "Archive is missing. Run scripts/archive-release.sh first." >&2
  exit 66
fi

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app_path}/Contents/Info.plist")
submission_zip=${release_root}/Spellbook-${version}-notary-submission.zip
final_zip=${release_root}/Spellbook-${version}.zip

ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${submission_zip}"
xcrun notarytool submit "${submission_zip}" --keychain-profile "${profile}" --wait
xcrun stapler staple "${app_path}"
xcrun stapler validate "${app_path}"
spctl --assess --type execute --verbose=2 "${app_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${final_zip}"

echo "Created notarized artifact ${final_zip}"
