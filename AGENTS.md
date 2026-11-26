# AGENTS.md — 给 AI 代理的执行手册

> 目标读者：Claude Code / Cursor / Copilot / 任意能跑命令的 agent。
> 目标：把本仓库的终端配置**安全地**装到一台 Windows 机器上，或在其上新增主题。
> 人类用法见 [README](README.md)；设计原理见 [docs/DESIGN.md](docs/DESIGN.md)。

---

## 0. 铁律（先读，违反会毁用户机器）

| # | 规则 |
|---|---|
| 1 | **绝不在 `C:\Users\<user>` 根目录 `git init` / `git add .`** —— 会提交 `.ssh`、`AppData`、`NTUSER.DAT`。仓库必须是独立子目录。 |
| 2 | **所有覆盖前必须备份** `*.bak-<yyyyMMdd-HHmmss>`。没有备份能力就用 `-DryRun`。 |
| 3 | **不要 `sudo` / 不要提权**。字体、profile、`.bashrc` 全部可 per-user 完成。 |
| 4 | 不要修改用户的 `.ssh/`、`~/.gitconfig`（除非任务明确要求设置身份）。 |
| 5 | 不认识的已有配置：**只追加/备份，不删除**。 |
| 6 | 任何"看起来成功"都不算完成 —— 必须跑 §6 的验证断言。 |
| 7 | 用户没要求时不要 `git push`、不要建远程仓库、不要动 Actions secret。 |

---

## 1. 环境探测（先看，不写）

```bash
# 平台
uname -s                                   # MINGW64_NT-* → Git Bash
# 关键组件
command -v git bash node pwsh powershell 2>/dev/null
node -v                                     # 主题系统需要 node（可降级）
# 已有状态（决定是否幂等跳过）
ls ~/.warm-terminal 2>/dev/null
grep -l "Warm Terminal" ~/.bashrc 2>/dev/null
```

**判断分支**

| 观察 | 走哪条路 |
|---|---|
| `node` 存在 | 完整流程（推荐） |
| `node` 缺失，但有 winget/scoop | 先装 Node，再走完整流程 |
| `node` 缺失且无包管理器 | **降级流程**：只装 `bash/bashrc`（内置默认配色），告知用户其余功能不可用 |
| 不是 Windows | **停止**，本项目不支持，直接告知 |

---

## 2. 获取仓库

```bash
git clone https://github.com/ZenithHCJ/warm-terminal.git ~/projects/warm-terminal
cd ~/projects/warm-terminal
```

已存在则 `git -C ~/projects/warm-terminal pull --ff-only`。

**注意**：目标目录不要放在用户家目录根、不要放在 `AppData` 下。

---

## 3. 安装依赖（可跳过）

有 PowerShell 时**优先用一键脚本**（幂等、带备份、支持 `-DryRun`）：

```powershell
pwsh -File deploy\deploy.ps1 -DryRun          # 先看计划
pwsh -File deploy\deploy.ps1                  # 再执行
```

只想装工具、不想碰配置：

```powershell
pwsh -File scripts\install-tools.ps1
```

**手动兜底**（无 winget/scoop，需从 GitHub Release 下载）：

| 工具 | 仓库 | 资产匹配 |
|---|---|---|
| eza | `eza-community/eza` | `x86_64-pc-windows-(gnu|msvc).zip` |
| bat | `sharkdp/bat` | `x86_64-pc-windows-msvc.zip` |
| fzf | `junegunn/fzf` | `windows_amd64.zip` |
| zoxide | `ajeetdsouza/zoxide` | `x86_64-pc-windows-msvc.zip` |
| lazygit | `jesseduffield/lazygit` | `Windows_x86_64.zip` |

解压后把 `.exe` 统一放到一个目录（默认 `D:\Tools\bin`），并让 `TOOLS_BIN` 指向它：

```bash
mkdir -p ~/.warm-terminal
echo "export TOOLS_BIN='/d/Tools/bin'" > ~/.warm-terminal/tools.sh
```

> `~/.bashrc` 会自动 source `~/.warm-terminal/tools.sh`，无需手改 PATH。

---

## 4. 字体（最容易出错的一步）

完整说明见 [docs/FONTS.md](docs/FONTS.md)。AI 必须这样做：

1. **先检测**（不要假设装了）：

```powershell
@('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
  'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') |
  ForEach-Object { if (Test-Path $_) { (Get-ItemProperty $_).PSObject.Properties.Name } } |
  Where-Object { $_ -match ' NF |Nerd Font' }
```

2. **按结果分支**：

| 结果 | 动作 |
|---|---|
| 有 `LXGWWenKaiMono NF` | 什么都不做 |
| 有其它 NF 字体（如 `CaskaydiaCove NF`） | 用 `-Font "CaskaydiaCove NF"` 传给部署脚本，**不要**强装新字体 |
| 一个 NF 都没有 | 尝试 `scoop install LXGWWenKaiMono-NF` / `winget install DEVCOM.JetBrainsMonoNerdFont`；都不行则提示用户手动装，并把 `font.face` 改成系统已有字体 |

3. **不要**把字体文件提交进 git（体积 + 许可证）。

> 真实案例：曾有机器 `settings.json` 写着 `LXGWWenKaiMono NF` 但系统里根本没这个字体，
> 一直是 fallback 在渲染 —— 图标缺失但**不报错**。所以必须查注册表，不能看配置。

---

## 5. 应用配置

**方式 A（推荐，全自动 + 备份）**

```powershell
pwsh -File deploy\deploy.ps1 -Theme latte-warm -Font "<检测到的字体>"
```

**方式 B（Git Bash 内）**

```bash
bash scripts/install.sh latte-warm        # 加 --no-wt 则不动 Windows Terminal
```

