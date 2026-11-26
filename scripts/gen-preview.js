#!/usr/bin/env node
/**
 * 生成主题预览图
 *   screenshots/<theme>.svg    单主题预览
 *   screenshots/overview.svg   8 套主题总览（README 顶部用）
 *
 * 用法： node scripts/gen-preview.js
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const themesDir = path.join(root, 'themes');
const outDir = path.join(root, 'screenshots');
fs.mkdirSync(outDir, { recursive: true });

// 允许覆盖字体（CI 里用 Nerd Font 渲染图标）
const FONT =
  process.env.PREVIEW_FONT ||
  `ui-monospace, 'LXGWWenKaiMono NF', Consolas, monospace`;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** 一个主题面板的内容（不含外层 <svg>） */
function panel(theme, w, h) {
  const s = theme.terminal.scheme;
  const tabBg = theme.terminal.appTheme.tab.background;
  const rowBg = theme.terminal.appTheme.tabRow.background;
  const pad = 16;
  const lineH = 21;
  const top = 62;

  const lines = [
    [[`~/projects/warm-terminal`, s.green], [` (main)`, s.cyan]],
    [[`$ `, s.foreground], [`lt`, s.foreground]],
    [[` 󰉋 bash`, s.blue], [`    󰉋 scripts`, s.blue], [`    󰉋 themes`, s.blue]],
    [[` 󰈔 README.md`, s.foreground], [`    󰈔 LICENSE`, s.yellow]],
    [[` 󰈞 settings.json`, s.purple]],
    [[`$ `, s.foreground], [`gs`, s.foreground]],
    [[`On branch `, s.foreground], [`main`, s.green], [`  clean`, s.brightBlack]],
  ];

  const body = lines
    .map((parts, i) => {
      const spans = parts
        .map(([txt, color]) => `<tspan fill="${color}">${esc(txt)}</tspan>`)
        .join('');
      return `<text x="${pad + 10}" y="${top + 20 + i * lineH}" font-family="${FONT}" font-size="12.5">${spans}</text>`;
    })
    .join('\n    ');

  return `<rect x="0" y="0" width="${w}" height="${h}" rx="10" fill="${s.background}"/>
    <rect x="0" y="0" width="${w}" height="30" rx="10" fill="${tabBg}"/>
    <rect x="0" y="20" width="${w}" height="10" fill="${tabBg}"/>
    <circle cx="16" cy="15" r="3.5" fill="${s.red}"/>
    <text x="27" y="19" font-family="${FONT}" font-size="10.5" fill="${s.foreground}">Git Bash</text>
    <rect x="0" y="30" width="${w}" height="2" fill="${rowBg}"/>
    ${body}
    <text x="${pad + 10}" y="${h - 14}" font-family="${FONT}" font-size="10" fill="${s.brightBlack}">${esc(theme.label)}</text>
    <rect x="${w - 52}" y="${h - 24}" width="6" height="12" fill="${s.cursorColor}"/>`;
}

const svgWrap = (w, h, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  ${body}
</svg>
`;

// ---------- 单主题 ----------
const files = fs.readdirSync(themesDir).filter((f) => f.endsWith('.json'));
const themes = files.map((f) => JSON.parse(fs.readFileSync(path.join(themesDir, f), 'utf8')));

for (const t of themes) {
  const w = 440, h = 230;
  fs.writeFileSync(
    path.join(outDir, `${t.name}.svg`),
    svgWrap(w, h, `<g>${panel(t, w, h)}</g>`)
  );
  console.log(`已生成 screenshots/${t.name}.svg`);
}

// ---------- 总览 ----------
const cols = 2;
const cellW = 440, cellH = 230, gap = 22, margin = 26, titleH = 52;
const rows = Math.ceil(themes.length / cols);
const W = margin * 2 + cols * cellW + (cols - 1) * gap;
const H = titleH + margin + rows * cellH + (rows - 1) * gap;

const cells = themes
  .map((t, i) => {
    const x = margin + (i % cols) * (cellW + gap);
    const y = titleH + Math.floor(i / cols) * (cellH + gap);
    return `<g transform="translate(${x},${y})">
      <rect x="-1" y="-1" width="${cellW + 2}" height="${cellH + 2}" rx="11" fill="none" stroke="#00000018" stroke-width="2"/>
      ${panel(t, cellW, cellH)}
    </g>`;
  })
  .join('\n  ');

const overview = svgWrap(
  W,
  H,
  `<rect width="${W}" height="${H}" fill="#f6f4ef"/>
  <text x="${margin}" y="34" font-family="${FONT}" font-size="17" fill="#4c4f69" font-weight="600">Warm Terminal</text>
  <text x="${margin + 148}" y="34" font-family="${FONT}" font-size="12" fill="#8c8fa1">8 themes · Windows Terminal + Git Bash</text>
  ${cells}`
);
fs.writeFileSync(path.join(outDir, 'overview.svg'), overview);
console.log(`已生成 screenshots/overview.svg  (${W}×${H})`);
