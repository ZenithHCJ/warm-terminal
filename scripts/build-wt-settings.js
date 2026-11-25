#!/usr/bin/env node
/**
 * 把 settings.base.json + 主题 JSON 合并成一份完整的 Windows Terminal 配置。
 *
 * 用法：
 *   node scripts/build-wt-settings.js <theme.json> <out.json>
 *   node scripts/build-wt-settings.js themes/latte-warm.json windows-terminal/settings.json
 */
const fs = require('fs');
const path = require('path');

const [, , themePath, outPath] = process.argv;
if (!themePath || !outPath) {
  console.error('用法: node build-wt-settings.js <theme.json> <out.json>');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
const base = JSON.parse(fs.readFileSync(path.join(root, 'windows-terminal', 'settings.base.json'), 'utf8'));
const theme = JSON.parse(fs.readFileSync(themePath, 'utf8'));

const { scheme, appTheme } = theme.terminal;

base.profiles.defaults.colorScheme = scheme.name;
base.schemes = [scheme];
base.theme = appTheme.name;
base.themes = [appTheme];

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(base, null, 4) + '\n');
console.log(`已生成 ${path.relative(root, outPath)}  ← 主题 ${theme.label}`);
