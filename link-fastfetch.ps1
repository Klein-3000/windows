# link-fastfetch.ps1
# 功能：自动将当前目录的 fastfetch 文件夹软链接到用户 .config 目录

# 使用环境变量获取用户名
$username = $env:USERNAME

# 定义源路径：当前目录下的 fastfetch 文件夹
$sourcePath = Join-Path $PWD "fastfetch"

# 定义目标目录和链接路径
$destinationDir = "C:\Users\$username\.config"
$linkPath = Join-Path $destinationDir "fastfetch"

# 检查源文件夹是否存在
if (-not (Test-Path $sourcePath)) {
    Write-Error "❌ 源文件夹不存在: $sourcePath"
    Write-Host "请确保当前目录下有 'fastfetch' 文件夹。"
    exit 1
}

# 确保 .config 目录存在
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

# 如果目标链接或文件已存在，处理冲突
if (Test-Path $linkPath) {
    $item = Get-Item $linkPath
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "🔗 已存在符号链接: $linkPath，正在删除..." -ForegroundColor Yellow
        Remove-Item $linkPath -Force
    }
    else {
        Write-Warning "⚠️  路径已存在且不是链接: $linkPath"
        $choice = Read-Host "是否删除并创建新链接? [y/N]"
        if ($choice -notmatch '^[Yy]') {
            Write-Host "操作已取消。"
            exit 0
        }
        Remove-Item $linkPath -Recurse -Force  # 支持文件或目录
    }
}

# 创建指向 fastfetch 文件夹的符号链接
try {
    New-Item -ItemType SymbolicLink `
             -Path $linkPath `
             -Target $sourcePath `
             -ErrorAction Stop | Out-Null

    Write-Host "✅ 成功创建符号链接!" -ForegroundColor Green
    Write-Host "   🔗 $linkPath" -ForegroundColor Gray
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