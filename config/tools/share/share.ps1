# ===================================================================
#  share - SMB 共享管理工具 (终极可移植版)
# ===================================================================

function share {
    [CmdletBinding(DefaultParameterSetName='Show')]
    param(
        [Parameter(ParameterSetName='Show')]    [switch]$s,
        [Parameter(ParameterSetName='Enable')]  [switch]$e,
        [Parameter(ParameterSetName='Enable', ValueFromRemainingArguments)][string[]]$ShareName,
        [Parameter(ParameterSetName='Disable')] [switch]$d,
        [Parameter(ParameterSetName='Disable', ValueFromRemainingArguments)][string[]]$DisableName,
        [Parameter(ParameterSetName='Config')]  [switch]$c
    )

    # ✅ 极致健壮：获取当前函数定义所在的文件路径
    $scriptPath = $null

    # 方法1: 尝试从调用堆栈获取脚本路径
    $frame = Get-PSCallStack | Where-Object { $_.Command -eq 'share' -and $_.FunctionName -eq 'share' }
    if ($frame) {
        $scriptPath = Split-Path $frame.ScriptName -Parent
    }

    # 方法2: 回退到 MyInvocation
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.ScriptBlock.Module | ForEach-Object {
            if ($_.Path) { Split-Path $_.Path }
        }
        if (-not $scriptPath -and $MyInvocation.MyCommand.Path) {
            $scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
        }
    }

    # 方法3: 最终回退：假设在 config/tools/share/ 下
    if (-not $scriptPath) {
        # 相对于 $PROFILE 的标准路径
        $scriptPath = Join-Path $PSScriptRoot "config/tools/share"
        if (-not (Test-Path $scriptPath)) {
            $scriptPath = Join-Path $HOME "Documents/PowerShell/config/tools/share"
        }
    }

    $configFile = Join-Path $scriptPath "shares.json"

    # ========== 验证配置文件存在 ==========
    if (-not (Test-Path -LiteralPath $configFile)) {
        Write-Error "❌ 配置文件未找到: $configFile"
        Write-Host "💡 当前探测到的脚本目录: $scriptPath" -ForegroundColor Yellow
        Write-Host "💡 请确认 shares.json 存在于该目录。" -ForegroundColor Yellow
        return
    }

    try {
        $rawContent = Get-Content -Raw -Path $configFile
        $shares = $rawContent | ConvertFrom-Json
    }
    catch {
        Write-Error "❌ 配置文件解析失败: $($_.Exception.Message)"
        Write-Debug $rawContent
        return
    }

    # 确保 $shares 是数组
    if (-not $shares) { $shares = @() }
    elseif ($shares -isnot [Array]) { $shares = @($shares) }

    # ========== -c: 查看配置 ==========
    if ($c) {
        Write-Host "`n📄 shares.json 配置内容：" -ForegroundColor Cyan
        $shares | Format-Table -Property Name, Path, @{ Name="FullAccess"; Expression={ $_.FullAccess -join ',' } } | Out-String -Stream | ForEach-Object {
            if ($_ -match '\S') { Write-Host "  $_" -ForegroundColor Gray }
        }
        return
    }

    # ========== -s: 显示状态 ==========
    if ($s) {
        Write-Host "`n🔍 当前共享配置与状态：" -ForegroundColor Cyan
        $existingShares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.Name -in $shares.Name }

        $table = foreach ($item in $shares) {
            $exists = $existingShares | Where-Object Name -eq $item.Name
            [PSCustomObject]@{
                "共享名"     = $item.Name
                "共享路径"   = $item.Path
                "权限"       = $item.FullAccess -join ', '
                "状态"       = if ($exists) { "✅ 已共享" } else { "❌ 未共享" }
                "实际路径"   = $exists.Path
            }
        }

        $table | Format-Table -AutoSize | Out-String -Stream | ForEach-Object {
            if ($_ -match '\S') { Write-Host "  $_" -ForegroundColor White }
        }
        return
    }

    # ========== -e: 启用共享 ==========
    if ($e) {
        $targets = if ($ShareName) { $shares | Where-Object Name -in $ShareName } else { $shares }
        if (-not $targets) {
            Write-Warning "⚠️ 未找到指定的共享名: $($ShareName -join ', ')"
            return
        }

        Write-Host "🚀 正在启用共享 ..." -ForegroundColor Green
        foreach ($item in $targets) {
            $path = $item.Path
            $name = $item.Name
            $fullAccess = $item.FullAccess

            if (-not $path) {
                Write-Error "❌ 共享 '$name' 缺少路径配置"
                continue
            }

            if (-not (Test-Path -LiteralPath $path)) {
                Write-Warning "❌ 路径不存在，跳过: $path"
                continue
            }

            $existing = Get-SmbShare -Name $name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "✅ 已存在: \\$env:COMPUTERNAME\$name" -ForegroundColor Green
            }
            else {
                try {
                    New-SmbShare -Name $name -Path $path -FullAccess $fullAccess -ErrorAction Stop | Out-Null
                    Write-Host "🎉 已创建: \\$env:COMPUTERNAME\$name" -ForegroundColor Cyan
                    Write-Host "   → 路径: $path" -ForegroundColor Gray
                    Write-Host "   → 权限: $($fullAccess -join ', ')" -ForegroundColor Gray
                }
                catch {
                    Write-Error "❌ 创建失败 [$name]: $($_.Exception.Message)"
                }
            }
        }
        return
    }

    # ========== -d: 禁用共享 ==========
    if ($d) {
        $targets = if ($DisableName) { $shares | Where-Object Name -in $DisableName } else { $shares }
        if (-not $targets) {
            Write-Warning "⚠️ 未找到指定的共享名: $($DisableName -join ', ')"
            return
        }

        Write-Host "🛑 正在禁用共享 ..." -ForegroundColor Red
        foreach ($item in $targets) {
            $name = $item.Name
            $existing = Get-SmbShare -Name $name -ErrorAction SilentlyContinue

            if ($existing) {
                try {
                    Remove-SmbShare -Name $name -Force -ErrorAction Stop | Out-Null
                    Write-Host "🗑️ 已删除共享: \\$env:COMPUTERNAME\$name" -ForegroundColor Red
                }
                catch {
                    Write-Error "❌ 删除失败 [$name]: $($_.Exception.Message)"
                }
            }
            else {
                Write-Host "✅ 共享不存在，无需删除: $name" -ForegroundColor Gray
            }
        }
        return
    }

    # ========== 默认帮助 ==========
    Write-Host @"
📖 share - SMB 共享管理工具 (可移植版)

用法:
  share -s              # 查看共享状态
  share -e [name]       # 启用共享
  share -d [name]       # 禁用共享
  share -c              # 查看配置

配置文件: $configFile
探测路径: $scriptPath
"@
}
