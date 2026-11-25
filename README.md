# Warm Terminal 🌤️

> 一套「浅色暖调」的 Windows 终端配置：Windows Terminal + Git Bash。
> Latte Warm 配色 · Nerd Font 图标 · 两行式简洁提示符 · fzf / eza / bat / zoxide 全家桶。

<!-- 建议放一张截图： screenshots/preview.png -->
<!-- ![preview](screenshots/preview.png) -->

## ✨ 特性

| 能力 | 实现 | 效果 |
|---|---|---|
| 配色 | Windows Terminal 自定义 `Latte Warm` 方案 | 米色底 `#f3ead9` + 暖棕/玫红强调色 |
| 字体 | `LXGWWenKaiMono NF` + Cascadia | 中文等宽 + Nerd Font 图标 |
| 提示符 | 纯 `PS1`，两行式 | 绿色路径 + 青色 git 分支，去掉 `user@host` |
| 文件列表 | [eza](https://github.com/eza-community/eza) | `ls` / `ll` / `la` / `lt` 带图标 |
| 查看文件 | [bat](https://github.com/sharkdp/bat) | `cat` 直接语法高亮 |
| 跳转 | [zoxide](https://github.com/ajeetdsouza/zoxide) | `z 关键目录` 秒跳 |
| 模糊搜索 | [fzf](https://github.com/junegunn/fzf) | 配色与主题一致 |
| 命令纠错 | [pay-respects](https://github.com/iffse/pay-respects) | 敲错命令后输入 `fuck` 自动修正 |
| 提交 | [lazygit](https://github.com/jesseduffield/lazygit) | `lg` 打开图形化 git |
| 快捷开窗 | 自定义函数 `mt` | 在当前目录弹出美化终端 |

## 📁 目录结构

```
warm-terminal/
├── bash/bashrc                  # → ~/.bashrc
├── windows-terminal/settings.json # → Windows Terminal 配置
├── scripts/
│   ├── install.sh               # 一键安装（Git Bash）
│   └── install-tools.ps1        # 依赖工具安装（PowerShell）
└── screenshots/                 # 截图放这里
```

## 🚀 安装

### 1. 装字体（必须，否则图标是方块）

任选其一：

```powershell
scoop bucket add nerd-fonts
scoop install LXGWWenKaiMono-NF
```

或从 [LXGW WenKai](https://github.com/lxgw/LxgwWenKai) 下载后安装，并确认字体名带 `NF` 后缀。

### 2. 装依赖工具

```powershell
pwsh -File scripts\install-tools.ps1
```

`lazygit` / `pay-respects` 需要额外装：

```powershell
scoop install lazygit
cargo install pay-respects        # 或 cargo binstall
```

把 `eza.exe / bat.exe / fzf.exe / zoxide.exe` 放进同一个目录（脚本默认 `D:\Tools\bin`），
如果放别处，安装后改一下 `~/.bashrc` 里的 `TOOLS_BIN`，或设置同名环境变量。

### 3. 应用配置

在 Git Bash 中：

```bash
git clone <本仓库地址> ~/projects/warm-terminal
cd ~/projects/warm-terminal
bash scripts/install.sh
```

脚本会：备份原 `~/.bashrc` 与 Windows Terminal 的 `settings.json` → 写入新配置 → 确保
`.bash_profile` 里有 `source ~/.bashrc`。只装 bash 部分可加 `--no-wt`。

### 4. 生效

重开终端，或 `source ~/.bashrc`。

## 🎨 自定义

**换配色**：编辑 `windows-terminal/settings.json` 的 `schemes` / `themes`，改完在
Windows Terminal 里 `Ctrl+,` 也能可视化调整。fzf 的配色在 `bash/bashrc` 的
`FZF_DEFAULT_OPTS` 里，两边色值保持一致观感最好。

**换字体**：改 `profiles.defaults.font.face`。

**路径不一致**：`bash/bashrc` 顶部 `TOOLS_BIN` 改成你的工具目录。

## ⚠️ 注意

- 仓库里**不要**放 `$HOME` 整个目录，也别在 `C:\Users\<你的用户名>` 里 `git init`——
  会把 `.ssh`、`AppData`、注册表文件一起传上去。
- `settings.json` 里的 profile 路径用了 `%ProgramFiles%`、`pwsh.exe` 等环境变量/命令名，
  不同机器上按需调整。
- Git Bash 里 clone 若出现 CRLF 警告，可加 `.gitattributes` 或 `git config core.autocrlf false`。

## 📄 License

MIT
