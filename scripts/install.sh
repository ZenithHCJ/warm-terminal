#!/usr/bin/env bash
# ============================================================
#  Warm Terminal 安装脚本（Git Bash / MSYS2）
#
#  用法：
#    bash scripts/install.sh                    # 安装 + 应用默认主题
#    bash scripts/install.sh tokyo-night        # 安装并指定主题
#    bash scripts/install.sh --no-wt            # 只装 bash 配置，不动 Windows Terminal
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
WITH_WT=1
THEME="latte-warm"

for arg in "$@"; do
    case "$arg" in
        --no-wt) WITH_WT=0 ;;
        -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "未知参数: $arg" >&2; exit 1 ;;
        *) THEME="$arg" ;;
    esac
done

echo "==> Warm Terminal 安装开始"
echo "    仓库位置: $REPO_DIR"
echo "    主题    : $THEME"

# ---------- 1. .bashrc ----------
TARGET_BASHRC="$HOME/.bashrc"
if [ -f "$TARGET_BASHRC" ] && ! grep -q "Warm Terminal" "$TARGET_BASHRC" 2>/dev/null; then
    cp "$TARGET_BASHRC" "$TARGET_BASHRC.bak-$STAMP"
    echo "==> 已备份旧配置: ~/.bashrc.bak-$STAMP"
fi
cp "$REPO_DIR/bash/bashrc" "$TARGET_BASHRC"
echo "==> 已写入 ~/.bashrc"

# .bash_profile 里确保 source 了 .bashrc（登录 shell 才会读到）
PROFILE="$HOME/.bash_profile"
if ! grep -q 'bashrc' "$PROFILE" 2>/dev/null; then
    printf '\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> "$PROFILE"
    echo "==> 已在 ~/.bash_profile 中加入 source ~/.bashrc"
fi

# ---------- 2. 主题 ----------
if command -v node >/dev/null 2>&1; then
    ARGS=("$THEME")
    [ "$WITH_WT" = "1" ] || ARGS=("--no-wt" "$THEME")
    bash "$REPO_DIR/scripts/apply-theme.sh" "${ARGS[@]}"
else
    echo "!!  未检测到 Node.js，跳过主题生成（提示符将使用内置默认配色）"
    echo "    安装后运行: bash scripts/apply-theme.sh $THEME"
fi

echo
echo "==> 完成。重开终端或执行： source ~/.bashrc"
echo "    换主题： theme            # 列出"
echo "            theme nord       # 切换"
