#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/02-source/flutter-app"
flutter pub get
DEFINES=()
if [[ -n "${MOCHI_AI_GATEWAY:-}" ]]; then
  DEFINES+=("--dart-define=MOCHI_AI_GATEWAY=$MOCHI_AI_GATEWAY")
fi
flutter build web --release --base-href /mochi/ --no-pub "${DEFINES[@]}"
flutter build apk --release --no-pub "${DEFINES[@]}"
# Prevent stale files from older web builds while touching only the release/web directory.
python3 - "$ROOT" <<'PYTHON'
from pathlib import Path
import shutil,sys
root=Path(sys.argv[1])
web=root/'01-release/web'
if web.exists(): shutil.rmtree(web)
shutil.copytree(root/'02-source/flutter-app/build/web',web)
shutil.copy2(root/'02-source/flutter-app/build/app/outputs/flutter-apk/app-release.apk',root/'01-release/android/Mochii-1.4.10-2047.apk')
PYTHON
printf 'Built release files. Refresh manifest, presentation metadata and SHA256SUMS before distribution.\n'
