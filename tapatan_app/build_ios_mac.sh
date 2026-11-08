#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# tap@tan — macOS Local iOS .ipa Build Script
# ==============================================================================
# Usage (on macOS with Xcode & Flutter installed):
#   cd tapatan_app
#   chmod +x build_ios_mac.sh
#   ./build_ios_mac.sh
#
# Output:
#   ../builds/tapatan-app-v2-ios.ipa (unsigned .ipa for sideloading / re-signing)
#
# Note on Physical iPhone CoreNFC:
#   To scan the physical JCOP4 J3R150 Java Card over CoreNFC on an iPhone, open
#   ios/Runner.xcworkspace in Xcode, select your Apple Developer Team (with the
#   "Near Field Communication Tag Reading" capability enabled for Runner), and
#   run/archive directly onto your iPhone.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/5] Fetching Flutter packages..."
flutter pub get

echo "==> [2/5] Running static analysis & tests..."
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test

echo "==> [3/5] Installing CocoaPods in ios/..."
(cd ios && pod install)

echo "==> [4/5] Building iOS Release Runner.app (--no-codesign)..."
flutter build ios --release --no-codesign

echo "==> [5/5] Packaging ../builds/tapatan-app-v2-ios.ipa..."
mkdir -p ../builds
rm -rf build/ios/ipa_out
mkdir -p build/ios/ipa_out/Payload
cp -R build/ios/iphoneos/Runner.app build/ios/ipa_out/Payload/Runner.app
(
  cd build/ios/ipa_out
  zip -qry "$SCRIPT_DIR/../builds/tapatan-app-v2-ios.ipa" Payload
)
rm -rf build

echo "Done! iOS package written to: $(cd ../builds && pwd)/tapatan-app-v2-ios.ipa"

