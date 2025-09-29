# ===================================================================
#  PowerShell 模块化配置文件 (Microsoft.PowerShell_profile.ps1)
#  作者: Klein-3000 
#  版本: 1.0.0
#  目标: 提供可维护、可扩展、高性能的 PowerShell 启动体验
# ===================================================================

# ===============================
#  环境变量设置
# ===============================
$env:EDITOR = "nvim"
$env:POSH_FZF_PREVIEW_CMD = "eza --icons"
$env:OBEXE_HOME = "D:\obsidian\obsidian.exe"
$env:Path += ";C:\Program Files\Git\usr\bin"

# ===============================
#  解决中文乱码 & 输出编码问题
# ===============================
[Console]::InputEncoding = [Console]::OutputEncoding = [Text.Encoding]::Utf8
$OutputEncoding = [Text.Encoding]::Utf8

# PowerShell 7+ 真彩色支持（如果使用 pwsh）
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.OutputRendering = 'ANSI'
}

# ===============================
#  设置配置目录（仅在未定义时创建为常量）
# ===============================
if (-not (Get-Variable -Name CONFIG_DIR -Scope Script -ErrorAction Ignore)) {
    Set-Variable -Name CONFIG_DIR -Value (Join-Path $PSScriptRoot "config") -Scope Script -Option Constant
}

# ===============================
#  定义核心配置文件路径（有序，避免加载顺序问题）
# ===============================
$config_files = [ordered]@{
    paths      = Join-Path $CONFIG_DIR "paths.ps1"
    utils      = Join-Path $CONFIG_DIR "utils.ps1"
    navigation = Join-Path $CONFIG_DIR "navigation.ps1"
    aliases    = Join-Path $CONFIG_DIR "aliases.ps1"
    keyhandler = Join-Path $CONFIG_DIR "keyhandler.ps1"
    network    = Join-Path $CONFIG_DIR "network.ps1"
    tools      = Join-Path $CONFIG_DIR "tools"  # tools 目录路径
}

# 可选：创建简短别名（避免频繁输入 $config_files.xxx）
# paths输出效果不符预期
#$script:paths      = $config_files.paths
$script:utils      = $config_files.utils
$script:navigation = $config_files.navigation
$script:aliases    = $config_files.aliases
$script:keyhandler = $config_files.keyhandler
$script:network    = $config_files.network

# ===============================
#  定义函数：Import-Config
#  用于安全加载核心模块
# ===============================
function Import-Config {
    param([string]$Name)
    $path = $config_files[$Name]
    if (-not $path) {
        Write-Warning "⚠️ 未知模块: $Name"
        return
    }
    if (Test-Path $path) {
        try {
            Write-Host "⏳ 加载配置: $Name ..." -ForegroundColor Gray
            . $path
            Write-Host "✅ 已加载: $Name" -ForegroundColor Green
        }
        catch {
            Write-Error "❌ 加载失败: $Name`n$_"
        }
    }
    else {
        Write-Warning "⚠️ 配置文件未找到: $path"
    }
}

# ===============================
#  模式设置
# ===============================
Set-PSReadLineOption -EditMode Emacs

# ===============================
#  加载所有核心配置模块（顺序重要！）
# ===============================
Import-Config "paths"
Import-Config "utils"
Import-Config "navigation"
Import-Config "aliases"
Import-Config "keyhandler"
Import-Config "network"

# ===============================
#  自动加载 config/tools/ 中的所有 .ps1 脚本（插件系统）
# ===============================
$toolsDir = $config_files.tools
$script:tools = [ordered]@{}

if (Test-Path $toolsDir) {
    Write-Host "⏳ 加载工具模块: tools ..." -ForegroundColor Gray
    Get-ChildItem $toolsDir -Filter "*.ps1" -File -Recurse | Sort-Object Name | ForEach-Object {
        $toolName = $_.BaseName
        $script:tools[$toolName] = $_.FullName
        try {
            Write-Host "⏳ 加载工具: $toolName ..." -ForegroundColor Gray
            . $_.FullName
            Write-Host "✅ 已加载: $toolName" -ForegroundColor Green
        }
        catch {
            Write-Error "❌ 加载失败: $toolName`n$_"
        }
    }
    Write-Host "✅ 所有工具脚本加载完成（共 $($tools.Count) 个工具）" -ForegroundColor Cyan
}
else {
    Write-Warning "⚠️ 工具目录不存在: $toolsDir"
    Write-Host "💡 提示: 你可以创建该目录并放入自定义工具脚本。" -ForegroundColor Yellow
}

# ===============================
#  外观与主题 (Starship)
# ===============================
try {
    $env:STARSHIP_CONFIG = "$PSScriptRoot\StarshipTheme\starship.CoryCharlton"
    Invoke-Expression (&starship init powershell) -ErrorAction Stop
}
catch {
    Write-Warning "⚠️ Starship 初始化失败，确保已安装 starship"
}

# ===============================
#  启动完成提示
# ===============================
Write-Host "🎉 PowerShell 配置已加载" -ForegroundColor Cyan

# ===============================
#  便捷命令
# ===============================
# 创建重新加载配置的函数（不是别名）
function global:reload {
    . $PROFILE
    Write-Host "✅ PowerShell 配置已重新加载" -ForegroundColor Green
}
