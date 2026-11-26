<#
.SYNOPSIS
    Warm Terminal 一键部署（Windows PowerShell 5.1 / PowerShell 7）

.DESCRIPTION
    不依赖 winget / scoop / 已配置好的 Git Bash。会自动：
      1. 检查 Git Bash（Git for Windows / MSYS2 / Scoop 都认）
      2. 检查 Node.js（主题系统依赖，缺失则降级为内置默认配色）
      3. 安装依赖：eza / bat / fzf / zoxide / lazygit（包管理器优先，否则 GitHub Release 直下）
      4. 检查 / 安装 Nerd Font
      5. 写入 ~/.bashrc、~/.warm-terminal/{colors.sh,tools.sh}
      6. 生成并写入 Windows Terminal settings.json

    幂等：可重复执行；覆盖前都会备份 *.bak-<时间戳>。

.PARAMETER Theme
    主题名（themes/*.json 文件名），默认 latte-warm。

.PARAMETER ToolsDir
    依赖工具目录，默认 %LOCALAPPDATA%\warm-terminal\bin，写入 ~/.warm-terminal/tools.sh。

.PARAMETER Font
    Windows Terminal 字体名，默认 "LXGWWenKaiMono NF"。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1

.EXAMPLE
    pwsh -File deploy\deploy.ps1 -Theme tokyo-night -Font "JetBrainsMono NF" -DryRun
#>
[CmdletBinding()]
param(
    [string]$Theme = 'latte-warm',
    [string]$ToolsDir,
    [string]$Font = 'LXGWWenKaiMono NF',
    [switch]$SkipTools,
    [switch]$SkipFont,
    [switch]$SkipGit,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$RepoDir  = Split-Path -Parent $PSScriptRoot
$Stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$StateDir = Join-Path $env:USERPROFILE '.warm-terminal'
if (-not $ToolsDir) { $ToolsDir = Join-Path $env:LOCALAPPDATA 'warm-terminal\bin' }

$script:Changes = New-Object System.Collections.ArrayList

function Write-Step([string]$n, [string]$msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    OK   $msg" -ForegroundColor Green }
function Write-Warn2([string]$msg){ Write-Host "    WARN $msg" -ForegroundColor Yellow }
function Write-Skip([string]$msg) { Write-Host "    SKIP $msg" -ForegroundColor DarkGray }
function Write-Plan([string]$msg) { Write-Host "    PLAN $msg" -ForegroundColor Magenta }

function Invoke-OrPlan([string]$desc, [scriptblock]$action) {
    if ($DryRun) { Write-Plan $desc; return }
    & $action
}

function Backup-File([string]$path) {
    if (Test-Path $path) {
        $bak = "$path.bak-$Stamp"
        Copy-Item $path $bak -Force
        [void]$script:Changes.Add("备份 $(Split-Path -Leaf $path) -> $(Split-Path -Leaf $bak)")
        return $bak
    }
    return $null
}

# C:\x\y  ->  /c/x/y  （Git Bash 认的形式）
function ConvertTo-BashPath([string]$p) {
    $r = $p -replace '\\', '/'
    if ($r -match '^([A-Za-z]):(.*)$') { $r = '/' + $Matches[1].ToLower() + $Matches[2] }
    return $r
}

Write-Host @"
============================================================
 Warm Terminal 一键部署
============================================================
 仓库目录 : $RepoDir
 主题     : $Theme
 工具目录 : $ToolsDir
 字体     : $Font
 DryRun   : $DryRun
"@ -ForegroundColor White

if (-not (Test-Path (Join-Path $RepoDir 'themes'))) {
    throw "当前脚本不在仓库内（缺 themes/ 目录）：$RepoDir"
}

# ---------------------------------------------------------------- 1. Git Bash
Write-Step '1/6' '检查 Git Bash'

function Find-GitBash {
    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $root = Split-Path (Split-Path $git.Source -Parent) -Parent
        $candidates += (Join-Path $root 'bin\bash.exe')
        $candidates += (Join-Path $root 'usr\bin\bash.exe')
    }
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) { $candidates += $bash.Source }

    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

$gitBash = Find-GitBash
if ($gitBash) {
    Write-Ok "已安装: $gitBash"
} elseif ($SkipGit) {
    Write-Skip '-SkipGit：跳过'
} else {
    Write-Warn2 '未找到 Git Bash'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Invoke-OrPlan 'winget install Git.Git' {
            winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements --silent
        }
    } elseif ($DryRun) {
        Write-Plan '需手动安装 Git for Windows：https://git-scm.com/download/win'
    } else {
        throw '未找到 Git Bash 且无 winget，请手动安装：https://git-scm.com/download/win'
    }
}

# ---------------------------------------------------------------- 2. Node
Write-Step '2/6' '检查 Node.js（主题系统依赖）'
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    Write-Ok "node $(node -v)"
} else {
    Write-Warn2 '未找到 node：主题配色会退回 ~/.bashrc 内置默认值'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Invoke-OrPlan 'winget install OpenJS.NodeJS.LTS' {
            winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements --silent
        }
    } else {
        Write-Warn2 '可手动安装：https://nodejs.org/'
    }
}

# ---------------------------------------------------------------- 3. 工具
function Install-FromGitHub([string]$repo, [string]$assetPattern, [string[]]$exeNames) {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" `
                              -Headers @{ 'User-Agent' = 'warm-terminal-deploy' }
    $asset = $rel.assets | Where-Object { $_.name -match $assetPattern } | Select-Object -First 1
    if (-not $asset) { throw "$repo 最新 Release 无匹配 $assetPattern 的资产" }

    $tmpZip = Join-Path $env:TEMP ("wt-" + $asset.name)
    Write-Host "    下载 $($asset.name)" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip
    $tmpDir = Join-Path $env:TEMP ("wt-x-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

    $found = @()
    foreach ($exe in $exeNames) {
        $f = Get-ChildItem -Path $tmpDir -Recurse -Filter $exe -File | Select-Object -First 1
        if ($f) { Copy-Item $f.FullName (Join-Path $ToolsDir $exe) -Force; $found += $exe }
    }
    Remove-Item $tmpZip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($found.Count -eq 0) { throw "$repo 包里没找到 $($exeNames -join '/')" }
    Write-Ok "已安装 $($found -join ', ') -> $ToolsDir"
}

Write-Step '3/6' '安装依赖工具（eza / bat / fzf / zoxide / lazygit）'
if ($SkipTools) {
    Write-Skip '-SkipTools：跳过'
} else {
    Invoke-OrPlan "创建工具目录 $ToolsDir" {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }
    if (-not $DryRun) { $env:PATH = "$ToolsDir;$env:PATH" }

    $missing = @()
    foreach ($t in @(
        @{ Cmd = 'eza.exe';     Repo = 'eza-community/eza';     Pattern = 'x86_64-pc-windows-(gnu|msvc)\.zip$'; Exes = @('eza.exe') },
        @{ Cmd = 'bat.exe';     Repo = 'sharkdp/bat';           Pattern = 'x86_64-pc-windows-msvc\.zip$';       Exes = @('bat.exe') },
        @{ Cmd = 'fzf.exe';     Repo = 'junegunn/fzf';          Pattern = 'windows_amd64\.zip$';                Exes = @('fzf.exe') },
        @{ Cmd = 'zoxide.exe';  Repo = 'ajeetdsouza/zoxide';    Pattern = 'x86_64-pc-windows-msvc\.zip$';       Exes = @('zoxide.exe') },
        @{ Cmd = 'lazygit.exe'; Repo = 'jesseduffield/lazygit'; Pattern = 'Windows_x86_64\.zip$';               Exes = @('lazygit.exe') }
    )) {
        if (Get-Command $t.Cmd -ErrorAction SilentlyContinue) { Write-Ok "$($t.Cmd) 已存在，跳过" }
        else { $missing += $t }
    }

    if ($DryRun) {
        foreach ($m in $missing) { Write-Plan "从 GitHub Release 下载 $($m.Cmd)" }
    } else {
        foreach ($m in $missing) {
            try { Install-FromGitHub -repo $m.Repo -assetPattern $m.Pattern -exeNames $m.Exes }
            catch {
                Write-Warn2 "$($m.Cmd) 安装失败：$($_.Exception.Message)"
                Write-Warn2 "手动装：https://github.com/$($m.Repo)/releases  （解压放到 $ToolsDir）"
            }
        }
    }
}

# ---------------------------------------------------------------- 4. 字体
Write-Step '4/6' "检查字体 $Font"
if ($SkipFont) {
    Write-Skip '-SkipFont：跳过'
} else {
    $fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

    # 注册表里的字体名和 CSS/WT 里的名字不完全一致（空格、NF/Nerd Font 后缀），做归一化比较
    function Get-InstalledFontNames {
        $names = @()
        foreach ($root in @('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
                            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
            if (Test-Path $root) { $names += (Get-ItemProperty $root).PSObject.Properties.Name }
        }
        return $names
    }
    function ConvertTo-FontKey([string]$s) {
        if (-not $s) { return '' }
        $t = $s -replace '\(.*?\)', '' -replace '\s', '' -replace 'NerdFont', 'NF'
        return $t.ToLowerInvariant()
    }

    $installedFonts = Get-InstalledFontNames
    $targetKey = ConvertTo-FontKey $Font
    $fontHit = @($installedFonts | Where-Object { (ConvertTo-FontKey $_) -like "*$targetKey*" }).Count -gt 0

    if ($fontHit) {
        Write-Ok "$Font 已安装"
    } else {
        Write-Warn2 "$Font 未安装（图标会退化成方块或系统 fallback 字体）"
        $nerdCandidates = $installedFonts | Where-Object { $_ -match ' NF |Nerd Font' } |
                          ForEach-Object { $_ -replace '\s*\(TrueType\)', '' } |
                          Select-Object -Unique -First 5
        if ($nerdCandidates) {
            Write-Host '    本机已装的可选 Nerd Font（可用 -Font 指定）：' -ForegroundColor DarkGray
            $nerdCandidates | ForEach-Object { Write-Host "      - $_" -ForegroundColor DarkGray }
        }
        Write-Host '    安装方式（三选一）：' -ForegroundColor DarkGray
        Write-Host '      scoop bucket add nerd-fonts; scoop install LXGWWenKaiMono-NF' -ForegroundColor DarkGray
        Write-Host '      winget install --id DEVCOM.JetBrainsMonoNerdFont  （改用 -Font "JetBrainsMono NF"）' -ForegroundColor DarkGray
        Write-Host '      下载 ttf 双击安装（详见 docs/FONTS.md）' -ForegroundColor DarkGray

        $ttf = Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads') -Filter '*.ttf' -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match 'NF|Nerd|Lxgw|LXGW' } | Select-Object -First 1
        if ($ttf) {
            Invoke-OrPlan "把 $($ttf.Name) 装到用户字体（$fontDir）" {
                if (-not (Test-Path $fontDir)) { New-Item -ItemType Directory -Path $fontDir -Force | Out-Null }
                Copy-Item $ttf.FullName $fontDir -Force
                $dest = Join-Path $fontDir $ttf.Name
                $regName = $Font + ' (TrueType)'
                if (-not (Test-Path $fontKey)) { New-Item -Path $fontKey -Force | Out-Null }
                New-ItemProperty -Path $fontKey -Name $regName -Value $dest -PropertyType String -Force | Out-Null
                Write-Ok "已注册字体 $regName（重开终端生效）"
            }
        } else {
            Write-Skip 'Downloads 里没有字体文件，跳过自动安装'
        }
    }
}

# ---------------------------------------------------------------- 5. shell
Write-Step '5/6' '写入 shell 配置（~/.bashrc + ~/.warm-terminal/）'
Invoke-OrPlan "生成 ~/.warm-terminal/tools.sh（TOOLS_BIN=$(ConvertTo-BashPath $ToolsDir)）" {
    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
    $bashTools = ConvertTo-BashPath $ToolsDir
    Set-Content -Path (Join-Path $StateDir 'tools.sh') -Value "export TOOLS_BIN='$bashTools'" -Encoding ASCII
    Write-Ok "TOOLS_BIN=$bashTools"
}

$bashrc      = Join-Path $env:USERPROFILE '.bashrc'
$bashProfile = Join-Path $env:USERPROFILE '.bash_profile'
[void](Backup-File $bashrc)
Invoke-OrPlan '写入 ~/.bashrc（旧文件已备份）' {
    Copy-Item (Join-Path $RepoDir 'bash\bashrc') $bashrc -Force
    Write-Ok '~/.bashrc'
}
Invoke-OrPlan '确保 ~/.bash_profile 里 source ~/.bashrc' {
    $need = $true
    if (Test-Path $bashProfile) {
        $need = -not (Select-String -Path $bashProfile -Pattern 'bashrc' -Quiet)
    }
    if ($need) {
        Add-Content -Path $bashProfile -Value "`n[ -f ~/.bashrc ] && . ~/.bashrc"
        Write-Ok '~/.bash_profile'
    } else {
        Write-Skip '~/.bash_profile 已包含 source'
    }
}

# ---------------------------------------------------------------- 6. 主题
Write-Step '6/6' "应用主题 $Theme 与 Windows Terminal 配置"
if ($nodeCmd) {
    $themeFile = Join-Path $RepoDir "themes\$Theme.json"
    if (-not (Test-Path $themeFile)) { throw "主题不存在：$themeFile" }

    Invoke-OrPlan "生成 ~/.warm-terminal/colors.sh（$Theme）" {
        node (Join-Path $RepoDir 'scripts\gen-colors.js') $themeFile (Join-Path $StateDir 'colors.sh') | Out-Null
        Set-Content -Path (Join-Path $StateDir 'current') -Value $Theme -Encoding ASCII
        Write-Ok '~/.warm-terminal/colors.sh'
    }

    $basePath = Join-Path $RepoDir 'windows-terminal\settings.base.json'
    $baseJson = Get-Content $basePath -Raw | ConvertFrom-Json
    if ($baseJson.profiles.defaults.font.face -ne $Font) {
        Write-Warn2 "settings.base.json 字体将改为 '$Font'"
        Invoke-OrPlan "改写 settings.base.json 的 font.face" {
            $baseJson.profiles.defaults.font.face = $Font
            $baseJson | ConvertTo-Json -Depth 20 | Set-Content $basePath -Encoding UTF8
        }
    }

    $genOut = Join-Path $RepoDir 'windows-terminal\settings.json'
    Invoke-OrPlan 'base + 主题 → settings.json' {
        node (Join-Path $RepoDir 'scripts\build-wt-settings.js') $themeFile $genOut | Out-Null
        Write-Ok 'settings.json 已生成'
    }

    $wt = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($wt) {
        $wtBackup = Backup-File $wt
        Invoke-OrPlan "写入 Windows Terminal：$wt" {
            Copy-Item $genOut $wt -Force
            Write-Ok "已写入（备份 $(Split-Path -Leaf $wtBackup)）"
        }
    } else {
        Write-Warn2 '未找到 Windows Terminal，跳过（可手动复制 windows-terminal\settings.json）'
    }
} else {
    Write-Warn2 '没有 node：只写了 ~/.bashrc（内置默认 Latte Warm 配色）'
    Write-Warn2 '装好 Node 后重跑本脚本即可启用完整主题系统'
}

# ---------------------------------------------------------------- 汇总
$changesText = if ($script:Changes.Count -eq 0) { '   （DryRun 或无需改动）' }
               else { ($script:Changes | ForEach-Object { "   - $_" }) -join "`n" }

Write-Host @"

============================================================
 完成
============================================================
 备份/改动：
$changesText

 下一步：
   1. 重开一个 Windows Terminal 窗口（配色需新窗口才生效）
   2. Git Bash 里执行： source ~/.bashrc
   3. 换主题： theme            # 列出
             theme nord       # 切换
 回滚：
   把 *.bak-$Stamp 改回原名即可
"@ -ForegroundColor White

if ($DryRun) { Write-Host '（DryRun：未做任何实际修改）' -ForegroundColor Magenta }
