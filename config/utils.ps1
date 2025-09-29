function global:cat-git {
    Get-Content 'C:\Users\Lenovo\.gitconfig'
}

function global:ln {
    [CmdletBinding()]
    param(
        # ✅ 关键：去掉 Position，只能用 -s 调用
        [switch]$s,

        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Target,

        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Link
    )

    $ItemType = if ($s) { "SymbolicLink" } else { "HardLink" }

    try {
        if (Test-Path $Link) {
            $existingItem = Get-Item $Link -ErrorAction SilentlyContinue
            if ($existingItem.LinkType -eq "SymbolicLink") {
                Write-Warning "链接 '$Link' 已存在。"
                return
            }
            else {
                Write-Error "目标路径 '$Link' 已存在且不是链接，无法覆盖。"
                return
            }
        }

        if (-not (Test-Path $Target)) {
            Write-Error "目标 '$Target' 不存在，无法创建链接。"
            return
        }

        New-Item -ItemType $ItemType -Path $Link -Target $Target -ErrorAction Stop | Out-Null
        $linkTypeStr = if ($s) { "符号链接" } else { "硬链接" }
        Write-Host "$linkTypeStr 已创建: '$Link' -> '$Target'" -ForegroundColor Green
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "权限不足。请以管理员身份运行 PowerShell，或启用 '开发者模式'。"
    }
    catch {
        Write-Error "创建链接失败: $($_.Exception.Message)"
    }
}

function global:run {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    $configFile = Join-Path $PSScriptRoot "program.json"
    if (-not (Test-Path $configFile)) {
        Write-Warning "❌ 程序配置文件不存在: $configFile"
        return
    }

    try {
        $programs = Get-Content $configFile -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "❌ 无法解析 program.json: $($_.Exception.Message)"
        return
    }

    if (-not $programs.PSObject.Properties.Name.Contains($Name)) {
        Write-Warning "❌ 未找到程序别名: '$Name'"
        return
    }

    $programPath = $programs.$Name
    if (-not (Test-Path $programPath)) {
        Write-Warning "❌ 程序路径不存在: $programPath"
        return
    }

    # ✅ 直接使用 Start-Process（别名 start），无需判断扩展名
    Start-Process $programPath -ArgumentList $Args -WorkingDirectory (Split-Path $programPath) -Verb "Open"
}