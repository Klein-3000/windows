# 所有路径定义
$script:paths = @{
    gittest     = 'D:\2-桌宠\test'
    desktop     = 'D:\Users\Lenovo\Desktop'
    docs        = 'D:\Users\Lenovo\Documents'
    dotfile     = 'D:\0repository\config\.dotfile'
    lenovo      = 'C:\Users\Lenovo'
    linux       = 'D:\0repository\linux'
    live2dmodel = 'D:\2-桌宠\live2d-model'
    music       = 'D:\Users\Lenovo\Music'
    pictures    = 'D:\Users\Lenovo\Pictures\Saved Pictures'
    videos      = 'D:\Users\Lenovo\Videos'
    wallpaper   = 'D:\Steam\steamapps\workshop\content\431960'
        pwsh                  =   'D:\Users\Lenovo\Documents\PowerShell'
}

# 清理旧函数
# 更安全地清理旧函数，避免 'global:' 不存在的报错
if (Get-PSDrive -Name Function -ErrorAction SilentlyContinue) {
    Get-ChildItem Function:\ | Where-Object {
        $_.ModuleName -eq $null -and $script:paths.ContainsKey($_.Name)
    } | Remove-Item -ErrorAction SilentlyContinue
}

# 创建跳转函数
foreach ($key in $script:paths.Keys) {
    $root = $script:paths[$key]
    $functionBody = {
        param([string]$SubPath = '')
        if (-not $SubPath.Trim()) {
            if (Test-Path $root) {
                Set-Location $root
                return
            }
            else {
                Write-Error "路径不存在: $root"
                return
            }
        }
        $normalized = $SubPath -replace '[\\/]', '\'
        $target = Join-Path $root $normalized
        if (Test-Path $target -PathType Container) {
            Set-Location $target
        }
        else {
            Write-Error "目录不存在或不是文件夹: $target"
        }
    }.GetNewClosure()

    # ✅ 正确：使用 global:
    New-Item -Path "Function:\global:$key" -Value $functionBody -Force | Out-Null
}

# 列出所有路径
function global:list-path {
    if ($script:paths -and $script:paths.Count -gt 0) {
        Write-Host "`n🎯 当前可用快速跳转命令：" -ForegroundColor Cyan
        foreach ($key in $script:paths.Keys | Sort-Object) {
            $path = $script:paths[$key]
            Write-Host "  $key`:`t→ $path" -ForegroundColor Green
        }
    }
    else {
        Write-Warning "未定义任何路径跳转命令。"
    }
}