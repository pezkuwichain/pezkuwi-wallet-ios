#!/usr/bin/env bash
# Prepares a CI environment that can compile the app for the iOS simulator and run the
# unit tests without any real credentials.
#
# - Exports a placeholder value for every variable Scripts/inject-keys.sh passes to
#   Sourcery (that script runs under `set -u`, so each one must be set). The generated
#   CIKeys.generated.swift then contains the placeholder instead of an API key.
# - Writes dummy GoogleService-Info-{Dev,Release}.plist files, which the
#   "Copy GoogleService-Info.plist" build phase requires to exist.
#
# None of these values is a secret, and builds made with them must not be distributed.
set -euo pipefail

PLACEHOLDER="ci-placeholder-not-a-secret"

KEY_VARS=(
  MERCURYO_PRODUCTION_SECRET
  MERCURYO_TEST_SECRET
  ACALA_AUTH_TOKEN
  ACALA_TEST_AUTH_TOKEN
  MOONBEAM_HISTORY_API_KEY
  MOONRIVER_HISTORY_API_KEY
  ETHERSCAN_HISTORY_API_KEY
  MOONBEAM_API_KEY
  MOONBEAM_TEST_API_KEY
  INFURA_API_KEY
  WC_PROJECT_ID
  DWELLIR_API_KEY
  POLKASSEMBLY_SUMMARY_API_KEY
)

if [ -z "${GITHUB_ENV:-}" ]; then
  echo "GITHUB_ENV is not set; this script is meant to run inside GitHub Actions." >&2
  exit 1
fi

for name in "${KEY_VARS[@]}"; do
  echo "${name}=${PLACEHOLDER}" >> "$GITHUB_ENV"
done

write_plist() {
  cat > "$1" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>
  <string>${PLACEHOLDER}</string>
  <key>GCM_SENDER_ID</key>
  <string>000000000000</string>
  <key>PLIST_VERSION</key>
  <string>1</string>
  <key>BUNDLE_ID</key>
  <string>ci.placeholder</string>
  <key>PROJECT_ID</key>
  <string>ci-placeholder</string>
  <key>STORAGE_BUCKET</key>
  <string>ci-placeholder.appspot.com</string>
  <key>IS_ADS_ENABLED</key>
  <false/>
  <key>IS_ANALYTICS_ENABLED</key>
  <false/>
  <key>IS_APPINVITE_ENABLED</key>
  <false/>
  <key>IS_GCM_ENABLED</key>
  <false/>
  <key>IS_SIGNIN_ENABLED</key>
  <false/>
  <key>GOOGLE_APP_ID</key>
  <string>1:000000000000:ios:0000000000000000000000</string>
</dict>
</plist>
PLIST
}

write_plist "./novawallet/GoogleService-Info-Dev.plist"
write_plist "./novawallet/GoogleService-Info-Release.plist"

echo "Placeholder keys exported (${#KEY_VARS[@]} variables) and dummy GoogleService plists written."
