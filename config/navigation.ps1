# ===================================================================
#  快速返回上级目录
# ===================================================================
function global:..    { Set-Location .. }
function global:...   { Set-Location ..\.. }
function global:....  { Set-Location ..\..\.. }

# ===================================================================
#  智能打开：open 命令
# ===================================================================
function global:open {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    # === 1. 检测是否为 URL ===
    $urlPattern = '^(https?://|www\.)|(\w+\.\w+)'
    $sanitizedTarget = $Target.Trim()

    if ($sanitizedTarget -match $urlPattern) {
        $url = $sanitizedTarget
        if ($url -like "www.*")      { $url = "https://" + $url }
        elseif ($url -notlike "http*"){ $url = "https://" + $url }

        try {
            $uri = [uri]$url
            if ($uri.Scheme -in @('http', 'https')) {
                $choice = Read-Host @"
🌐 即将打开网页：
    $url

是否在默认浏览器中打开？[Y/n]
"@
                if ($choice -notmatch '^[Yy]$|^$') {
                    Write-Host "操作已取消。" -ForegroundColor Yellow
                    return
                }
                Start-Process $url
                return
            }
        }
        catch { }
    }

    # === 2. 打开当前目录 ===
    if ($Target -eq '.') {
        explorer $PWD
        return
    }

    # === 3. 解析路径：优先从 $script:paths 查找 ===
    $path = $script:paths.ContainsKey($Target) ? $script:paths[$Target] : $Target

    # === 4. 网络路径安全警告 ===
    if ($path -like "\\*") {
        $choice = Read-Host @"
⚠️  即将打开一个网络位置：
    $path

网络共享可能包含恶意文件或窃取凭据。
仅在你信任该设备和网络时继续。

是否继续打开？[y/N]
"@
        if ($choice -notmatch '^[Yy]$') {
            Write-Host "操作已取消。" -ForegroundColor Yellow
            return
        }
        explorer $path
        return
    }

    # === 5. 检查本地路径存在性 ===
    if (-not (Test-Path $path)) {
        Write-Error "路径或文件不存在: $path"
        return
    }

    # === 6. 判断类型并打开 ===
    $item = Get-Item $path
    if ($item.PSIsContainer) {
        explorer $item.FullName
    }
    else {
        $ext = $item.Extension.ToLower()
        $executables = @('.exe', '.msi', '.bat', '.cmd', '.ps1', '.vbs', '.scr', '.pif', '.lnk')

        if ($executables -contains $ext) {
            $choice = Read-Host @"
⚠️  检测到可执行文件: $($item.Name)

此类文件可能包含病毒或恶意程序。
仅在你完全信任来源时运行。

是否继续打开？[Y/n]
"@
            if ($choice -notmatch '^[Yy]$|^$') {
                Write-Host "操作已取消。" -ForegroundColor Yellow
                return
            }
        }
        Invoke-Item $item.FullName
    }
}