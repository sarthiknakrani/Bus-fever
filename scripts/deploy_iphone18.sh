#!/bin/bash
set -e

# Default to iPhone Air: D2AB00FB-EA40-4523-A22C-A426DDC30AD1
SIM_ID="${1:-D2AB00FB-EA40-4523-A22C-A426DDC30AD1}"
APP_BUNDLE_ID="org.godotengine.busfeverparty"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Exporting Godot project ==="
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-debug "iOS" "$PROJECT_DIR/build/ios/BusFeverParty.zip"

echo "=== Applying Simulator Patches ==="
cp "$PROJECT_DIR/build/libgodot_sim_arm64.a" "$PROJECT_DIR/build/ios/BusFeverParty.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
sed -i '' 's/TARGETED_DEVICE_FAMILY = "2";/TARGETED_DEVICE_FAMILY = "1,2";/g' "$PROJECT_DIR/build/ios/BusFeverParty.xcodeproj/project.pbxproj"
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' "$PROJECT_DIR/build/ios/BusFeverParty.xcodeproj/project.pbxproj"

if ! grep -q "MTLIOErrorDomain" "$PROJECT_DIR/build/ios/BusFeverParty/dummy.cpp"; then
  cat << 'EOF' >> "$PROJECT_DIR/build/ios/BusFeverParty/dummy.cpp"
extern "C" {
    __attribute__((weak)) void* MTLIOErrorDomain = (void*)0x1;
    __attribute__((weak)) void* MTLTensorDomain = (void*)0x1;
}
EOF
fi

echo "=== Building Xcode project for iPhone 18 Pro Simulator ==="
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$PROJECT_DIR/build/ios/BusFeverParty.xcodeproj" \
  -scheme BusFeverParty \
  -destination "id=$SIM_ID" \
  -configuration Debug \
  build

APP_PATH="/Users/nakranisarthikashokbhai/Library/Developer/Xcode/DerivedData/BusFeverParty-fywsuvuvgfqlsgefeljhwxfaeyzr/Build/Products/Debug-iphonesimulator/BusFeverParty.app"

echo "=== Ensuring Simulator is Booted ==="
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator 2>/dev/null || true

echo "=== Installing on Simulator ==="
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install "$SIM_ID" "$APP_PATH"

echo "=== Relaunching Bus Fever Party on iPhone 18 Pro ==="
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate "$SIM_ID" "$APP_BUNDLE_ID" 2>/dev/null || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch "$SIM_ID" "$APP_BUNDLE_ID"

echo "=== Done! Bus Fever Party is running on iPhone 18 Pro ==="
