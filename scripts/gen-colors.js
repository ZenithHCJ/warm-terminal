#!/usr/bin/env node
/**
 * 由主题 JSON 生成 shell 配色文件 ~/.warm-terminal/colors.sh
 *
 * 用法： node scripts/gen-colors.js themes/nord.json ~/.warm-terminal/colors.sh
 */
const fs = require('fs');
const path = require('path');

const [, , themePath, outPath] = process.argv;
if (!themePath || !outPath) {
  console.error('用法: node gen-colors.js <theme.json> <colors.sh>');
  process.exit(1);
}

const theme = JSON.parse(fs.readFileSync(themePath, 'utf8'));
const s = theme.shell;
const q = (v) => `'${String(v ?? '').replace(/'/g, `'\\''`)}'`;

const content = `# ============================================================
#  Warm Terminal — 主题色（自动生成，勿手改）
#  主题: ${theme.label}  (${theme.name})
#  重新生成: bash scripts/apply-theme.sh <主题名>
# ============================================================

WT_THEME_NAME=${q(theme.name)}
WT_DIR_COLOR=${q(s.promptDir)}
WT_GIT_COLOR=${q(s.promptGit)}
WT_BAT_THEME=${q(s.batTheme)}
WT_FZF_OPTS=${q(s.fzf)}
`;

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, content);
console.log(`已生成 ${outPath} ← ${theme.label}`);
