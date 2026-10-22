#!/bin/bash
# =============================================================================
#  INSTALL ONLY - Pype Dialer
#  Installs the APK that's already built (build/app/outputs/flutter-apk/
#  app-release.apk) without rebuilding -- for when a build already happened
#  (e.g. Claude ran the build itself while making a change, or you ran
#  build_and_install.sh a moment ago and just want to reinstall the same
#  APK on another device) and a full rebuild would just be wasted time.
#
#  If nothing's been built yet, or the source has changed since the last
#  build, use build_and_install.sh instead -- this script never compiles
#  anything, it only re-installs whatever .apk is already sitting on disk.
# =============================================================================
#  HOW TO RUN:
#    ./install_only.sh                    # auto-picks the device (see below)
#    ./install_only.sh <device-id>        # target a specific device, e.g.:
#    ./install_only.sh 192.168.1.142:39101
#
#  Device auto-pick logic is identical to build_and_install.sh -- see that
#  script's header comment for the wireless-debugging double-listing case.
# =============================================================================

set -e

cd "$(dirname "$0")"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "No build found at $APK_PATH -- run ./build_and_install.sh first."
    exit 1
fi

# macOS's stat has BSD-style flags (unlike Linux's `stat -c`) -- this prints
# the file's last-modified time so you can sanity-check it's the build you
# expect before installing a possibly-stale APK.
BUILT_AT=$(stat -f "%Sm" "$APK_PATH" 2>/dev/null || echo "unknown time")
echo "Found existing build (built $BUILT_AT): $APK_PATH"

TARGET="$1"

if [ -z "$TARGET" ]; then
    DEVICES=()
    while IFS= read -r line; do
        [ -n "$line" ] && DEVICES+=("$line")
    done < <(adb devices | awk '$2 == "device" {print $1}')

    if [ "${#DEVICES[@]}" -eq 0 ]; then
        echo "No adb device connected. Reconnect wireless debugging (or plug in via USB) and try again."
        exit 1
    elif [ "${#DEVICES[@]}" -eq 1 ]; then
        TARGET="${DEVICES[0]}"
    else
        IP_PORT_MATCHES=()
        for d in "${DEVICES[@]}"; do
            if [[ "$d" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
                IP_PORT_MATCHES+=("$d")
            fi
        done
        if [ "${#IP_PORT_MATCHES[@]}" -eq 1 ] && [ "${#DEVICES[@]}" -eq 2 ]; then
            TARGET="${IP_PORT_MATCHES[0]}"
            echo "Multiple adb entries found (likely the same phone via wireless debugging) -- using $TARGET."
        else
            echo "Multiple distinct adb devices connected -- pass one explicitly:"
            printf '  %s\n' "${DEVICES[@]}"
            echo "Example: ./install_only.sh ${DEVICES[0]}"
            exit 1
        fi
    fi
fi

echo "Installing $APK_PATH to $TARGET..."
adb -s "$TARGET" install -r "$APK_PATH"

echo "Done -- Pype Dialer installed on $TARGET."
