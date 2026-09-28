#!/bin/bash
# 编译打包 WorkMode.app（模式启动器）
# 产物输出在 ./dist 下，不会往系统目录里塞东西
#
# 用法：
#   ./build.sh               只编译 .app（universal：arm64 + x86_64）
#   ./build.sh --package     编译 + 产出可分发的 dmg（含安装说明）
#   ./build.sh --arch=arm64  只编译指定架构
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="WorkMode"
ROOT="$(pwd)"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
SDK="$(xcrun --show-sdk-path)"
MIN_MACOS="12.0"

TARGET_ARM="arm64-apple-macosx${MIN_MACOS}"
TARGET_X86="x86_64-apple-macosx${MIN_MACOS}"

DO_PACKAGE=0
ARCHES="arm64 x86_64"

for arg in "$@"; do
  case "$arg" in
    --package|-p) DO_PACKAGE=1 ;;
    --arch=arm64) ARCHES="arm64" ;;
    --arch=x86_64) ARCHES="x86_64" ;;
  esac
done

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)"

echo "==> 清理旧产物"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

echo "==> 生成应用图标"
if swiftc -O -target "$TARGET_ARM" Scripts/make_icon.swift -o /tmp/wm_make_icon 2>/dev/null; then
  if /tmp/wm_make_icon "$RES/AppIcon.icns" 2>/dev/null; then
    echo "    图标 OK"
  else
    echo "    （图标生成失败，使用系统默认图标）"
  fi
else
  echo "    （图标工具编译失败，使用系统默认图标）"
fi

# 为每个架构各编译一份，最后 lipo 合并成 universal
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

BUILT=""
for arch in $ARCHES; do
  case "$arch" in
    arm64) target="$TARGET_ARM" ;;
    x86_64) target="$TARGET_X86" ;;
    *) continue ;;
  esac
  echo "==> 编译 Swift 源码（$arch）"
  if swiftc -O \
    -target "$target" \
    -sdk "$SDK" \
    -o "$BUILD_DIR/${APP_NAME}_${arch}" \
    Sources/*.swift; then
    BUILT="$BUILT $BUILD_DIR/${APP_NAME}_${arch}"
  else
    echo "    （$arch 编译失败，跳过该架构）"
  fi
done

if [ -z "$BUILT" ]; then
  echo "错误：没有任何架构编译成功" >&2
  exit 1
fi

# shellcheck disable=SC2086
set -- $BUILT
if [ "$#" -eq 1 ]; then
  echo "==> 复制可执行文件（单架构 $ARCHES）"
  cp "$1" "$MACOS/$APP_NAME"
else
  echo "==> 合并为 universal 二进制"
  lipo -create -output "$MACOS/$APP_NAME" "$@"
  lipo -info "$MACOS/$APP_NAME"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"

# 图标 key 要在 Info.plist 存在之后才能写入
if [ -f "$RES/AppIcon.icns" ]; then
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
fi

echo "==> 签名（ad-hoc）"
codesign --force --deep --sign - "$APP"

echo "==> 完成"
echo "应用位置: $APP"
echo "运行方式: open \"$APP\""

if [ "$DO_PACKAGE" -eq 1 ]; then
  echo
  echo "==> 打包 dmg（零成本分发方案：对方需右键/隐私与安全性放行）"

  STAGE="$DIST/staging"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"

  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  cp Resources/安装说明.md "$STAGE/安装说明.md"

  DMG="$DIST/${APP_NAME}-${VERSION}.dmg"
  rm -f "$DMG"
  hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null
  rm -rf "$STAGE"

  # 去掉本地隔离属性，方便自己先双击验证
  xattr -dr com.apple.quarantine "$DMG" 2>/dev/null || true

  echo "分发包: $DMG"
  echo "校验值: $(shasum -a 256 "$DMG" | awk '{print $1}')"
  echo
  echo "--------------------------------------------------------------"
  echo "发给朋友时，请附上这段说明："
  echo "--------------------------------------------------------------"
  echo "1. 双击打开 WorkMode-${VERSION}.dmg"
  echo "2. 把里面的 WorkMode.app 拖到 Applications（窗口里已有快捷入口）"
  echo "3. 首次启动会被系统拦截（因为没有付费开发者签名），三种方式任选："
  echo "   ① 在 Finder 里右键 WorkMode.app → 打开 → 再点「打开」"
  echo "   ② 系统设置 → 隐私与安全性 → 点「仍要打开」"
  echo "   ③ 终端执行：xattr -dr com.apple.quarantine /Applications/WorkMode.app"
  echo "4. 启动后右上角出现 ⚡️，点开选模式即可一键开应用"
  echo "   支持 Apple Silicon 和 Intel Mac，完整说明见 dmg 里的「安装说明.md」"
  echo "--------------------------------------------------------------"
fi
