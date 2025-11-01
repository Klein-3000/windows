function global:jb {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$ProjectName,

        [Alias('l')]
        [switch]$list,

        [Alias('n')]
        [int]$number,

        [Alias('on')]
        [int]$openNumber,

        [Alias('h')]
        [switch]$help
    )

    # ----------------------------
    # 帮助信息
    # ----------------------------
    if ($help) {
        Write-Host @"
用法: jb [选项] [<项目名>]

📌 管理 PyCharm 最近项目（依赖 JB_HOME 环境变量）

选项:
    jb                    启动 PyCharm
    jb <名>               打开指定项目
    jb -l                 [list] 列出所有最近项目（带序号）
    jb -n <序号>          [number] 通过序号打开项目
    jb -on <序号>         [open-number] 打开第N个项目的目录
    jb -h                 [help] 显示帮助

📌 必须设置环境变量 JB_HOME 指向 pycharm64.exe，例如：
    C:\Program Files\JetBrains\PyCharm 2024.2.1\bin\pycharm64.exe
    C:\Users\me\AppData\Local\JetBrains\Toolbox\apps\PyCharm-C\ch-0\242.20224.26\bin\pycharm64.exe

💡 设置方法（PowerShell）：
    # 临时设置（当前会话）
    `$env:JB_HOME = '你的完整路径\pycharm64.exe'

    # 永久设置（用户级别）
    [Environment]::SetEnvironmentVariable('JB_HOME', '你的完整路径\pycharm64.exe', 'User')

📌 设置后，重启 PowerShell 或运行：
    `$env:JB_HOME = [Environment]::GetEnvironmentVariable('JB_HOME', 'User')
"@ -ForegroundColor Cyan
        return
    }

    # ----------------------------
    # 🔒 强制检查 JB_HOME：必须指向 pycharm64.exe 文件
    # ----------------------------
    if (-not ($env:JB_HOME)) {
        Write-Error @"
❌ 未设置环境变量 JB_HOME

请设置 JB_HOME 指向 pycharm64.exe 可执行文件，例如：

👉 临时设置（当前会话）：
    `$env:JB_HOME = 'C:\Program Files\JetBrains\PyCharm 2024.2.1\bin\pycharm64.exe'

📌 永久设置（推荐）：
    [Environment]::SetEnvironmentVariable('JB_HOME', 'C:\Program Files\JetBrains\PyCharm 2024.2.1\bin\pycharm64.exe', 'User')

常见路径：
  • 安装版:     C:\Program Files\JetBrains\PyCharm <版本>\bin\pycharm64.exe
  • Toolbox:    C:\Users\<User>\AppData\Local\JetBrains\Toolbox\apps\PyCharm-<C|P>\ch-0\<版本>\bin\pycharm64.exe
  • 便携版:     你解压的任意位置\bin\pycharm64.exe

💡 设置后，重启 PowerShell 或运行：
    `$env:JB_HOME = [Environment]::GetEnvironmentVariable('JB_HOME', 'User')
"@
        return
    }

    $PyCharmExe = $env:JB_HOME

    if (-not (Test-Path $PyCharmExe -PathType Leaf)) {
        Write-Error "❌ JB_HOME 指向的路径无效或不是文件：`n    $PyCharmExe"
        return
    }

    if (-not ($PyCharmExe -like "*\pycharm64.exe")) {
        Write-Warning "⚠️  JB_HOME 指向的文件名不是 pycharm64.exe，确定是正确路径吗？"
    }

    # ----------------------------
    # 以下保持不变：解析 recentProjects.xml
    # ----------------------------
    $ConfigDirPattern = "$env:APPDATA\JetBrains\PyCharm*"
    $ConfigDirs = Get-ChildItem $ConfigDirPattern | Where-Object { $_.PSIsContainer } | Sort-Object Name -Descending

    if (-not $ConfigDirs) {
        Write-Error "❌ 未找到 PyCharm 配置目录。请确认 PyCharm 是否已运行过至少一次。"
        return
    }

    $OptionsDir = $ConfigDirs[0].FullName + "\options"
    $RecentProjectsXml = "$OptionsDir\recentProjects.xml"


    if (-not (Test-Path $RecentProjectsXml)) {
        Write-Error "❌ 未找到 recentProjects.xml: $RecentProjectsXml"
        Write-Host "💡 可能是 PyCharm 尚未打开过任何项目。" -ForegroundColor Yellow
        return
    }

    try {
        [xml]$xml = Get-Content $RecentProjectsXml
    }
    catch {
        Write-Error "❌ 读取或解析 recentProjects.xml 失败: $_"
        return
    }

    $projects = @()
    $index = 1

    # 新版本 PyCharm 使用 entry 的 key 属性存储项目路径
    $entryNodes = $xml.SelectNodes("//component[@name='RecentProjectsManager']//map/entry[@key]")

    if (-not $entryNodes) {
        Write-Error "❌ 未在 recentProjects.xml 中找到项目条目（<entry key='...' />）"
        return
    }

    foreach ($entry in $entryNodes) {
        $projectPath = $entry.GetAttribute("key")

        # 确保路径是本地路径（不是 file:// 或其他协议）
        if ($projectPath -like "file://*") {
            $projectPath = $projectPath -replace '^file:///', '' -replace '^file://', ''
        }
        $projectPath = $projectPath -replace '/', '\'

        if (-not (Test-Path $projectPath)) {
            Write-Warning "⚠️ 路径不存在，跳过: $projectPath"
            continue
        }

        $projectName = Split-Path $projectPath -Leaf
        $projects += [PSCustomObject]@{
            Number = $index
            Name   = $projectName
            Path   = $projectPath
        }
        $index++
    }


    if ($projects.Count -eq 0) {
        Write-Error "❌ 未找到有效的项目路径。"
        return
    }

    # ----------------------------
    # -l: 列出项目
    # ----------------------------
    if ($list) {
        $projects | Select-Object Number, Name, Path | Format-Table -AutoSize
        return
    }

    # ----------------------------
    # -on <n>: 打开第N个项目目录
    # ----------------------------
    if ($openNumber) {
        $target = $projects | Where-Object { $_.Number -eq $openNumber }
        if (-not $target) {
            Write-Error "❌ 无效序号: $openNumber"
            jb -l
            return
        }
        if (Test-Path $target.Path) {
            Invoke-Item $target.Path
            Write-Host "📁 已打开项目目录: $($target.Path)" -ForegroundColor Green
        } else {
            Write-Error "❌ 目录不存在: $($target.Path)"
        }
        return
    }

    # ----------------------------
    # -n <n>: 打开第N个项目
    # ----------------------------
    if ($number) {
        $target = $projects | Where-Object { $_.Number -eq $number }
        if (-not $target) {
            Write-Error "❌ 无效序号: $number"
            jb -l
            return
        }
        Start-Process $PyCharmExe -ArgumentList """$($target.Path)"""
        Write-Host "🚀 正在打开第 $number 个项目: '$($target.Name)'..." -ForegroundColor Cyan
        return
    }

    # ----------------------------
    # 默认行为
    # ----------------------------
    if (-not $ProjectName) {
        & $PyCharmExe
        Write-Host "👉 启动 PyCharm（默认）" -ForegroundColor Green
        return
    }

    $target = $projects | Where-Object { $_.Name -eq $ProjectName }
    if (-not $target) {
        Write-Error "❌ 未找到项目: '$ProjectName'"
        jb -l
        return
    }

    Start-Process $PyCharmExe -ArgumentList """$($target.Path)"""
    Write-Host "🚀 正在打开项目: '$($target.Name)'..." -ForegroundColor Cyan
}