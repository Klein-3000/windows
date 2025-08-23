# Starship Theme
Invoke-Expression (&starship init powershell)

# ===================================================================
#  PowerShell 模块化配置入口
# ===================================================================

# 设置 config 目录路径
$CONFIG_DIR = Join-Path $PSScriptRoot "config"

# ===============================
#  定义配置文件路径（避免与 $script:paths 冲突）
# ===============================
$config_files = @{
    aliases    = Join-Path $CONFIG_DIR "aliases.ps1"
    navigation = Join-Path $CONFIG_DIR "navigation.ps1"
    paths      = Join-Path $CONFIG_DIR "paths.ps1"
    utils      = Join-Path $CONFIG_DIR "utils.ps1"
    keyhandler = Join-Path $CONFIG_DIR "keyhandler.ps1"
}

# 可选：创建简短别名（如果不想每次都打 $config_files.）
$aliases    = $config_files.aliases
$navigation = $config_files.navigation
$utils      = $config_files.utils
$keyhandler = $config_files.keyhandler
# ❌ 不创建 $paths，避免冲突

# ===============================
#  定义函数：Import-Config
# ===============================
function Import-Config {
    param([string]$Name)
    $path = $config_files[$Name]
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
#  加载所有配置模块
# ===============================
Import-Config "paths"
Import-Config "navigation"
Import-Config "aliases"
Import-Config "utils"
Import-Config "keyhandler"

# ===============================
#  启动完成提示
# ===============================
Write-Host "🎉 PowerShell 配置已加载" -ForegroundColor Cyan