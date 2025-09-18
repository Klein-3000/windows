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

# ========== 增强版 rreplace 函数 ==========
function global:rreplace {
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


function global:tree {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Path = ".",

        [int]$L = [int]::MaxValue,

        [int]$CurrentLevel = 0,

        [string]$Prefix = "",

        [bool]$IsLast = $true,

        [switch]$c,  # 显示统计信息 (dir:x; file:y)

        [switch]$h    # 显示帮助
    )

    if ($h) {
        Write-Host "`ntree v1.0 - 以树状结构显示目录内容`n" -ForegroundColor Cyan

        Write-Host "用法:" -ForegroundColor Yellow
        Write-Host "    tree [-Path <string>] [-L <int>] [-c] [-h]`n"

        Write-Host "参数:" -ForegroundColor Yellow
        Write-Host "    -Path <string)        " -NoNewline -ForegroundColor White
        Write-Host "要显示的路径（默认: 当前目录）"

        Write-Host "    -L <int>              " -NoNewline -ForegroundColor White
        Write-Host "最大显示深度（默认: 无限）"

        Write-Host "    -c                    " -NoNewline -ForegroundColor White
        Write-Host "显示每个目录的统计信息 (dir:x; file:y)"

        Write-Host "    -h, --help            " -NoNewline -ForegroundColor White
        Write-Host "显示此帮助信息并退出`n"

        Write-Host "示例:" -ForegroundColor Yellow
        Write-Host "    tree                  # 显示当前目录树"
        Write-Host "    tree -L 2             # 只显示两层深度"
        Write-Host "    tree -c               # 显示统计信息"
        Write-Host "    tree 'C:\Temp' -L 3   # 指定路径，深度3`n"

        return
    }
    # ✅ 互斥检查
    if ($d -and $f) {
        Write-Warning "参数 -d 和 -f 不能同时使用。请只选择其中一个，或都不使用以显示全部内容。"
        Write-Host "用法示例:" -ForegroundColor Yellow
        Write-Host "    save -d           # 仅显示目录"
        Write-Host "    save -f           # 仅显示文件"
        Write-Host "    save              # 显示所有" -ForegroundColor Gray
        return
    }

    $Item = Get-Item $Path -ErrorAction SilentlyContinue
    if (!$Item) { 
        return  # 路径无效，静默跳过
    }

    $Name = $Item.Name

    # 🔽 固定排除的系统/元数据目录（不包括 .gitignore 等文件）
    $ExcludedDirs = @('.git', '.svn', '.hg', 'node_modules', '__pycache__', 'Thumbs.db', 'desktop.ini')

    # 如果是被排除的目录，且不是根节点，则跳过
    if ($Item.PSIsContainer -and ($ExcludedDirs -contains $Name)) {
        if ($CurrentLevel -gt 0) {
            return  # 不显示，也不展开
        }
        # 根节点是 .git？不可能，但安全起见也跳过
        if ($ExcludedDirs -contains $Name) {
            Write-Warning "无法显示受保护目录: $Path"
            return
        }
    }

    # ========== 显示当前节点 ==========
    if ($CurrentLevel -gt 0) {
        $stats = ""
        if ($c -and $Item.PSIsContainer) {
            # 获取子项，并排除特殊目录
            $children = @(
                Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.PSIsContainer -or (-not $_.PSIsContainer -and $_.Name -notin $ExcludedDirs) } |
                Where-Object { $_.Name -notin $ExcludedDirs }
            )
            $dirs = @($children | Where-Object { $_.PSIsContainer }).Count
            $files = @($children | Where-Object { -not $_.PSIsContainer }).Count
            $stats = " (dir:$dirs; file:$files)"
        }

        $connector = if ($IsLast) { '└── ' } else { '├── ' }
        $color = if ($Item.PSIsContainer) { 'DarkCyan' } else { 'White' }

        Write-Host "$Prefix$connector$Name" -NoNewline -ForegroundColor $color
        if ($stats) {
            Write-Host "$stats" -ForegroundColor Green
        } else {
            Write-Host ""
        }
    }
    else {
        # 根节点
        $rootStats = ""
        if ($c) {
            $children = @(
                Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin $ExcludedDirs }
            )
            $dirs = @($children | Where-Object { $_.PSIsContainer }).Count
            $files = @($children | Where-Object { -not $_.PSIsContainer }).Count
            $rootStats = " (dir:$dirs; file:$files)"
        }

        Write-Host $Item.FullName -NoNewline
        if ($rootStats) {
            Write-Host "$rootStats" -ForegroundColor Green
        } else {
            Write-Host ""
        }
    }

    # 如果不是目录或已达到最大深度，停止
    if (!$Item.PSIsContainer -or $CurrentLevel -ge $L) {
        return
    }

    # 获取子项（排除特殊目录）
    $Children = @(
        Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $ExcludedDirs } |
        Sort-Object Name
    )
    $Total = $Children.Count

    for ($i = 0; $i -lt $Total; $i++) {
        $Child = $Children[$i]
        $IsLastChild = ($i -eq ($Total - 1))

        $NewPrefix = $IsLast ? "$Prefix    " : "$Prefix│   "

        # 递归调用（不再传 -f）
        tree -Path $Child.FullName -L $L -CurrentLevel ($CurrentLevel + 1) -Prefix $NewPrefix -IsLast $IsLastChild -c:$c
    }
}

