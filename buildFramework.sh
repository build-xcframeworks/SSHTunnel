#!/bin/bash

set -e

ROOT=$(pwd)
ARCHIVE_ROOT="$ROOT/build/archives"
OUTPUT="$ROOT/output"
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
SDK_MIN_IOS_VERSION=$(/usr/bin/plutil -extract SupportedTargets.iphoneos.MinimumDeploymentTarget raw -o - "$SDK_PATH/SDKSettings.plist")
MIN_IOS_VERSION=${MIN_IOS_VERSION:-$SDK_MIN_IOS_VERSION}

rm -R -f "$ARCHIVE_ROOT" "$OUTPUT/SSHTunnel.xcframework"
mkdir -p "$ARCHIVE_ROOT" "$OUTPUT"

archiveFramework() {
  local destination=$1
  local archive_path=$2
  local architectures=$3

  xcodebuild archive \
    -project SSHTunnel.xcodeproj \
    -scheme SSHTunnel \
    -destination "$destination" \
    -archivePath "$archive_path" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO \
    ARCHS="$architectures" \
    SWIFT_VERSION=5.0 \
    IPHONEOS_DEPLOYMENT_TARGET="$MIN_IOS_VERSION"
}

archiveFramework "generic/platform=iOS" "$ARCHIVE_ROOT/SSHTunnel-iOS" "arm64"
archiveFramework "generic/platform=iOS Simulator" "$ARCHIVE_ROOT/SSHTunnel-Simulator" "arm64"
archiveFramework "generic/platform=macOS,variant=Mac Catalyst" "$ARCHIVE_ROOT/SSHTunnel-Catalyst" "arm64 x86_64"

xcodebuild -create-xcframework \
  -framework "$ARCHIVE_ROOT/SSHTunnel-iOS.xcarchive/Products/Library/Frameworks/SSHTunnel.framework" \
  -framework "$ARCHIVE_ROOT/SSHTunnel-Simulator.xcarchive/Products/Library/Frameworks/SSHTunnel.framework" \
  -framework "$ARCHIVE_ROOT/SSHTunnel-Catalyst.xcarchive/Products/Library/Frameworks/SSHTunnel.framework" \
  -output "$OUTPUT/SSHTunnel.xcframework"
