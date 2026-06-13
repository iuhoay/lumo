#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Lumo Dev"
BUNDLE_ID="com.iuhoay.lumo.dev"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/mac-app"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
DERIVED_APP_BUNDLE="$BUILD_DIR/DerivedData/Build/Products/Debug/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

remove_duplicate_dev_app() {
  # Tests build a second "Lumo Dev.app" under build/DerivedData. Keeping two
  # bundles with the same name and bundle id makes macOS Screen Recording
  # permissions easy to grant to the wrong path, so dev runs keep only the
  # stable SYMROOT app bundle.
  if [[ -d "$DERIVED_APP_BUNDLE" ]]; then
    /bin/rm -rf "$DERIVED_APP_BUNDLE"
  fi
}

reset_screen_capture_permission() {
  /usr/bin/tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
}

remove_duplicate_dev_app

xcodebuild \
  -project "$PROJECT_DIR/Lumo.xcodeproj" \
  -scheme Lumo \
  -configuration Debug \
  SYMROOT="$BUILD_DIR" \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --reset-screen-capture|reset-screen-capture)
    reset_screen_capture_permission
    open_app
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--reset-screen-capture]" >&2
    exit 2
    ;;
esac
