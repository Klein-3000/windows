function global:vs {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$FolderName,

        [Alias('s')]
        [switch]$show,

        [Alias('j')]
        [switch]$json,

        [Alias('o')]
        [string]$open,

        [Alias('on')]
        [int]$openNumber,

        [Alias('n')]
        [int]$number,

        [Alias('h')]
        [switch]$help,

        [Alias('p')]
        [string]$pin,

        [Alias('u')]
        [string]$unpin,

        [Alias('r')]
        [switch]$resetOrder
    )

    $ConfigFile = "$env:APPDATA\Code\User\globalStorage\state.vscdb" # 注意：实际是 SQLite DB，但 VS Code 也使用其他 JSON 文件
    # 实际上，最近打开的文件夹信息主要存储在：
    $StorageJson = "$env:APPDATA\Code\User\globalStorage\storage.json"

    # ----------------------------
    # 查找 code 命令或 VS Code 可执行文件
    # ----------------------------
    $CodeExe = Get-Command 'code' -ErrorAction SilentlyContinue
    if (-not $CodeExe) {
        # 尝试常见安装路径
        $PossiblePaths = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe"
            "$env:PROGRAMFILES\Microsoft VS Code\Code.exe"
            "$env:PROGRAMFILES\Microsoft VS Code Insiders\Code - Insiders.exe"
            "$env:PROGRAMFILES (x86)\Microsoft VS Code\Code.exe"
        )
        foreach ($path in $PossiblePaths) {
            if (Test-Path $path) {
                $CodeExe = $path
                break
            }
        }
    }
    else {
        $CodeExe = $CodeExe.Source
    }

    if (-not $CodeExe -or -not (Test-Path $CodeExe)) {
        Write-Error @"
❌ 未找到 VS Code 可执行文件。

请确保已安装 VS Code，并将其 'code' 命令添加到 PATH 环境变量。
常见安装路径：
  • $env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe
  • $env:PROGRAMFILES\Microsoft VS Code\Code.exe
"@
        return
    }

    # ----------------------------
    # Help
    # ----------------------------
    if ($help) {
        Write-Host @"
用法: vs [选项] [<文件夹名>]

📌 管理 VS Code 最近打开的文件夹

选项:
    vs                    启动 VS Code
    vs <名>               打开指定文件夹
    vs -s                 [show] 显示所有最近打开的文件夹（带序号）
    vs -j                 [json] 输出 storage.json 内容
    vs -o <名>            [open] 打开文件夹所在目录
    vs -on <序号>         [open-number] 打开第N个文件夹的目录
    vs -n <序号>          [number] 打开第N个最近的文件夹
    vs -p <名>            [pin] 功能预留（VS Code 无原生置顶）
    vs -u <名>            [unpin] 功能预留
    vs -r                 [reset] 功能预留（清空最近列表需手动）
    vs -h                 [help] 显示帮助

示例:
    vs -s
    vs -o myproject
    vs -n 3
    vs mylife
"@
        return
    }

    if (-not (Test-Path $StorageJson)) {
        Write-Error "❌ 配置文件不存在: $StorageJson`nVS Code 可能尚未运行或路径不正确。"
        return
    }

    try {
        $storage = Get-Content $StorageJson | ConvertFrom-Json -Depth 10
    }
    catch {
        Write-Error "❌ 解析 JSON 失败: $_"
        return
    }

    # 提取最近打开的文件夹
    $workspaces = @()
    if ($storage.profileAssociations -and $storage.profileAssociations.workspaces) {
        $workspaces = $storage.profileAssociations.workspaces.PSObject.Properties | Where-Object {
            $_.Value -eq "__default__profile__" -and
            $_.Name -like "file:///*"
        } | ForEach-Object {
            $decodedPath = [System.Uri]::UnescapeDataString($_.Name)
            $localPath = $decodedPath -replace '^file:///([a-zA-Z])%3A/', 'D:\'  # 修复 D: 盘符
            $localPath = $localPath -replace '^file:///', ''
            $folderName = Split-Path $localPath -Leaf
            [PSCustomObject]@{
                Name = $folderName
                Path = $localPath
                Uri  = $_.Name
            }
        }
    }

    # 构建有序列表
    $folderList = @()
    $index = 1
    foreach ($ws in $workspaces) {
        $folderList += [PSCustomObject]@{ Number = $index; Name = $ws.Name; Path = $ws.Path; Uri = $ws.Uri }
        $index++
    }

    # ----------------------------
    # 功能: -json
    # ----------------------------
    if ($json) {
        Write-Host "📄 当前 storage.json 内容：" -ForegroundColor Green
        Get-Content $StorageJson | Write-Host -ForegroundColor Gray
        return
    }

    # ----------------------------
    # 功能: -show
    # ----------------------------
    if ($show) {
        if ($folderList.Count -eq 0) {
            Write-Host "📭 未找到最近打开的文件夹。" -ForegroundColor Yellow
        }
        else {
            $folderList | Select-Object Number, Name, Path | Format-Table -AutoSize
        }
        return
    }

    # ----------------------------
    # 功能: -open (打开目录)
    # ----------------------------
    if ($open) {
        $target = $folderList | Where-Object { $_.Name -eq $open }
        if (-not $target) {
            Write-Error "❌ 未找到文件夹: '$open'"
            vs -s
            return
        }
        $dir = $target.Path
        if (Test-Path $dir) {
            Invoke-Item $dir
            Write-Host "📁 已打开目录: $dir" -ForegroundColor Green
        } else {
            Write-Error "❌ 目录不存在: $dir"
        }
        return
    }

    # ----------------------------
    # 功能: -openNumber (打开第N个目录)
    # ----------------------------
    if ($openNumber) {
        $target = $folderList | Where-Object { $_.Number -eq $openNumber }
        if (-not $target) {
            Write-Error "❌ 无效序号: $openNumber"
            vs -s
            return
        }
        $dir = $target.Path
        if (Test-Path $dir) {
            Invoke-Item $dir
            Write-Host "📁 已打开第 $openNumber 个目录: $dir" -ForegroundColor Green
        } else {
            Write-Error "❌ 目录不存在: $dir"
        }
        return
    }

    # ----------------------------
    # ✅ 新增功能: -number (打开第N个文件夹)
    # ----------------------------
    if ($number) {
        $target = $folderList | Where-Object { $_.Number -eq $number }
        if (-not $target) {
            Write-Error "❌ 无效序号: $number"
            vs -s
            return
        }

        & $CodeExe $target.Path
        Write-Host "🚀 正在用 VS Code 打开第 $number 个文件夹: '$($target.Name)'..." -ForegroundColor Cyan
        return
    }

    # ----------------------------
    # 预留功能: -pin / -unpin / -reset
    # ----------------------------
    if ($pin) {
        Write-Warning "📌 VS Code 本身不支持‘置顶’功能，此命令为预留。"
        return
    }
    if ($unpin) {
        Write-Warning "🗑️ VS Code 本身不支持‘置顶’功能，此命令为预留。"
        return
    }
    if ($reset) {
        Write-Warning "🔄 清空最近打开列表需在 VS Code 设置中操作，或手动编辑 storage.json。"
        return
    }

    # ----------------------------
    # 默认行为：启动或打开指定文件夹
    # ----------------------------
    if (-not $FolderName) {
        & $CodeExe
        Write-Host "👉 启动 VS Code" -ForegroundColor Green
        return
    }

    $target = $folderList | Where-Object { $_.Name -eq $FolderName }
    if (-not $target) {
        Write-Error "❌ 未找到文件夹: '$FolderName'"
        vs -s
        return
    }

    & $CodeExe $target.Path
    Write-Host "🚀 正在用 VS Code 打开 '$($target.Name)'..." -ForegroundColor Cyan
}
