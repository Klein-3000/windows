# config/tools/demo.ps1
# 懒加载入口：只在首次调用时加载模块

if (request "module:demo") {
    Write-ConfigStatus "✅ demo 模块已加载" -Color Green
}