#!/bin/bash
# =============================================================================
#  BUILD & INSTALL - Pype Dialer
#  Builds the release APK (prod flavor, points at https://pypecrm.com) and
#  installs it straight to a connected Android device via adb (wired or
#  wireless debugging) -- self-serve version of the build+install cycle so
#  a rebuild after a code change doesn't need a separate request.
# =============================================================================
#  HOW TO RUN:
#    ./build_and_install.sh                    # auto-picks the device (see below)
#    ./build_and_install.sh <device-id>         # target a specific device, e.g.:
#    ./build_and_install.sh 192.168.1.142:39101
#
#  Get <device-id> from `adb devices`. Wireless debugging commonly lists the
#  SAME phone twice -- once as its IP:port, once as an
#  "adb-<serial>._adb-tls-connect._tcp" mDNS alias -- that's not two
#  devices, just two names for one. With no argument, this script picks the
#  IP:port entry automatically when that's the only ambiguity; anything
#  messier (an emulator also running, a second real device, etc.) it'll ask
#  you to pass the id explicitly instead of guessing.
#
#  If wireless debugging has dropped, reconnect it (phone -> Developer
#  options -> Wireless debugging) before running this -- adb fails with
#  "no devices/emulators found" otherwise.
# =============================================================================

set -e

cd "$(dirname "$0")"

TARGET="$1"

if [ -z "$TARGET" ]; then
    # Only lines whose 2nd column is literally "device" (skips the header
    # line and anything "offline"/"unauthorized"). Built with a while-read
    # loop, not `mapfile`/`readarray` -- macOS ships bash 3.2 (Apple hasn't
    # updated it past that since bash 4 went GPLv3), and mapfile doesn't
    # exist there; this form works on 3.2 as well as any newer bash.
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
        # Common wireless-debugging case: the same phone listed twice (an
        # IP:port entry and an mDNS alias). Prefer the IP:port one.
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
            echo "Example: ./build_and_install.sh ${DEVICES[0]}"
            exit 1
        fi
    fi
fi

echo "Building release APK (prod flavor)..."
flutter build apk --release -t lib/main_prod.dart

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
echo "Installing $APK_PATH to $TARGET..."
adb -s "$TARGET" install -r "$APK_PATH"

echo "Done -- Pype Dialer installed on $TARGET."
