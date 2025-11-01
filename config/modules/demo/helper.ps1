# config/modules/demo/helper.ps1
function global:Show-DemoFeature {
    param([string]$Feature)
    Write-Host "✨ 功能演示: $Feature" -ForegroundColor Magenta
}