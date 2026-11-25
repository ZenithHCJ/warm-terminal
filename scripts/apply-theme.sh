#!/usr/bin/env bash
# ============================================================
#  Warm Terminal — 切换主题
#
#  用法：
#    bash scripts/apply-theme.sh                 # 列出所有主题
#    bash scripts/apply-theme.sh tokyo-night     # 应用主题
#    bash scripts/apply-theme.sh --no-wt nord    # 只改 shell 配色，不动 Windows Terminal
#
#  做了三件事：
#    1. ~/.warm-terminal/colors.sh        → 提示符 / fzf / bat 配色
#    2. windows-terminal/settings.json    → base + 主题合并结果
#    3. 备份并写入 Windows Terminal 实际配置
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$REPO_DIR/themes"
STATE_DIR="$HOME/.warm-terminal"
STAMP="$(date +%Y%m%d-%H%M%S)"

# node 是 Windows 程序，MSYS 路径（/c/...）要转成 C:\...
towin() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

list_themes() {
    echo "可用主题："
    for f in "$THEMES_DIR"/*.json; do
        node -e '
            const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
            const cur = process.env.CUR === t.name ? " ← 当前" : "";
            console.log(`  ${t.name.padEnd(16)} ${t.label.padEnd(16)} ${t.description}${cur}`);
        ' "$(towin "$f")"
    done
    echo
    echo "用法: bash scripts/apply-theme.sh <主题名>"
}

WITH_WT=1
THEME=""
for arg in "$@"; do
    case "$arg" in
        --no-wt)   WITH_WT=0 ;;
        -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)        echo "未知参数: $arg" >&2; exit 1 ;;
        *)         THEME="$arg" ;;
    esac
done

command -v node >/dev/null 2>&1 || {
    echo "需要 Node.js 来解析主题 JSON（winget install OpenJS.NodeJS.LTS）" >&2
    exit 1
}

if [ -z "$THEME" ]; then
    CUR="$(cat "$STATE_DIR/current" 2>/dev/null || echo '')" list_themes
    exit 0
fi

THEME_FILE="$THEMES_DIR/${THEME%.json}.json"
if [ ! -f "$THEME_FILE" ]; then
    echo "找不到主题: $THEME" >&2
    echo "可选：$(ls "$THEMES_DIR" | sed 's/\.json$//' | tr '\n' ' ')" >&2
    exit 1
fi
THEME_NAME="$(node -p "JSON.parse(require('fs').readFileSync('$(towin "$THEME_FILE")','utf8')).name")"

# ---------- 1. shell 配色 ----------
node "$(towin "$REPO_DIR/scripts/gen-colors.js")" "$(towin "$THEME_FILE")" "$(towin "$STATE_DIR/colors.sh")"
echo "$THEME_NAME" > "$STATE_DIR/current"

# ---------- 2. 生成项目内 settings.json ----------
node "$(towin "$REPO_DIR/scripts/build-wt-settings.js")"      "$(towin "$THEME_FILE")" "$(towin "$REPO_DIR/windows-terminal/settings.json")"

# ---------- 3. 写入 Windows Terminal ----------
if [ "$WITH_WT" = "1" ]; then
    LOCAL="${LOCALAPPDATA:-$HOME/AppData/Local}"
    WT_SETTINGS=""
    for p in \
        "$LOCAL/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" \
        "$LOCAL/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json" \
        "$LOCAL/Microsoft/Windows Terminal/settings.json"; do
        [ -f "$p" ] && WT_SETTINGS="$p" && break
    done

    if [ -n "$WT_SETTINGS" ]; then
        cp "$WT_SETTINGS" "$WT_SETTINGS.bak-$STAMP"
        cp "$REPO_DIR/windows-terminal/settings.json" "$WT_SETTINGS"
        echo "==> 已写入 Windows Terminal（备份: settings.json.bak-$STAMP）"
    else
        echo "!!  未找到 Windows Terminal 配置，跳过第 3 步，可手动复制 windows-terminal/settings.json"
    fi
fi

echo "生效： source ~/.bashrc  |  Windows Terminal 需新开窗口"
