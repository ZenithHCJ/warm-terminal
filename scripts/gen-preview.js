#!/usr/bin/env node
/**
 * 为每个主题生成一张 SVG 预览图（不依赖截图，README 里直接显示）。
 *
 * 用法： node scripts/gen-preview.js
 * 输出： screenshots/<theme>.svg
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const themesDir = path.join(root, 'themes');
const outDir = path.join(root, 'screenshots');
fs.mkdirSync(outDir, { recursive: true });

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function preview(theme) {
  const s = theme.terminal.scheme;
  const tabBg = theme.terminal.appTheme.tab.background;
  const rowBg = theme.terminal.appTheme.tabRow.background;
  const mono = 'ui-monospace, &quot;LXGWWenKaiMono NF&quot;, Consolas, monospace';
  const lineH = 22;
  const x = 16;

  // 模拟一段终端内容：提示符 + eza 列表 + git 输出
  const lines = [
    { t: 1, parts: [[`~/projects/warm-terminal`, s.green], [` (main)`, s.cyan]] },
    { t: 1, parts: [[`$ `, s.foreground], [`lt`, s.foreground]] },
    { t: 0, parts: [[` 󰉋 bash`, s.blue], [`   󰉋 scripts`, s.blue], [`   󰉋 themes`, s.blue]] },
    { t: 0, parts: [[` 󰈔 README.md`, s.foreground], [`   󰈔 LICENSE`, s.yellow]] },
    { t: 0, parts: [[`  settings.json`, s.purple]] },
    { t: 1, parts: [[`$ `, s.foreground], [`gs`, s.foreground]] },
    { t: 0, parts: [[`On branch `, s.foreground], [`main`, s.green], [`  working tree clean`, s.brightBlack]] },
  ];

  const body = lines
    .map((l, i) => {
      const y = 86 + i * lineH;
      const spans = l.parts
        .map(([txt, color]) => `<tspan fill="${color}">${esc(txt)}</tspan>`)
        .join('');
      return `<text x="${x}" y="${y}" font-family="${mono}" font-size="13">${spans}</text>`;
    })
    .join('\n  ');

  return `<svg xmlns="http://www.w3.org/2000/svg" width="480" height="260" viewBox="0 0 480 260" role="img" aria-label="${esc(theme.label)} 预览">
  <rect width="480" height="260" rx="10" fill="${s.background}"/>
  <!-- 标签栏 -->
  <rect x="8" y="8" width="120" height="26" rx="6" fill="${tabBg}"/>
  <circle cx="22" cy="21" r="4" fill="${s.red}"/>
  <text x="34" y="26" font-family="${mono}" font-size="11" fill="${s.foreground}">Git Bash</text>
  <rect x="0" y="40" width="480" height="4" fill="${rowBg}"/>
  <!-- 终端内容 -->
  <rect x="8" y="50" width="464" height="200" rx="6" fill="${s.background}" stroke="${tabBg}"/>
  ${body}
  <!-- 主题名 -->
  <text x="${x}" y="242" font-family="${mono}" font-size="10" fill="${s.brightBlack}">${esc(theme.label)} · 光标</text>
  <rect x="96" y="232" width="7" height="13" fill="${s.cursorColor}"/>
</svg>
`;
}

const files = fs.readdirSync(themesDir).filter((f) => f.endsWith('.json'));
for (const f of files) {
  const theme = JSON.parse(fs.readFileSync(path.join(themesDir, f), 'utf8'));
  const out = path.join(outDir, `${theme.name}.svg`);
  fs.writeFileSync(out, preview(theme));
  console.log(`已生成 screenshots/${theme.name}.svg`);
}
