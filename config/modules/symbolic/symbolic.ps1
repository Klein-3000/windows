# ===================================================================
#  symbolic - 类 Unix 软链接管理工具（模块化版本）
#  用法: symbolic [-e|-d|-st|-p|-j|-h] [name]
# ===================================================================

# ✅ 使用 $PSScriptRoot 获取脚本所在目录
$scriptDir = $PSScriptRoot
$configFile = Join-Path $scriptDir "link.json"

function symbolic {
    [CmdletBinding(DefaultParameterSetName='Help')]
    param(
        [Parameter(ParameterSetName='Enable', Position=0)]
        [string]$Name,

        [Parameter(ParameterSetName='Enable')]
        [Alias('e')]
        [switch]$Enable,

        [Parameter(ParameterSetName='Disable', Position=0)]
        [string]$DisableName,

        [Parameter(ParameterSetName='Disable')]
        [Alias('d')]
        [switch]$Disable,

        [Parameter(ParameterSetName='Status')]
        [Alias('st')]
        [switch]$Status,

        [Parameter(ParameterSetName='Preview')]
        [Alias('p')]
        [switch]$Preview,

        [Parameter(ParameterSetName='Edit')]
        [Alias('j')]
        [switch]$Json,

        [Parameter(ParameterSetName='Help')]
        [Alias('h')]
        [switch]$Help
    )

    # ========== -h: 帮助 ==========
    if ($Help) {
        Write-Host @"
📖 symbolic - 软链接管理工具
用法: symbolic [选项] [名称]

选项:
  -e, -enable [名称]     启用链接（创建软链接），默认全部
  -d, -disable [名称]    禁用链接（删除软链接），默认全部
  -st, -status           打印当前链接状态
  -p, -preview          预览将创建的链接（不实际执行）
  -j, -json             编辑 link.json 配置文件
  -h, -help              显示此帮助信息

示例:
   symbolic -p                    # 预览所有链接
   symbolic -e                    # 创建所有链接
   symbolic -e nvim               # 仅创建名为 'nvim' 的链接
   symbolic -d                    # 删除所有链接
   symbolic -st                   # 查看状态
   symbolic -j                    # 编辑配置文件

配置文件: $configFile
"@
        return
    }

    # ========== -j: 编辑 JSON ==========
    if ($Json) {
        $editor = $env:EDITOR ?? "notepad"
        if (Test-Path $configFile) {
            & $editor $configFile
        } else {
            Write-Error "❌ 配置文件不存在: $configFile"
            Write-Host "💡 使用 `New-Item '$configFile' -Force` 创建空文件。" -ForegroundColor Yellow
        }
        return
    }

    # ========== 读取配置文件 ==========
    if (-not (Test-Path $configFile)) {
        Write-Error "❌ 配置文件未找到: $configFile"
        Write-Host "💡 请确认文件存在或使用 symbolic -j 创建。" -ForegroundColor Yellow
        return
    }

    try {
        $links = Get-Content $configFile | ConvertFrom-Json
        if ($null -eq $links -or $links.Count -eq 0) {
            Write-Warning "⚠️ 配置文件为空或格式错误。"
            return
        }
    }
    catch {
        Write-Error "❌ 配置文件解析失败: $_"
        return
    }

    # ========== 内部函数：解析路径变量 ==========
    function Resolve-PathWithEnv {
        param([string]$path)
        $path = $path -replace '^~', $HOME
        if ($path -match '%(\w+)%') {
            $varName = $matches[1]
            $varValue = (Get-Item "env:$varName" -ErrorAction Ignore)?.Value
            if ($varValue) {
                $path = $path -replace "%$varName%", $varValue
            }
        }
        return $path
    }

    # ========== 动作分发 ==========
    if ($Status) {
        Write-Host "`n🔗 当前软链接状态：" -ForegroundColor Cyan
        foreach ($item in $links) {
            $linkPath = Resolve-PathWithEnv $item.link
            $exists = Test-Path $linkPath
            $status = $exists ? "✅" : "❌"
            $target = if ($exists) { (Get-Item $linkPath).Target } else { "" }
            Write-Host "$status $($item.link)"
            if ($target) { Write-Host "   ↳ $target" -ForegroundColor Gray }
        }
    }
    elseif ($Preview) {
        Write-Host "🔍 预览模式: 将创建的软链接" -ForegroundColor Yellow
        foreach ($item in $links) {
            $linkPath = Resolve-PathWithEnv $item.link
            $targetPath = Resolve-PathWithEnv $item.target
            if (Test-Path $linkPath) {
                Write-Host "✅ 已存在: $($item.link)"
            } elseif (-not (Test-Path $targetPath)) {
                Write-Warning "⚠️ 目标不存在: $($item.target) ← $($item.link)"
            } else {
                Write-Host "🆕 将创建: $($item.link) → $($item.target)"
            }
        }
    }
    elseif ($Enable) {
        $targetLinks = $links
        if ($Name) {
            $targetLinks = $links | Where-Object { $_.name -eq $Name }
            if (-not $targetLinks) {
                Write-Error "❌ 未找到名为 '$Name' 的链接配置。"
                return
            }
        }

        $adminRequired = $targetLinks | Where-Object {
            $linkPath = Resolve-PathWithEnv $_.link
            -not (Test-Path $linkPath)
        }

        if ($adminRequired) {
            $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if (-not $principal.IsInRole("Administrator")) {
                Write-Warning "⚠️ 创建软链接需要管理员权限。"
                return
            }
        }

        Write-Host "🔗 正在创建软链接 ..." -ForegroundColor Cyan
        foreach ($item in $targetLinks) {
            $linkPath = Resolve-PathWithEnv $item.link
            $targetPath = Resolve-PathWithEnv $item.target

            if (-not (Test-Path $targetPath)) {
                Write-Warning "⚠️ 跳过（目标不存在）: $($item.link) → $($item.target)"
                continue
            }

            if (Test-Path $linkPath) {
                Write-Host "✅ 已存在: $($item.link)" -ForegroundColor Green
            } else {
                try {
                    New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -ErrorAction Stop | Out-Null
                    Write-Host "✅ 已创建: $($item.link) → $($item.target)" -ForegroundColor Green
                } catch {
                    Write-Error "❌ 创建失败: $($item.link)`n$_"
                }
            }
        }
        Write-Host "🎉 启用完成！" -ForegroundColor Green
    }
    elseif ($Disable) {
        $targetLinks = $links
        if ($DisableName) {
            $targetLinks = $links | Where-Object { $_.name -eq $DisableName }
            if (-not $targetLinks) {
                Write-Error "❌ 未找到名为 '$DisableName' 的链接配置。"
                return
            }
        }

        Write-Host "🗑️ 正在删除软链接 ..." -ForegroundColor Red
        foreach ($item in $targetLinks) {
            $linkPath = Resolve-PathWithEnv $item.link
            if (Test-Path $linkPath) {
                try {
                    Remove-Item $linkPath -Force -ErrorAction Stop
                    Write-Host "🗑️ 已删除: $($item.link)" -ForegroundColor Red
                } catch {
                    Write-Error "❌ 删除失败: $($item.link)`n$_"
                }
            } else {
                Write-Host "✅ 不存在: $($item.link)" -ForegroundColor Gray
            }
        }
        Write-Host "✅ 删除完成。"
    }
    else {
        # 默认：显示帮助
        symbolic -h
    }
}
# 导出函数（可选，用于模块化）
Export-ModuleMember -Function symbolic