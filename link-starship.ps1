# link-starship.ps1
# 功能：自动将当前目录的 starship.toml 软链接到用户 .config 目录

# 获取当前用户名（格式：COMPUTER\username）
$username = (whoami).Split('\')[-1]

# 或者使用 $env:USERNAME 更简单（推荐）
$username = $env:USERNAME

# 定义目标配置文件路径
$sourcePath = Join-Path $PWD "starship.toml"

# 定义链接目标路径：C:\Users\<username>\.config\starship.toml
$destinationDir = "C:\Users\$username\.config"
$destinationPath = Join-Path $destinationDir "starship.toml"

# 检查源文件是否存在
if (-not (Test-Path $sourcePath)) {
    Write-Error "❌ 源文件不存在: $sourcePath"
    Write-Host "请确保当前目录下有 'starship.toml' 文件。"
    exit 1
}

# 创建 .config 目录（如果不存在）
if (-not (Test-Path $destinationDir)) {
    try {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        Write-Host "📁 已创建目录: $destinationDir" -ForegroundColor Cyan
    }
    catch {
        Write-Error "❌ 无法创建目录: $destinationDir"
        exit 1
    }
}

# 如果已存在链接或文件，先删除
if (Test-Path $destinationPath) {
    $item = Get-Item $destinationPath
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "🔗 已存在符号链接: $destinationPath，正在删除..." -ForegroundColor Yellow
        Remove-Item $destinationPath -Force
    }
    else {
        Write-Warning "⚠️  文件已存在且不是链接: $destinationPath"
        $choice = Read-Host "是否覆盖? [y/N]"
        if ($choice -notmatch '^[Yy]') {
            Write-Host "操作已取消。"
            exit 0
        }
        Remove-Item $destinationPath -Force
    }
}

# 创建符号链接
try {
    New-Item -ItemType SymbolicLink `
             -Path $destinationPath `
             -Target $sourcePath `
             -ErrorAction Stop | Out-Null

    Write-Host "✅ 成功创建符号链接!" -ForegroundColor Green
    Write-Host "   🔗 $destinationPath" -ForegroundColor Gray
    Write-Host "   ➡️  $sourcePath" -ForegroundColor Gray
}
catch [System.UnauthorizedAccessException] {
    Write-Error "⛔ 权限不足！请以管理员身份运行 PowerShell，或启用 '开发者模式'。"
    Write-Host "💡 设置 → 隐私和安全 → 开发者 → 启用 '开发人员模式'"
    exit 1
}
catch {
    Write-Error "❌ 创建链接失败: $($_.Exception.Message)"
    exit 1
}
