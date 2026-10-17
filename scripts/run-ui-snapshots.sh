#!/usr/bin/env bash
#
# Body of the "Run the app on an emulator and take screenshots" step.
#
# It is a file, not an inline `script: |` block, because reactivecircus/android-emulator-runner
# splits that input on newlines and runs every line as a separate `sh -c` command. A multi-line
# `if`, a variable set on one line and read on the next, or a line continuation therefore cannot
# work there: the first incomplete fragment exits with code 2. The workflow passes the single line
# `bash scripts/run-ui-snapshots.sh` instead.
#
# Exit status: the adb install status when the APK could not be installed, otherwise Maestro's.
set -uo pipefail

cd "${GITHUB_WORKSPACE:?}" || exit 1

APK="${APK_PATH:-}"
if [ -z "$APK" ] && [ -f apk-path.txt ]; then
  APK=$(cat apk-path.txt)
fi
if [ -z "$APK" ]; then
  APK=$(ls sublearn/app/build/outputs/apk/debug/app-x86_64-debug.apk 2>/dev/null || true)
fi
if [ -z "$APK" ]; then
  APK=$(ls sublearn/app/build/outputs/apk/debug/*.apk 2>/dev/null | head -1 || true)
fi

echo "== APK: [$APK] =="
echo "== adb devices =="
adb devices || true

echo "== install =="
INSTALL=1
if adb install -r -t "$APK" > install.log 2>&1; then
  INSTALL=0
fi
cat install.log
echo "adb install exit code: $INSTALL"

echo "== reset logcat and app state =="
adb logcat -c || true
adb shell am force-stop "$APP_ID" || true

echo "== install the Maestro CLI =="
# shellcheck disable=SC2312
curl -Ls "https://get.maestro.mobile.dev" | bash > maestro-install.log 2>&1 || true
cat maestro-install.log
export PATH="$PATH:$HOME/.maestro/bin"
maestro --version > maestro.log 2>&1 || true
cat maestro.log || true

echo "== run the Maestro flows =="
mkdir -p maestro-output
MAESTRO_EXIT=1
maestro test \
  --test-output-dir="$GITHUB_WORKSPACE/maestro-output" \
  --format junit \
  --output="$GITHUB_WORKSPACE/maestro-report.xml" \
  "$GITHUB_WORKSPACE/.maestro" > maestro-run.log 2>&1
MAESTRO_EXIT=$?
cat maestro-run.log
cat maestro-run.log >> maestro.log

echo "== collect the device logs =="
adb logcat -d -v threadtime > logcat.txt || true
adb logcat -d '*:E' > logcat-errors.txt || true
adb logcat -d -v time '*:E' > logcat-errors-time.txt || true
adb shell dumpsys package "$APP_ID" > package-dump.txt 2>&1 || true
adb exec-out screencap -p > final-screen.png || true

echo "== screenshots Maestro produced =="
find maestro-output -type f -name '*.png' >> maestro.log 2>&1 || true
cat maestro.log || true

if [ "$INSTALL" -ne 0 ]; then
  exit "$INSTALL"
fi
exit "$MAESTRO_EXIT"
