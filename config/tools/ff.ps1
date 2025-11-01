function global:ff {
    [CmdletBinding()]
    param(
        [string]$name,
        [switch]$list,
        [switch]$help,
        [int]$width = 30,
        [int]$paddingTop = 1
    )

    $logoDir = "$env:USERPROFILE\.config\fastfetch\logos"
    $imageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff', '.webp')

    if (-not (Get-Command "fastfetch" -ErrorAction SilentlyContinue)) {
        Write-Error "Fastfetch 未安装或不可用。"
        return
    }

    if ($help) {
        Get-Help ff -Full
        return
    }

    if ($list) {
        Write-Verbose "正在列出可用的 logo 图片..."
        if (Test-Path $logoDir) {
            Get-ChildItem -Path $logoDir | Where-Object {
                $imageExtensions -contains $_.Extension.ToLower()
            } | ForEach-Object {
                Write-Host "  $($_.Name)"
            }
        } else {
            Write-Error "Logo 目录不存在: $logoDir"
        }
        return
    }

    if (-not (Test-Path $logoDir)) {
        Write-Error "Logo 目录不存在: $logoDir"
        return
    }

    $images = Get-ChildItem -Path $logoDir | Where-Object {
        $imageExtensions -contains $_.Extension.ToLower()
    }

    if ($images.Count -eq 0) {
        Write-Error "在 $logoDir 中未找到支持的图片文件。"
        return
    }

    if ($name) {
        $targetImage = $images | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $targetImage) {
            Write-Error "未找到指定的图片: $name"
            Write-Host "可用图片:" -ForegroundColor Yellow
            $images | ForEach-Object { Write-Host "  $($_.Name)" }
            return
        }
        $imagePath = $targetImage.FullName
    } else {
        $randomImage = Get-Random -InputObject $images
        $imagePath = $randomImage.FullName
    }

    Write-Verbose "使用图片 $imagePath 作为 logo。"
    fastfetch --iterm "$imagePath" --logo-width $width --logo-padding-top $paddingTop --logo-padding-left 5
}
