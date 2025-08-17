# ===================================================================
#  paths.ps1 - 路径跳转函数生成器
#  ✅ 支持用户自定义覆盖默认路径
#  🔧 调试开关：通过 $env:DEBUG_PATHS 控制
#     开启：$env:DEBUG_PATHS=1; . $PROFILE
#     关闭：$env:DEBUG_PATHS=''; . $PROFILE
# ===================================================================

# 🔧 使用环境变量控制调试输出（跨作用域，外部可设置）
$DEBUG_PATHS = ($env:DEBUG_PATHS -eq "1") -or ($env:DEBUG_PATHS -eq "true")

$CONFIG_DIR = $PSScriptRoot
$defaultFile = Join-Path $CONFIG_DIR "paths.default.json"
$userFile    = Join-Path $CONFIG_DIR "paths.user.json"

# 如果用户配置不存在，自动创建
if (-not (Test-Path $userFile)) {
    Write-Host "🆕 首次运行：创建用户配置文件 $userFile" -ForegroundColor Yellow
    if (Test-Path $defaultFile) {
        Copy-Item $defaultFile $userFile
        Write-Host "✅ 已生成用户配置，请根据需要修改 $userFile" -ForegroundColor Green
    }
    else {
        Write-Error "❌ 错误：未找到默认配置文件 $defaultFile"
        return
    }
}

# 读取默认配置
try {
    $defaultPaths = Get-Content $defaultFile | ConvertFrom-Json -AsHashtable
}
catch {
    Write-Error "❌ 解析 default.json 失败: $_"
    return
}

# 读取用户配置
try {
    $userPaths = Get-Content $userFile | ConvertFrom-Json -AsHashtable
}
catch {
    Write-Error "❌ 解析 user.json 失败: $_"
    return
}

# 合并路径：用户 > 默认，支持 user.json 中新增的键
$script:paths = @{}
$allKeys = ($defaultPaths.Keys + $userPaths.Keys) | Sort-Object -Unique

foreach ($key in $allKeys) {
    $finalPath = $userPaths[$key]
    if ([string]::IsNullOrWhiteSpace($finalPath)) {
        $finalPath = $defaultPaths[$key]
    }

    if (-not [string]::IsNullOrWhiteSpace($finalPath)) {
        # 替换 $home 变量
        $finalPath = $finalPath -replace '\$home', $HOME
        $script:paths[$key] = $finalPath.Trim()
    }
    else {
        if ($DEBUG_PATHS) {
            Write-Warning "⚠️ 忽略空路径: [$key]"
        }
    }
}

# 清理旧的跳转函数（避免重复定义）
if (Get-PSDrive -Name Function -ErrorAction SilentlyContinue) {
    Get-ChildItem Function:\ | Where-Object {
        $_.ModuleName -eq $null -and $script:paths.ContainsKey($_.Name)
    } | Remove-Item -ErrorAction SilentlyContinue
}

# 🔧 条件性输出：开始生成函数
if ($DEBUG_PATHS) {
    Write-Host "`n🔧 开始生成跳转函数..." -ForegroundColor Magenta
}

# 为每个路径生成全局函数
foreach ($key in $script:paths.Keys) {
    $root = $script:paths[$key]
    $rootDisplay = if ([string]::IsNullOrWhiteSpace($root)) { "<空>" } else { $root }

    if ($DEBUG_PATHS) {
        Write-Host "  📌 $key`:`t→ $rootDisplay" -ForegroundColor Gray
    }

    # ✅ 修复：在闭包中捕获当前 $key 和 $script:paths 的副本
    $currentKey = $key
    $currentPaths = $script:paths  # 捕获当前哈希表

    $functionBody = {
        param([string]$SubPath = '')

        # 使用捕获的变量，而不是运行时查找 $script:paths
        $root = $currentPaths[$currentKey]

        if (-not $root) {
            Write-Error "❌ 路径 '$currentKey' 未定义或为空"
            return
        }

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

        $normalized = $SubPath -replace '[\\/]', '\\'
        $target = Join-Path $root $normalized

        if (Test-Path $target -PathType Container) {
            Set-Location $target
        }
        else {
            Write-Error "目录不存在或不是文件夹: $target"
        }
    }.GetNewClosure()

    New-Item -Path "Function:\global:$key" -Value $functionBody -Force | Out-Null
}

function global:list-path {
    if (-not $script:paths) {
        Write-Warning "❌ 路径表未定义。"
        return
    }

    if ($script:paths.Count -eq 0) {
        Write-Warning "未定义任何路径跳转命令。"
        return
    }

    Write-Host "`n🎯 当前可用快速跳转命令：" -ForegroundColor Cyan
    foreach ($key in $script:paths.Keys | Sort-Object) {
        $path = $script:paths[$key]
        $pathDisplay = if ([string]::IsNullOrWhiteSpace($path)) { "<空>" } else { $path }
        Write-Host "  $key`:`t→ $pathDisplay" -ForegroundColor Green
    }
}

# 最终提示
Write-Host "✅ 路径配置已加载（共 $($script:paths.Count) 个命令）" -ForegroundColor Green