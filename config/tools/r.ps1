# ========== 增强版 rreplace 函数 ==========
function rreplace {
    [CmdletBinding(DefaultParameterSetName="Repeat")]
    param(
        [Parameter(ParameterSetName="ReplaceText")]
        [Alias('s')]
        [switch]$Replace,

        [Parameter(Position=0, ParameterSetName="ReplaceText")]
        [string]$Old,

        [Parameter(Position=1, ParameterSetName="ReplaceText")]
        [string]$New,

        [Parameter(Mandatory, Position=0, ParameterSetName="ReplaceLast")]
        [Alias('l')]
        [string]$Last,

        [Parameter(Mandatory, Position=0, ParameterSetName="ReplaceCommand")]
        [Alias('f')]
        [string]$Command
    )

    $history = Get-History | Where-Object { $_.CommandLine -notmatch '^\s*r(\s.*)?$' }
    if (-not $history) {
        Write-Warning "没有找到可执行的历史命令。"
        return
    }

    $lastCmd = $history[-1].CommandLine
    $parts = $lastCmd -split ' ', 2
    $cmd = $parts[0]
    $argsStr = if ($parts.Count -eq 2) { $parts[1] } else { '' }

    switch ($PSCmdlet.ParameterSetName) {
        "Repeat" {
            Write-Host "执行: $lastCmd" -ForegroundColor Green
            Invoke-Expression $lastCmd
            return
        }

        "ReplaceText" {
            if ([string]::IsNullOrWhiteSpace($Old)) {
                Write-Warning "请提供要替换的文本。"
                return
            }
            $newCmd = $lastCmd -replace [regex]::Escape($Old), $New
        }

        "ReplaceLast" {
            if ([string]::IsNullOrWhiteSpace($argsStr)) {
                $newCmd = "$cmd $Last"
            } else {
                $argList = $argsStr -split ' '
                $argList[-1] = $Last
                $newCmd = "$cmd " + ($argList -join ' ')
            }
        }

        "ReplaceCommand" {
            if ([string]::IsNullOrWhiteSpace($argsStr)) {
                $newCmd = $Command
            } else {
                $newCmd = "$Command $argsStr"
            }
        }
    }

    Write-Host "原命令: $lastCmd" -ForegroundColor Gray
    Write-Host "新命令: $newCmd" -ForegroundColor Green
    Invoke-Expression $newCmd
}

# 覆盖原生 r 别名
Remove-Item Alias:\r -ErrorAction SilentlyContinue
Set-Alias -Name r -Value rreplace -Scope Global -Force