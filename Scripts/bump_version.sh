#!/bin/bash
# 升级版本号：同时更新 CFBundleShortVersionString 和递增 CFBundleVersion
#
# 用法：./Scripts/bump_version.sh 1.1.0
set -euo pipefail

cd "$(dirname "$0")/.."

NEW="${1:-}"
if [ -z "$NEW" ]; then
  echo "用法: ./Scripts/bump_version.sh <版本号>"
  echo "示例: ./Scripts/bump_version.sh 1.1.0"
  exit 1
fi

if ! echo "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "版本号格式应为 主版本.次版本.修订号，例如 1.1.0"
  exit 1
fi

PLIST="Resources/Info.plist"

CURRENT="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")"
NEXT_BUILD=$((BUILD + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$PLIST"

echo "版本: $CURRENT -> $NEW  (build $BUILD -> $NEXT_BUILD)"
echo
echo "记得同步更新 CHANGELOG.md，然后："
echo "  git add -A && git commit -m \"chore: bump version to $NEW\""
echo "  git tag v$NEW"
echo "  git push && git push --tags"
