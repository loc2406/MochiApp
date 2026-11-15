#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter build apk --release --target-platform "${TARGET_PLATFORM:-android-arm,android-arm64,android-x64}" --no-pub
