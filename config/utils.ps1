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