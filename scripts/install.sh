#!/usr/bin/env bash
# ============================================================
#  Warm Terminal 安装脚本（Git Bash / MSYS2）
#  用法： bash scripts/install.sh
#  可选： bash scripts/install.sh --no-wt   只装 bash 配置
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
WITH_WT=1
[ "${1:-}" = "--no-wt" ] && WITH_WT=0

echo "==> Warm Terminal 安装开始"
echo "    仓库位置: $REPO_DIR"

# ---------- 1. .bashrc ----------
TARGET_BASHRC="$HOME/.bashrc"
if [ -f "$TARGET_BASHRC" ] && ! grep -q "Warm Terminal" "$TARGET_BASHRC" 2>/dev/null; then
    cp "$TARGET_BASHRC" "$TARGET_BASHRC.bak-$STAMP"
    echo "==> 已备份旧配置: $TARGET_BASHRC.bak-$STAMP"
fi
cp "$REPO_DIR/bash/bashrc" "$TARGET_BASHRC"
echo "==> 已写入 $TARGET_BASHRC"

# .bash_profile 里确保 source 了 .bashrc（Git Bash 登录 shell 才会读到）
PROFILE="$HOME/.bash_profile"
if ! grep -q 'bashrc' "$PROFILE" 2>/dev/null; then
    printf '\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> "$PROFILE"
    echo "==> 已在 $PROFILE 中加入 source ~/.bashrc"
fi

# ---------- 2. Windows Terminal ----------
if [ "$WITH_WT" = "1" ]; then
    WT_SETTINGS=""
    for p in \
        "$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" \
        "$LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json" \
        "$LOCALAPPDATA/Microsoft/Windows Terminal/settings.json"; do
        [ -f "$p" ] && WT_SETTINGS="$p" && break
    done

    if [ -n "$WT_SETTINGS" ]; then
        cp "$WT_SETTINGS" "$WT_SETTINGS.bak-$STAMP"
        cp "$REPO_DIR/windows-terminal/settings.json" "$WT_SETTINGS"
        echo "==> 已备份并写入 Windows Terminal 配置"
        echo "    $WT_SETTINGS"
    else
        echo "!!  没找到 Windows Terminal 配置，跳过（可手动复制 windows-terminal/settings.json）"
    fi
fi

echo
echo "==> 完成。请重开一个终端，或执行： source ~/.bashrc"
echo "    提示：先把 window 文件夹里的字体装好（见 README），图标才正常显示。"
