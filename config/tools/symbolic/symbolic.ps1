# ===================================================================
#  symbolic - 类 Unix 软链接管理工具
#  用法: symbolic -s | -r | -p | -v | -h
# ===================================================================

# ✅ 使用 $PSScriptRoot 获取脚本所在目录（最可靠方式）
$scriptDir = $PSScriptRoot
$configFile = Join-Path $scriptDir "link.json"  # 支持你当前的 link.json

function symbolic {
    [CmdletBinding(DefaultParameterSetName='Print')]
    param(
        [Parameter(ParameterSetName='Setup')]    [switch]$s,  # setup
        [Parameter(ParameterSetName='Remove')]   [switch]$r,  # remove
        [Parameter(ParameterSetName='Print')]    [switch]$p,  # print status
        [Parameter(ParameterSetName='View')]     [switch]$v,  # view (preview)
        [Parameter(ParameterSetName='Help')]     [switch]$h   # help (new)
    )

    # ========== 新增：-h 显示帮助 ==========
    if ($h) {
        Write-Host @"
📖 symbolic - 软链接管理工具
用法: symbolic [-s|-r|-p|-v|-h]

  -s    setup     创建所有软链接
  -r    remove    删除所有软链接
  -p    print     打印当前链接状态
  -v    view      预览将要创建的链接（安全模式）
  -h    help      显示此帮助信息

配置文件: $configFile

💡 示例:
   symbolic -v    # 预览将创建哪些链接
   symbolic -s    # 实际创建（需管理员权限）
   symbolic -p    # 查看当前状态
   symbolic -r    # 删除所有链接
"@
        return
    }

    # ========== 读取配置文件 ==========
    if (-not (Test-Path $configFile)) {
        Write-Error "❌ 配置文件未找到: $configFile"
        Write-Host "💡 请确认文件存在且路径正确。" -ForegroundColor Yellow
        return
    }

    try {
        $links = Get-Content $configFile | ConvertFrom-Json
    }
    catch {
        Write-Error "❌ 配置文件解析失败: $_"
        return
    }

    # ========== 内部函数：解析路径中的 ~ 和 %ENV% ==========
    function Resolve-PathWithEnv {
        param([string]$path)
        $path = $path -replace '^~', $HOME
        if ($path -match '%(\w+)%') {
            $varName = $matches[1]
            $varValue = (Get-Item "env:$varName").Value
            $path = $path -replace "%$varName%", $varValue
        }
        return $path
    }

    # ========== 动作分发 ==========
    if ($p) {
        # 打印状态
        Write-Host "`n🔗 当前软链接状态：" -ForegroundColor Cyan
        foreach ($item in $links) {
            $linkPath = Resolve-PathWithEnv $item.link
            $exists = Test-Path $linkPath
            $status = $exists ? "✅" : "❌"
            $target = if ($exists) { (Get-Item $linkPath).Target } else { "" }
            Write-Host "$status $($item.link) -> $($item.target)"
            if ($target) { Write-Host "   ↳ Target: $target" -ForegroundColor Gray }
        }
    }
    elseif ($r) {
        # 删除所有链接
        if (-not $env:ADMIN_CHECKED) {
            $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if (-not $principal.IsInRole("Administrator")) {
                Write-Warning "⚠️ 删除软链接建议以管理员身份运行。"
            }
        }

        Write-Host "🗑️ 正在删除软链接 ..." -ForegroundColor Red
        foreach ($item in $links) {
            $linkPath = Resolve-PathWithEnv $item.link
            if (Test-Path $linkPath) {
                Remove-Item $linkPath -Force
                Write-Host "🗑️ 已删除: $($item.link)"
            }
        }
        Write-Host "✅ 所有软链接已删除。"
    }
    elseif ($s -or $v) {
        # 创建链接（$v 是预览）
        $whatIf = $v.IsPresent

        $adminRequired = $false
        foreach ($item in $links) {
            $linkPath = Resolve-PathWithEnv $item.link
            $targetPath = Resolve-PathWithEnv $item.target

            if (-not (Test-Path $targetPath)) {
                Write-Warning "⚠️ 目标路径不存在: $($item.target)"
                continue
            }

            if (-not (Test-Path $linkPath)) {
                $adminRequired = $true
                break
            }
        }

        if ($adminRequired -and -not $whatIf) {
            $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if (-not $principal.IsInRole("Administrator")) {
                Write-Warning "⚠️ 创建软链接需要管理员权限。请以管理员身份运行。"
                return
            }
        }

        Write-Host $("🔍 预览模式: " * $whatIf) + "正在处理软链接 ..." -ForegroundColor ($whatIf ? 'Yellow' : 'Cyan')

        foreach ($item in $links) {
            $linkPath = Resolve-PathWithEnv $item.link
            $targetPath = Resolve-PathWithEnv $item.target

            if (-not (Test-Path $targetPath)) {
                Write-Warning "⚠️ 跳过（目标不存在）: $($item.link) -> $($item.target)"
                continue
            }

            if (Test-Path $linkPath) {
                Write-Host "✅ 已存在: $($item.link)" -ForegroundColor Green
            }
            else {
                if ($whatIf) {
                    Write-Host "🔍 预览: 创建 $($item.link) → $($item.target)"
                }
                else {
                    try {
                        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -ErrorAction Stop | Out-Null
                        Write-Host "🔗 已创建: $($item.link) → $($item.target)" -ForegroundColor Cyan
                    }
                    catch {
                        Write-Error "❌ 创建失败: $($item.link) → $($item.target)`n$_"
                    }
                }
            }
        }

        if ($whatIf) {
            Write-Host "💡 运行 symbolic -s 以实际创建。" -ForegroundColor Yellow
        }
        else {
            Write-Host "🎉 所有软链接处理完成！" -ForegroundColor Green
        }
    }
    else {
        # 默认：显示帮助
        symbolic -h
    }
}