function global:save {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Path = ".",

        [ValidateSet('Asc', 'Desc')]
        [string]$Order = 'Asc',

        [switch]$h,
        [switch]$d,
        [switch]$f,
        [switch]$T,
        [int]$Top,
        [string]$Filter
    )

    # ✅ 将 Format-FileSize 提前定义！
    function Format-FileSize($bytes) {
        if ($bytes -ge 1TB) { "{0:F1} TB" -f ($bytes / 1TB) }
        elseif ($bytes -ge 1GB) { "{0:F1} GB" -f ($bytes / 1GB) }
        elseif ($bytes -ge 1MB) { "{0:F1} MB" -f ($bytes / 1MB) }
        elseif ($bytes -ge 1KB) { "{0:F1} KB" -f ($bytes / 1KB) }
        else { "$bytes B" }
    }

    if ($h) {
        Write-Host "`nsave v1.2 - 文件/目录大小可视化工具`n" -ForegroundColor Cyan
        Write-Host "用法:" -ForegroundColor Yellow
        Write-Host "    save [-Path <路径>] [-Order Asc|Desc] [-d|-f] [-T] [-Top <n>] [-Filter <模式>] [-h]`n"
        Write-Host "参数:" -ForegroundColor Yellow
        Write-Host "    -Path      " -NoNewline; Write-Host "目标路径（默认: 当前目录）"
        Write-Host "    -Order     " -NoNewline; Write-Host "排序方式：Asc（小→大）, Desc（大→小）"
        Write-Host "    -d         " -NoNewline; Write-Host "仅显示子目录"
        Write-Host "    -f         " -NoNewline; Write-Host "仅显示文件"
        Write-Host "    -T         " -NoNewline; Write-Host "仅显示总大小"
        Write-Host "    -Top <n>   " -NoNewline; Write-Host "只显示前 n 个最大项（n > 0）"
        Write-Host "    -Filter    " -NoNewline; Write-Host "按名称过滤（支持 *.log, config*, ?.txt 等通配符）"
        Write-Host "    -h         " -NoNewline; Write-Host "显示帮助`n"
        Write-Host "示例:" -ForegroundColor Yellow
        Write-Host "    save -T                          # 显示当前目录总大小"
        Write-Host "    save -Top 5                     # 显示最大的 5 个项目"
        Write-Host "    save -Filter *.log              # 只显示 .log 文件"
        Write-Host "    save -d -Top 3 -Order Desc      # 最大的 3 个目录，降序"
        Write-Host "    save -f -Filter 'temp*'         # 所有以 temp 开头的文件"
        return
    }

    # 互斥检查：-d 和 -f 不能同时使用
    if ($d -and $f) {
        Write-Warning "参数 -d 和 -f 不能同时使用。请只选择其中一个，或都不使用以显示全部内容。"
        Write-Host "用法示例:" -ForegroundColor Yellow
        Write-Host "    save -d           # 仅显示目录"
        Write-Host "    save -f           # 仅显示文件"
        Write-Host "    save              # 显示所有" -ForegroundColor Gray
        return
    }

    # 获取目标路径下的所有项目（包含隐藏项）
    $items = Get-ChildItem $Path -Force -ErrorAction SilentlyContinue
    if (-not $items) {
        Write-Warning "未找到文件或路径无效: $Path"
        return
    }

    # 计算每个项目的大小
    $itemSizes = @()
    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            # 目录：累加所有文件大小
            $files = Get-ChildItem $item.FullName -File -Recurse -ErrorAction SilentlyContinue
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $size) { $size = 0 }
        } else {
            # 文件：直接取 Length
            $size = $item.Length
        }
        $itemSizes += [PSCustomObject]@{
            Name = $item.Name
            Size = $size
            IsDirectory = $item.PSIsContainer
        }
    }

    # 过滤：-d（仅目录）或 -f（仅文件）
    if ($d) {
        $itemSizes = $itemSizes | Where-Object { $_.IsDirectory }
        if (-not $itemSizes) {
            Write-Warning "当前目录下无子目录"
            return
        }
    }
    if ($f) {
        $itemSizes = $itemSizes | Where-Object { -not $_.IsDirectory }
        if (-not $itemSizes) {
            Write-Warning "当前目录下无文件"
            return
        }
    }

    # 过滤：-Filter（按名称匹配）
    if ($Filter) {
        $filtered = $itemSizes | Where-Object { $_.Name -like $Filter }
        if (-not $filtered) {
            Write-Warning "未找到匹配 '$Filter' 的项目"
            return
        }
        $itemSizes = $filtered
    }

    # 排序
    $Sorted = switch ($Order) {
        'Desc' { $itemSizes | Sort-Object Size -Descending }
        Default { $itemSizes | Sort-Object Size }
    }

    # ✅ -T：只显示总大小
    if ($T) {
        $total = ($Sorted | Measure-Object -Property Size -Sum).Sum
        $totalStr = Format-FileSize $total
        $pathDisplay = if ($Path -eq ".") { "当前目录" } else { "'$Path'" }
        Write-Host "`n📁 $pathDisplay 的总大小: " -NoNewline -ForegroundColor Cyan
        Write-Host "$totalStr" -ForegroundColor Green
        return
    }

    # ✅ -Top：只保留前 N 项
    if ($Top -gt 0) {
        $Sorted = $Sorted | Select-Object -First $Top
        if (-not $Sorted) {
            Write-Warning "没有符合条件的项目"
            return
        }
    }

    # 归一化用的最大值
    $MaxSize = ($Sorted | Measure-Object -Property Size -Maximum).Maximum
    if ($MaxSize -eq 0) { $MaxSize = 1 }

    # 获取终端宽度
    try {
        $Width = $Host.UI.RawUI.WindowSize.Width
    } catch { $Width = 80 }

    $BarLength = 20
    if ($Width -lt 60) { $BarLength = 10 }

    $NamePadding = $Width - 15 - $BarLength
    if ($NamePadding -lt 20) { $NamePadding = 20 }

    # 输出每一行
    foreach ($item in $Sorted) {
        $sizeStr = Format-FileSize $item.Size
        $pct = $item.Size / $MaxSize
        $fill = [Math]::Floor($pct * $BarLength)
        $bar = ('█' * $fill) + ('░' * ($BarLength - $fill))

        $name = $item.Name
        if ($name.Length -gt $NamePadding) {
            $cutLen = $NamePadding - 3
            if ($cutLen -le 0) { $name = "" } else {
                $name = "..." + $name.Substring($name.Length - $cutLen)
            }
        }
        $name = $name.PadRight($NamePadding)

        $leftPart = "{0,8}  {1}  " -f $sizeStr, $bar

        Write-Host -NoNewline -ForegroundColor White $leftPart
        if ($item.IsDirectory) {
            Write-Host -ForegroundColor Blue $name   # 目录：蓝色
        } else {
            Write-Host -ForegroundColor White $name  # 文件：白色
        }
    }
}