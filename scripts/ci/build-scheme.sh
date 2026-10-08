#!/usr/bin/env bash
# 指定スキームをシミュレータ向けにビルドする（.claude/verify.conf / CI から呼ぶ）。
# -sdk iphonesimulator だと Anosa に埋め込まれた Watch ターゲットまで iOS SDK でビルドされるため、
# generic destination を使う。デバイス名に依存しないので Xcode のバージョンや worktree 間で衝突しない。
set -euo pipefail

usage() {
  echo "usage: $0 <scheme> <ios|watchos>" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
scheme="$1"
platform="$2"
[ -n "$scheme" ] || usage

case "$platform" in
  ios) destination="generic/platform=iOS Simulator" ;;
  watchos) destination="generic/platform=watchOS Simulator" ;;
  *) usage ;;
esac

cd "$(git rev-parse --show-toplevel)"

exec xcodebuild \
  -project Anosa.xcodeproj \
  -scheme "$scheme" \
  -destination "$destination" \
  -derivedDataPath ./.derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
