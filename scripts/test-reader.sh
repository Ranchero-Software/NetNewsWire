#!/bin/bash
set -euo pipefail

reader_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$reader_root"
reader_platform=${1:-all}
reader_xcodebuild=${READER_XCODEBUILD:-xcodebuild}
reader_results=${READER_RESULTS_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/reader-results.XXXXXX")}
mkdir -p "$reader_results"
if [[ ${READER_SKIP_GENERATION:-0} != 1 ]]; then
    python3 ReaderApp/generate_project.py
fi

reader_destination() {
    xcrun simctl list devices available --json | python3 -c '
import json, sys
kind = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if ".iOS-27-" not in runtime:
        continue
    for device in devices[runtime]:
        if device["name"].startswith(kind) and device.get("isAvailable", False):
            print("platform=iOS Simulator,id=" + device["udid"])
            sys.exit(0)
sys.exit("Kein passender Simulator ab iOS 27 verfügbar")
' "$1"
}

reader_run() {
    local reader_kind=$1
    local reader_dest=$2
    local reader_derived="$reader_results/$reader_kind-derived"
    # Leave package resource bundles at their default unsigned setting.
    local reader_signing=(CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual)
    "$reader_xcodebuild" -project Reader.xcodeproj -scheme Reader -testPlan Reader \
        -destination "$reader_dest" -derivedDataPath "$reader_derived" \
        "${reader_signing[@]}" build-for-testing
    if [[ "$reader_kind" == macos && ${READER_SKIP_SIGNATURE_CHECK:-0} != 1 ]]; then
        codesign --verify --deep --strict "$reader_derived/Build/Products/Debug/Reader.app"
        codesign --verify --deep --strict "$reader_derived/Build/Products/Debug/ReaderSmokeTests-Runner.app"
    fi
    "$reader_xcodebuild" -project Reader.xcodeproj -scheme Reader -testPlan Reader \
        -destination "$reader_dest" -derivedDataPath "$reader_derived" \
        -resultBundlePath "$reader_results/$reader_kind.xcresult" \
        "${reader_signing[@]}" test-without-building
}

case "$reader_platform" in
    macos) reader_run macos 'platform=macOS,arch=arm64' ;;
    ios) reader_run ios "${READER_IOS_DESTINATION:-$(reader_destination iPhone)}" ;;
    ipad) reader_run ipad "${READER_IPAD_DESTINATION:-$(reader_destination iPad)}" ;;
    all)
        reader_run macos 'platform=macOS,arch=arm64'
        reader_run ios "${READER_IOS_DESTINATION:-$(reader_destination iPhone)}"
        reader_run ipad "${READER_IPAD_DESTINATION:-$(reader_destination iPad)}"
        ;;
    *) echo 'Aufruf: scripts/test-reader.sh [all|macos|ios|ipad]' >&2; exit 2 ;;
esac
echo "Reader-Prüfung erfolgreich: $reader_platform; Ergebnisse: $reader_results"
