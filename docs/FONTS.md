# 字体：从哪来、怎么装、怎么换

> 这套终端的「好看」有一半来自字体：**等宽 + 中文 + Nerd Font 图标**三合一。
> 字体没装对，`eza` 的图标会变成 `□`，中文可能变成方块或被 fallback 成别的字体。

---

## 1. 为什么需要「Nerd Font」

`eza` / `bat` / `lazygit` 用的图标（󰉋 󰈔 󰊢 之类）不是普通 Unicode 字符，而是
**Nerd Fonts** 在 Unicode 私有使用区（PUA）里补充的字形。普通字体里没有这些码位，
就会渲染成方块。

因此需要一款 **带 NF 补丁的等宽字体**。本项目默认：

| 用途 | 字体名（Windows 里显示的名字） | 来源 |
|---|---|---|
| 默认 | `LXGWWenKaiMono NF` | [LXGW WenKai](https://github.com/lxgw/LxgwWenKai)（霞鹜文楷等宽，中文友好） |
| 备选 | `JetBrainsMono NF` | [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) |
| 备选 | `CaskaydiaCove NF` | Nerd Fonts（Cascadia Code 的 NF 版，Win 自带字体打补丁） |

> ⚠️ **名字必须精确匹配**。Windows 里叫 `CaskaydiaCove NF`，不是 `Cascadia Code`；
> 叫 `LXGWWenKaiMono NF`，不是 `LXGW WenKai Mono`。写错就静默 fallback —— 不报错，只是图标没了。

---

## 2. 三种安装方式

### 方式 A：scoop（最省事，推荐）

```powershell
scoop bucket add nerd-fonts
scoop install LXGWWenKaiMono-NF        # 或 JetBrainsMono-NF / CascadiaCode-NF
```

scoop 会同时处理字体文件和系统注册，装完即可用。

### 方式 B：winget

```powershell
winget search Nerd
winget install --id DEVCOM.JetBrainsMonoNerdFont
```

### 方式 C：手动（没有任何包管理器时）

1. 下载 `.ttf`：
   - 霞鹜文楷：https://github.com/lxgw/LxgwWenKai/releases （找 `LXGWWenKaiMonoNF.ttf`）
   - Nerd Fonts 全家桶：https://www.nerdfonts.com/font-downloads
2. **选中 ttf → 右键 → 安装**（当前用户）或「为所有用户安装」
3. 或命令行注册（per-user，不需要管理员）：

```powershell
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
New-Item -ItemType Directory $fontDir -Force | Out-Null
Copy-Item .\LXGWWenKaiMonoNF.ttf $fontDir

# 注册表登记（名字随意，但建议用家族名 + (TrueType)）
$key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-ItemProperty $key -Name 'LXGWWenKaiMono NF (TrueType)' `
  -Value "$fontDir\LXGWWenKaiMonoNF.ttf" -PropertyType String -Force
```

4. **注销/重开终端**（字体缓存在进程里，重启 Terminal 就够）

### 方式 D：一键部署脚本（推荐给 AI / 新机器）

```powershell
# 自动检查；能从 Downloads 找到 ttf 就顺手装好并登记注册表
pwsh -File deploy\deploy.ps1 -Font "LXGWWenKaiMono NF"

# 已经装好了别的 NF 字体，直接指定
pwsh -File deploy\deploy.ps1 -Font "CaskaydiaCove NF"
```

---

## 3. 怎么确认装好了

**A. 看注册表（最可靠）**

```powershell
@('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
  'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') |
  ForEach-Object { if (Test-Path $_) { (Get-ItemProperty $_).PSObject.Properties.Name } } |
  Where-Object { $_ -match ' NF |Nerd Font' }
```

**B. 看 Terminal 里实际生效的字体**：`Ctrl+,` → 配置文件 → 外观 → 字体，下拉框里能不能选中。

**C. 终极验证**：在 Git Bash 里跑

```bash
printf '\ue0b0 \uf07b \uf121 \uf1d3\n'    # 应该看到箭头 / 文件夹 / git 之类图标，而不是方块
eza --icons -l                            # 图标正常显示
```

> 本项目在用户机器上实测发现过：WT 里写了 `LXGWWenKaiMono NF`，但系统里 441 个字体
> 没有一个匹配 → 一直是系统 fallback 在撑。所以**别信配置文件，去注册表查**。

---

## 4. 怎么换字体

改一个地方即可（`windows-terminal/settings.base.json` 是骨架，`settings.json` 是生成物）：

```powershell
pwsh -File deploy\deploy.ps1 -Font "JetBrainsMono NF"     # 自动改 base 并重新生成
```

或者手动：

```jsonc
// windows-terminal/settings.base.json
"profiles": { "defaults": { "font": { "face": "CaskaydiaCove NF", "size": 14 } } }
```

```bash
node scripts/build-wt-settings.js themes/latte-warm.json windows-terminal/settings.json
bash scripts/apply-theme.sh latte-warm    # 或直接重跑主题，会重新生成
```

**预览图字体**（只影响 README 里那几张 SVG，不影响终端）：

```bash
npm run preview        # 固定用 JetBrainsMono NF，与 CI 一致
npm run preview:local  # 用本机字体（霞鹜文楷）
```

---

## 5. 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 图标是 `□` 方块 | 字体不带 NF，或名字写错 | 换 NF 字体 / 校正 `font.face` |
| 中文变方块 | 字体没有中文字形（如纯 JetBrainsMono） | 用 `LXGWWenKaiMono NF`，或 WT 里配 `"font": {"face": "...", "cellWidth": ...}` 之外改用中文等宽 NF |
| 改了 `font.face` 没变化 | 只改了 `settings.json`（生成物），下次生成被覆盖 | 改 `settings.base.json` |
| 下拉框里找不到字体 | 字体只装给了另一个用户 / 未登记注册表 | 按上面方式 C 重新登记，重启 Terminal |
| 字体装了但很矮很宽 | 该字体不是等宽 | 换 Mono 版本（名字里带 `Mono`） |
| `fc-list` 里看不到 | Git Bash 用的是 Windows 字体系统，不是 fontconfig | 用注册表检查，别看 `fc-list` |

---

## 6. 加一套自己的字体到项目里（可选）

字体文件**不要提交到 git**（动辄 5–20 MB，且各有许可证）。推荐：

```
docs/FONTS.md          ← 说明用哪个字体、去哪下（现在这个文件）
scripts/gen-preview.js ← 只引用字体名
```

要带动画的安装，就在 `deploy/deploy.ps1` 的 `-Font` 参数里传，或在
`.github/` 里加一个 release 附件链接。**只登记名字，不登记二进制**。
