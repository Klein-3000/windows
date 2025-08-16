# 🚀 PowerShell 快速上手指南（模块化配置）
## 1️⃣ 快速目录切换（如 `lenovo`、`linux`）

### ✅ 功能说明(相关文件==paths.ps1==)
```pwsh
lenovo → cd C:\Users\Lenovo 
linux → cd D:\0repository\linux 
desktop → cd D:\Users\Lenovo\Desktop 
list-path → 查看所有可用命令
```
### 🔥 核心特点

| 特性          | 说明                                                           |
| ----------- | ------------------------------------------------------------ |
| **函数即命令**   | `lenovo` 是一个函数，不是别名，支持参数                                     |
| **支持子目录跳转** | `linux docs\myproj` → 跳转到 `D:\0repository\linux\docs\myproj` |
| **路径集中管理**  | 所有路径定义在 `$script:paths` 哈希表中                                 |
| **自动列出**    | `list-path` 显示所有可用跳转命令                                       |
## 2️⃣ 日后自定义配置：注意事项（避免 `utils.ps1` 加载失败）

### ✅ 正确做法

#### ✅ 原则 1：函数必须用 `global:` 声明

❌ 错误：
```pwsh
function open { ... } # 作用域内，外部用不了
```
✅ 正确：
```pwsh
function global:open { ... } # 全局可用
```
#### ✅ 原则 2：模块化加载必须在 `Import-Config` 之后

你的结构是：
```pwsh
Import-Config "paths"      # 必须最先加载，因为其他模块可能依赖 $script:paths
Import-Config "navigation" # 依赖 paths
Import-Config "aliases"
Import-Config "utils"
```
## ✅ 新增配置文件的步骤（如 `gitconfig.ps1`）

### 步骤 1：创建文件
```pwsh
New-Item D:\Users\Lenovo\Documents\PowerShell\config\gitconfig.ps1
```
### 步骤 2：写入内容（记得加 `global:`）
```pwsh
# D:\Users\Lenovo\Documents\PowerShell\config\gitconfig.ps1

function global:cat-git {
    Get-Content $HOME\.gitconfig
}

function global:edit-git {
    notepad $HOME\.gitconfig
}
```
### 步骤 3：在 `$PROFILE` 中加载
```pwsh
# 在 $PROFILE 中添加
$config_files = @{
    ...
    gitconfig = Join-Path $CONFIG_DIR "gitconfig.ps1"
}

# 在 Import-Config 调用中添加
Import-Config "gitconfig"
```
## ✅ 调试技巧：快速查看(==$config_files.ConfigName==)/编辑配置
```pwsh
# 查看配置文件内容
$config_files.paths
$config_files.navigation

# 编辑配置文件
notepad $config_files.aliases
code $config_files.utils  # 如果你用 VS Code

# 查看变量是否加载
Get-Command lenovo   # 看函数是否存在
$script:paths        # 看路径表是否正确
```
## ✅ 推荐命名规范
|类型|建议命名|
|---|---|
|配置文件路径变量|`$config_files.aliases`|
|全局函数|`global:open`, `global:list-path`|
|全局哈希表|`$script:jump_paths`（避免 `$script:paths`）|
|自定义模块|`xxx.ps1` 放在 `config\` 目录|