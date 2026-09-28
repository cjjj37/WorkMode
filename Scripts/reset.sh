#!/bin/bash
# 把机器恢复到「刚拿到安装包」的干净状态，方便反复做全新体验测试。
# 会自动备份现有配置到 .backup/ 目录，不会真的丢数据。
#
# 用法：
#   ./Scripts/reset.sh                  恢复干净状态
#   ./Scripts/reset.sh --simulate-download   额外给应用打上隔离标记，
#                                            完整复现「首次启动被系统拦截」
set -uo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CONFIG_DIR="$HOME/Library/Application Support/WorkMode"
CONFIG="$CONFIG_DIR/modes.json"
BACKUP_DIR="$ROOT/.backup"

echo "==> 退出正在运行的应用"
pkill -f "WorkMode.app/Contents/MacOS/WorkMode" 2>/dev/null || true
sleep 1

echo "==> 备份现有配置"
mkdir -p "$BACKUP_DIR"
if [ -f "$CONFIG" ]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG" "$BACKUP_DIR/modes-$STAMP.json"
  echo "    已备份: $BACKUP_DIR/modes-$STAMP.json"
  rm -f "$CONFIG"
else
  echo "    （当前没有配置文件，跳过备份）"
fi

echo "==> 清除首次启动标记"
defaults delete com.local.workmode WorkMode.didLaunchBefore 2>/dev/null || true
# 这个标记不清，开机自启的「默认开启」逻辑就不会再触发，测不出首次体验
defaults delete com.local.workmode WorkMode.didInitAutostart 2>/dev/null || true

echo "==> 关闭开机自启"
BIN="$ROOT/dist/WorkMode.app/Contents/MacOS/WorkMode"
if [ -x "$BIN" ]; then
  "$BIN" --autostart-off 2>/dev/null || true
else
  echo "    （还没编译，跳过）"
fi

echo "==> 移除已安装的副本"
rm -rf "/Applications/WorkMode.app" 2>/dev/null || true

if [ "${1:-}" = "--simulate-download" ]; then
  echo "==> 给安装包打上隔离标记（模拟从网上下载）"
  xattr -w com.apple.quarantine "0081;00000000;WorkMode;" "$ROOT/dist/WorkMode-1.0.0.dmg" 2>/dev/null || true
  echo "    双击 dmg 后拖到 Applications，首次启动就会被系统拦截"
fi

echo
echo "干净了。现在的状态等同于一个从没装过 WorkMode 的新用户。"
echo "    配置目录: $CONFIG_DIR （已清空）"
echo "    配置备份: $BACKUP_DIR/"
echo