**方式 C（手动分步，仅当脚本不可用）**

```bash
# 1. 备份
cp ~/.bashrc ~/.bashrc.bak-$(date +%Y%m%d-%H%M%S)
# 2. 写入 shell 配置
cp bash/bashrc ~/.bashrc
grep -q bashrc ~/.bash_profile || printf '\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> ~/.bash_profile
# 3. 生成主题色
node "$(cygpath -m scripts/gen-colors.js)" "$(cygpath -m themes/latte-warm.json)" "$(cygpath -m ~/.warm-terminal/colors.sh)"
# 4. 生成并写入 WT 配置（先备份目标！）
node "$(cygpath -m scripts/build-wt-settings.js)" "$(cygpath -m themes/latte-warm.json)" "$(cygpath -m windows-terminal/settings.json)"
cp "$LOCALAPPDATA/Microsoft/Windows Terminal/settings.json" "$LOCALAPPDATA/Microsoft/Windows Terminal/settings.json.bak-$(date +%Y%m%d-%H%M%S)"
cp windows-terminal/settings.json "$LOCALAPPDATA/Microsoft/Windows Terminal/settings.json"
```

> ⚠️ node 是 Windows 程序：传给它路径前必须 `cygpath -m`，否则报 `Cannot find module 'C:\c\Users...'`。

---

## 6. 验证断言（必须全部通过才算完成）

```bash
# 1. bashrc 已生效
grep -q "Warm Terminal" ~/.bashrc && echo OK1

# 2. 主题色文件存在且含 4 个变量
grep -c "^WT_" ~/.warm-terminal/colors.sh        # 期望 >= 4

# 3. bashrc 语法无误（这一步能抓住 90% 的手改错误）
bash -n ~/.bashrc && echo OK3

# 4. WT 配置是合法 JSON
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$(cygpath -m "$LOCALAPPDATA/Microsoft/Windows Terminal/settings.json")" && echo OK4

# 5. 子 shell 里能加载（真正模拟新终端）
bash -lic 'echo $WT_THEME_NAME; alias | grep -c eza' </dev/null

# 6. 工具可用
for t in eza bat fzf zoxide; do command -v $t >/dev/null && echo "$t ok" || echo "$t MISSING"; done
```

全部通过后，告诉用户：**必须新开 Windows Terminal 窗口**（配色不热重载）。

---

## 7. 回滚

```bash
ls -1 ~/.bashrc.bak-* "$LOCALAPPDATA/Microsoft/Windows Terminal/"*.bak-* 2>/dev/null | tail -5
mv ~/.bashrc.bak-<stamp> ~/.bashrc        # 选最近的
```

`deploy.ps1` 结束时会打印本次所有备份路径，直接用它。

---

## 8. 失败分支速查

| 报错 | 原因 | 处理 |
|---|---|---|
| `Cannot find module 'C:\c\...'` | 给 node 传了 MSYS 路径 | 用 `cygpath -m` 转换 |
| `.bashrc` 改了没生效 | Git Bash 登录 shell 不读 `.bashrc` | 检查 `~/.bash_profile` 是否有 `source ~/.bashrc` |
| 图标是方块 | 字体不带 NF / 名字写错 | 见 §4，查注册表 + `-Font` 指定已装字体 |
| 配色没变 | WT 不热重载 | 新开窗口；确认写的是真的那份 `settings.json`（Store 版在 `Packages\...\LocalState\`） |
| `applicationTheme` 无效 | 旧版 Windows Terminal | 忽略；其余配色仍生效 |
| `theme: command not found` | `WARM_TERMINAL_DIR` 指向不对 | `export WARM_TERMINAL_DIR=/实际路径` 写进 `~/.bashrc` |
| `bat: unknown theme` | bat 版本旧 | 改 `themes/*.json` 的 `shell.batTheme` 为 `bat --list-themes` 里存在的名字 |
| CRLF 报错 `\r` | 脚本被转成 CRLF | `.gitattributes` 已有规则；必要时 `git config core.autocrlf false` 后重新 clone |

---

## 9. 任务：新增一个主题（最常见的二次开发）

```bash
cp themes/latte-warm.json themes/my-theme.json
# 编辑：name（=文件名）、label（WT 显示名）、description
#        terminal.scheme.*      16 色 + bg/fg/cursor/selection
#        terminal.appTheme.*    标签栏 + applicationTheme
#        shell.promptDir/Git    形如 "\\[\\033[32m\\]"
#        shell.batTheme         bat --list-themes 里有的名字
#        shell.fzf              --color=... 字符串
npm run preview                          # 生成预览（与 CI 同字体）
bash scripts/apply-theme.sh my-theme     # 本机验证
```

**自检**：色值必须是 `#rrggbb`；`promptDir` 必须是 JSON 转义后的 `\[\033[..m\]`；
`label` 全局唯一（WT 里 scheme 名重复会冲突）。

---

## 10. 交付报告格式（给用户的最终消息）

```
已完成：
- 备份：~/.bashrc.bak-20261126-101500、WT settings.json.bak-20261126-101500
- 改动：~/.bashrc、~/.warm-terminal/{colors.sh,tools.sh}、WT settings.json
- 主题：tokyo-night   字体：CaskaydiaCove NF（本机已装）
- 验证：bash -n / JSON 解析 / 子 shell 加载 / 4 个工具  全部通过

需要你做：
1. 新开一个 Windows Terminal 窗口（配色不热重载）
2. 若图标仍为方块：按 docs/FONTS.md §3 检查字体

回滚命令：mv ~/.bashrc.bak-20261126-101500 ~/.bashrc
```

**不要**只说"完成了" —— 必须列出改了哪些文件、备份在哪、怎么回滚。
