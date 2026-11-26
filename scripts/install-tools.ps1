# ============================================================
#  Warm Terminal — 依赖工具安装 (PowerShell 7 / Windows)
#  用法（在 PowerShell 中）：
#     pwsh -File scripts\install-tools.ps1
# ============================================================
$ErrorActionPreference = 'Stop'

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!!  $m" -ForegroundColor Yellow }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw '未找到 winget，请先安装 App Installer（Microsoft Store 搜索 "App Installer"）'
}

$pkgs = @(
    @{ Id = 'JanDeDobbeleer.OhMyPosh';          Skip = $true },  # 未使用，保留占位
    @{ Id = 'eza-community.eza' },                            # 彩色 ls
    @{ Id = 'ajeetdsouza.zoxide' },                           # 智能 cd
    @{ Id = 'sharkdp.bat' },                                  # 语法高亮 cat
    @{ Id = 'junegunn.fzf' }                                  # 模糊查找
)

foreach ($p in $pkgs) {
    if ($p.Skip) { continue }
    Info "安装 $($p.Id)"
    try {
        winget install --id $p.Id -e --accept-source-agreements --accept-package-agreements --silent
    } catch {
        Warn "安装 $($p.Id) 失败：$_"
    }
}

# ---- 需要手动/其他渠道的 ----
Info 'lazygit / pay-respects 建议用 scoop 或 cargo 安装：'
Write-Host '    scoop install lazygit' -ForegroundColor DarkGray
Write-Host '    cargo install pay-respects' -ForegroundColor DarkGray

# ---- 字体 ----
Warn '字体需手动安装（推荐 Maple Mono NF CN：中文 + 图标）：'
Write-Host '    https://github.com/lxgw/LxgwWenKai  +  https://www.nerdfonts.com/font-downloads' -ForegroundColor DarkGray
Write-Host '    scoop bucket add nerd-fonts; scoop install Maple-Mono-NF-CN' -ForegroundColor DarkGray

Write-Host ''
Info '依赖安装结束。请重开终端让 PATH 生效。'
