# 设计文档

> 这份文档解释 **为什么** 代码长这样，而不是「怎么用」（用法见 [README](../README.md)，
> AI 执行手册见 [AGENTS.md](../AGENTS.md)，字体见 [FONTS.md](FONTS.md)）。

## 1. 目标与非目标

**要解决的三个具体问题**

1. Windows 原生终端默认又丑又难用：没有图标、没有 git 分支、`ls` 不分区、`cd` 靠记路径。
2. 网上的「美化教程」是**一次性的**：装完就散落在 `~/.bashrc`、`settings.json`、
   `fzf` 环境变量、`bat` 配置文件里，换机器要重新抄一遍，改配色要同时改 4 个地方。
3. 想换风格（浅色↔深色）时，终端配色和 shell 配色不同步 —— 白底终端配深色 fzf 弹窗、
   深色终端配浅色提示符，非常割裂。

**非目标**

- 不做跨平台（macOS/Linux 有现成的 starship + WezTerm 生态，没必要自己造）。
- 不做插件管理器（不引 oh-my-zsh / antibody，避免启动变慢）。
- 不追求「零依赖」（见 §5 的取舍）。

## 2. 核心决策：主题是唯一数据源

```
themes/<name>.json   ← 一个人写、一个人改、进 git review
   │
   ├─→ ~/.warm-terminal/colors.sh     （bash 运行时读：PS1 颜色、FZF_DEFAULT_OPTS、BAT_THEME）
   ├─→ windows-terminal/settings.json （Windows Terminal 读：colorScheme、tab theme、font）
   └─→ screenshots/<name>.svg         （README 读：预览图）
```

一份 JSON 同时喂三个消费者。**改配色 = 改一个 JSON 文件**，其余全是生成物。

关键点：**生成物进 git，但带「此处为生成」的显式声明**。
（`settings.json`、`screenshots/*` 都提交，因为用户 clone 下来直接可用；
但 README 和目录树里明确标注它们是生成物，避免用户手改后被覆盖后崩溃。）

## 3. 模块划分与职责边界

| 模块 | 文件 | 只做一件事 | 明确不做 |
|---|---|---|---|
| 主题数据 | `themes/*.json` | 声明颜色与名字 | 不写逻辑 |
| bash 运行时 | `bash/bashrc` | 消费 `WT_*` 变量，装配 prompt 与 alias | 不含任何颜色字面量 |
| shell 配色生成 | `scripts/gen-colors.js` | 主题 → `colors.sh` | 不碰 Windows Terminal |
| WT 配置生成 | `scripts/build-wt-settings.js` | `settings.base.json` + 主题 → `settings.json` | 不碰 shell |
| WT 骨架 | `windows-terminal/settings.base.json` | profile / 字体 / 快捷键（与主题无关） | 不含配色 |
| 预览图生成 | `scripts/gen-preview.js` | 主题 → SVG（+ 总览） | 不联网、不截图 |
| 编排 | `scripts/apply-theme.sh` | 依次调用上面三件事 + 备份 | 不含颜色/结构知识 |
| 安装 | `scripts/install.sh` | 首次落地（备份、写 `.bashrc`、调 apply-theme） | 不装依赖工具 |
| 依赖安装 | `scripts/install-tools.ps1` / `deploy/deploy.ps1` | 装 eza/bat/fzf/zoxide/字体 | 不碰配置内容 |
| CI | `.github/workflows/preview.yml` | 主题变更 → 重生成预览 | 不发布 release |

**边界规则（重要）**：`apply-theme.sh` 是唯一的「编排者」，它不理解颜色，只按顺序调脚本。
这样加一个消费者（比如 powershell 配色、kitty 配置）只需要加一个生成器 + 在编排里加一行。

### 数据的三种形态

```
设计期   themes/*.json          人可读、可 review、可 diff
构建期   scripts/*.js           纯函数式转换（读 JSON 写文件），无副作用、无网络
运行期   ~/.warm-terminal/*     shell 每次启动 source；极小（<1KB），无解析开销
```

`colors.sh` 刻意做成 **bash 变量赋值**而不是 JSON + 运行时解析：
启动 shell 时解析 JSON 要额外进程（node/python），会让 `打开终端` 慢 100–300 ms。

## 4. 为什么是 `PS1` 手写而不是 starship / oh-my-posh

| 方案 | 启动开销 | 依赖 | 双行 + 中文等宽控制 |
|---|---|---|---|
| 手写 `PS1`（本项目） | ~0 ms | 无 | 完全可控 |
| starship | 10–30 ms + 二进制 | Rust 二进制 | 需 TOML 调，且配置与主题脱节 |
| oh-my-posh | 20–60 ms | 二进制 + JSON 主题 | 主题系统做得好，但与我们这套重复 |

你要的只是「路径 + git 分支 + 配色」，`PS1` 十几行就够。少一个二进制 = 少一个装不上的理由。

代价：不支持右侧 prompt、异步 git 状态。对本项目的使用场景（中短路径、小仓库）可接受。

## 5. 为什么接受 Node.js 依赖

- 生成器要处理 JSON（WT 配置嵌套深）、要跨平台（CI 是 Linux）、要无需 `jq`。
  Node 是唯一「Windows 上大概率已有、Linux CI 自带、写 JSON 不用引依赖」的选择。
- **降级路径**：没有 node 时，`bash/bashrc` 内置默认 Latte Warm 配色（`: ${WT_*:=默认值}`），
  终端依然好看，只是不能切主题。所以 Node 是「增强」而不是「硬依赖」。
