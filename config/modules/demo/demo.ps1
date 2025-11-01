# config/modules/demo/demo.ps1

# 1. 加载配置
$ConfigPath = Join-Path $PSScriptRoot "config.json"
if (Test-Path $ConfigPath) {
    $script:DemoConfig = Get-Content $ConfigPath | ConvertFrom-Json
} else {
    Write-Warning "⚠️ demo 配置文件未找到: $ConfigPath"
    return
}

# 2. 加载辅助函数
. (Join-Path $PSScriptRoot "helper.ps1")

# 3. 定义主命令
function global:demo {
    param(
        [switch]$List,
        [switch]$Info
    )

    if ($Info) {
        Write-Host "📦 demo 模块信息:" -ForegroundColor Cyan
        Write-Host "   版本: $($script:DemoConfig.version)"
        Write-Host "   作者: $($script:DemoConfig.author)"
        return
    }

    if ($List) {
        Write-Host $script:DemoConfig.greeting -ForegroundColor Green
        Write-Host "可用功能:" -ForegroundColor Yellow
        $script:DemoConfig.features | ForEach-Object {
            Show-DemoFeature $_
        }
        return
    }

    Write-Host "🎯 运行 demo 模块" -ForegroundColor Green
    Write-Host "输入 'demo -List' 或 'demo -Info' 查看更多" -ForegroundColor Gray
}