- 反过来，如果把生成器写成 bash + `sed`，就无法可靠地合并 JSON —— 那是更坏的取舍。

## 6. 配色模型为什么分三层

一个主题 JSON 里有三个独立的颜色集合，因为 Windows Terminal 里它们由不同机制渲染：

| 层 | 键 | 谁用它 | 为什么不能合并 |
|---|---|---|---|
| ANSI 16 色 | `scheme.black/red/green/…` | 程序自己输出的颜色（`ls`、`git`、`eza`） | 只影响「程序主动上色」的部分 |
| 背景/前景/光标 | `scheme.background/foreground/cursorColor/selectionBackground` | 终端画布 | 决定整体明暗，必须与 16 色协调 |
| 标签栏 | `appTheme.tab/tabRow/window.applicationTheme` | WT 的窗口 chrome（WinUI） | 不吃 ANSI 色，得单独给；`applicationTheme` 还决定文件对话框等系统控件明暗 |

再加上 shell 层的第四组（`promptDir` / `promptGit` / `fzf` / `batTheme`），是因为：
- 提示符用的是 ANSI SGR 码（`\033[32m`），只能映射到 16 色里的某一个，**不能**用 `#hex`；
- fzf 要自己的 `--color` 字符串（`fg:#hex` 形式，且键名不同）；
- bat 的主题名是一套完全独立的命名空间（`bat --list-themes`）。

> 这些是「同一份设计语言的四次翻译」。硬要统一成一个抽象层会引入一个翻译器，
> 而翻译器本身就容易和上游实现漂移 —— 不如显式写清楚，让主题作者明确知道有四个输出面。

## 7. 兼容性陷阱与对策（都是踩过的坑）

| 陷阱 | 现象 | 对策 |
|---|---|---|
| Git Bash 是**登录 shell** | 改了 `.bashrc` 不生效 | `install.sh` 确保 `.bash_profile` 里 `source ~/.bashrc` |
| MSYS 路径 vs Windows 路径 | `node /c/Users/...` → `Cannot find module 'C:\c\Users...'` | 用 `cygpath -m` 转成 `C:/Users/...`（正斜杠，node 和 Windows 都认） |
| CRLF | PS1 脚本被当 bash 执行报 `\r` 错 | `.gitattributes` 固定：`*.sh` LF、`*.ps1` CRLF |
| PowerShell 5.1 编码 | 中文注释变乱码/语法错 | `deploy.ps1` 存为 **UTF-8 with BOM** |
| `cat` 被 alias 成 `bat` | 复制 SSH 公钥得到带边框的文本 → `Key is invalid` | 文档里统一用 `clip.exe < file` 或 `tr -d '\r' < file` |
| WT 配置不热重载 | 切主题后窗口没变 | 文档明确：必须新开窗口 |
| `settings.json` 是生成物 | 手改的 profile 被覆盖 | 骨架拆到 `settings.base.json`，README 显著标注 |
| 图标是 PUA 私有区 | 换字体就变方块 | 字体检测做名字归一化 + 列出本机已装 NF 字体 |

## 8. 预览图为什么是「生成」而不是「截图」

- 截图：不可复现（字体/DPI/窗口大小/系统主题都会变）、要人工维护、加主题时必须手动补图。
- 生成：`themes/*.json` 一改，SVG 立即反映；CI 里用 Nerd Font 渲染，产物逐字节一致。

代价：预览图是「示意图」而非真实截图。对 README 的可信度足够，且能显示 8 套主题的统一对比。

**一致性方案**：`npm run preview` 固定字体串，与 CI 完全一致 → 本地跑完 `git status` 应为空。

## 9. 幂等与可回滚

所有写操作都遵循同一模式：

```
备份 <目标> → <目标>.bak-<时间戳>
写入新内容
失败时提示备份位置
```

- `install.sh` / `apply-theme.sh` / `deploy.ps1` 全部可重复执行（已经装了 → SKIP）。
- `deploy.ps1 -DryRun` 打印计划不做修改，供 AI 先「读」再「写」。
- 回滚 = 把 `.bak-*` 改回原名，零脚本依赖。

## 10. 扩展点

| 想做的事 | 改哪里 | 不用改 |
|---|---|---|
| 加主题 | 新增 `themes/x.json` | 所有脚本 |
| 加第三种终端消费者（Windows Terminal 之外的 konsole、kitty…） | 新增 `scripts/gen-kitty.js` + `apply-theme.sh` 加一行 | 主题、bashrc |
| 换依赖工具（yazi 替 ranger…） | `bash/bashrc` 的 alias 段 + `deploy.ps1` 的工具表 | 生成器 |
| 支持 PowerShell prompt | 新增 `scripts/gen-pwsh-colors.ps1` + WT profile | 主题 |
| 打包成 scoop/winget 包 | 加 `manifest`，复用 `deploy.ps1` | 生成器 |

## 11. 已知限制

1. 只在 Windows 10/11 + Git Bash 验证；MSYS2 的其他 shell（zsh/fish）未适配。
2. `theme` 命令在 `WARM_TERMINAL_DIR` 缺失时找不到脚本（默认 `~/projects/warm-terminal`）。
3. bat 主题名是硬编码字符串（`Catppuccin Latte` 等），旧版 bat 若没有该主题会回退默认。
4. CI 只在 `themes/**` 与 `package.json` 变更时跑，改 `gen-preview.js` 也会跑，但改 README 不会。
5. 未处理多显示器 DPI / 高 DPI 下的字体尺寸差异。
