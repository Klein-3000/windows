# 🚀 PowerShell 快速上手指南（模块化配置）
为提升命令行效率，本项目采用模块化方式对 PowerShell 配置进行重构，支持 **快速跳转、自定义命令、集中管理、易于维护**。

> ✅ 已支持：路径跳转、别名、导航、工具函数、Git 集成  
> 🔧 可扩展：任意新增模块（如 gitconfig、docker、python 等）

---

## 📁 项目结构
```powershell
$HOME\Documents\PowerShell\
├── Microsoft.PowerShell_profile.ps1    # 主配置文件
└── config/
    ├── paths.ps1           # 快速目录跳转
    ├── paths.default.json  # 默认路径定义
    ├── paths.user.json     # 用户自定义路径（优先级更高）
    ├── navigation.ps1      # 导航增强函数
    ├── aliases.ps1         # 别名定义
    ├── utils.ps1           # 工具函数
    └── *.ps1               # 其他自定义模块（如 gitconfig.ps1）
```
## 1️⃣ 快速目录跳转（如 `lenovo`, `linux`, `repo`）

### ✅ 功能说明

通过 `paths.ps1` 实现，支持：

| 特性         | 说明                                                              |
| ---------- | --------------------------------------------------------------- |
| 🔄 函数即命令   | `repo` 是一个函数，不是别名，可接收子目录参数                                      |
| 📁 子目录跳转   | `repo docs\myproj` → 跳转到 `D:\0repository\docs\myproj`           |
| 🗂 路径集中管理  | 所有路径定义在 `$script:paths` 哈希表中                                    |
| 🔍 查看所有命令  | 使用 `list-path` 显示所有可用跳转命令                                       |
| 🛠 用户自定义覆盖 | `paths.user.json` 优先于 `paths.default.json`                      |
| 💡 变量引用    | `${repo}` 获取路径字符串，可用于脚本                                         |
| ⌨️ Tab 补全  | `cd ${repo}\l` + `Tab` → `cd D:\0repository\linux` 支持子目录/文件自动补全 |
### 📝 示例命令
```powershell
repo                 # 跳转到 D:\0repository
repo docs\learning   # 跳转到 D:\0repository\docs\learning
lenovo .ssh          # 跳转到 C:\Users\Lenovo\.ssh
list-path            # 查看所有可用跳转命令

# 获取路径字符串(变量引用)
${repo}              # 输出: D:\0repository
ls ${repo}           # 列出 repo 目录内容
cd ${repo}\linux     # 进入子目录
```

> [!hint] tab 键补全 -- 提示
> 支持
> - 中文目录
> - 空格路径
> - 文件与目录区分显示
> - 所有使用 `-Path`, `-LiteralPath` 等参数的命令


### 🧩 路径配置文件

- `paths.default.json`：默认路径（建议不要修改）
- `paths.user.json`：用户自定义路径（可新增或覆盖）
```json
{
  "repo": "D:\\0repository",
  "gittest": "D:\\2-桌宠\\test",
  "dotfile": "D:\\0repository\\config\\.dotfile"
}
```
## 2️⃣  调试模式：可开关的调试输出（推荐）
为便于维护和排查问题，`paths.ps1` 支持 **无需修改代码的调试模式**。
### 🔧 开启调试
```powershell
$env:DEBUG_PATHS = "1"
. $PROFILE
```
输出示例:
```powershell
🔧 开始生成跳转函数...
  📌 repo → D:\0repository
  📌 linux → D:\0repository\linux
  ...
✅ 路径配置已加载（共 13 个命令）
```
### 🔇 关闭调试
```powershell
$env:DEBUG_PATHS = ""
. $PROFILE
```
> ✅ 调试信息完全由环境变量控制，不污染代码。

## 3️⃣ 自定义模块开发规范
### ✅ 正确做法

#### ✅ 原则 1：函数必须用 `global:` 声明
```powershell
# ❌ 错误：作用域内，外部无法调用
function open { ... }

# ✅ 正确：全局可用
function global:open { ... }
```
#### ✅ 原则 2：模块化加载必须在 `Import-Config` 之后

```powershell
Import-Config "paths"      # 必须最先加载，因为其他模块可能依赖 $script:paths
Import-Config "navigation" # 依赖 paths
Import-Config "aliases"
Import-Config "utils"
```
### ➕ 新增配置文件示例(如 `gitconfig.ps1`)
#### 步骤 1：创建文件
```powershell
New-Item D:\Users\Lenovo\Documents\PowerShell\config\gitconfig.ps1
```
#### 步骤 2：写入内容（记得加 `global:`）
```powershell
# $CONFIG_DIR\gitconfig.ps1

function global:cat-git {
    Get-Content $HOME\.gitconfig
}

function global:edit-git {
    notepad $HOME\.gitconfig
}
```
#### 步骤 3：在 `$PROFILE` 中加载
```powershell
# 在 $PROFILE 中一个"gitconfig.ps1"配置文件
# 必要
$config_files = @{
    paths      = "$CONFIG_DIR\paths.ps1"
    navigation = "$CONFIG_DIR\navigation.ps1"
    aliases    = "$CONFIG_DIR\aliases.ps1"
    utils      = "$CONFIG_DIR\utils.ps1"
    gitconfig  = "$CONFIG_DIR\gitconfig.ps1"  # 添加这一行
}

# 可选：创建简短别名（如果不想每次都打 $config_files.）
$aliases    = $config_files.aliases
$navigation = $config_files.navigation
$utils      = $config_files.utils
$gitconfig = $config_files.gitconfig # 为"gitconfig.ps1"配置类似于$profile的变量

# 加载顺序(必要)
Import-Config "paths"
Import-Config "navigation"
Import-Config "aliases"
Import-Config "utils"
Import-Config "gitconfig"  # 添加这一行
```
## 4️⃣ 调试与维护技巧

### 🔍 快速查看/编辑配置
```powershell
# 查看配置文件路径
$config_files.paths
$config_files.aliases

# 编辑配置文件
notepad $config_files.paths
code $config_files.utils  # 使用 VS Code

# 查看函数是否加载
Get-Command repo      # 应显示函数信息
Get-Command list-path

# 查看路径表
$script:paths
```
## 5️⃣ 推荐命名规范

|类型|建议命名|示例|
|---|---|---|
|配置文件变量|`$config_files.xxx`|`$config_files.aliases`|
|全局函数|`global:funcName`|`global:open`, `global:list-path`|
|全局哈希表|`$script:jump_paths`|避免与系统变量冲突|
|自定义模块|`xxx.ps1`|`gitconfig.ps1`, `docker.ps1`|

## ✅ 调试技巧：快速查看(==$config_files.ConfigName==)/编辑配置
```powershell
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
# 自定命令和函数
## 1. run函数
主要文件==config/program.json==, 在该文档中,配置脚本,程序的路径,并设置别名。即可通过`run <别名>`启动对应的脚本,程序
### 示例
```powershell
# config/program.json
{
  "lanset": "D:\\2-桌宠\\0-lanlan.full.v0.3.1\\lanlan\\启动设置页.bat",
  "mate": "D:\\2-桌宠\\0-Public.Release.1.6.2\\MateEngineX.exe"
}
```
执行脚本或启动程序
```powershell
# 启动"mate"对应的程序
run mate
```

## 2. 🎯 `r` 命令总结：PowerShell 高效操作神器

> 基于 `rreplace` 函数 + 模块化配置，实现类 Unix 历史命令智能替换

---

### ✅ 基本功能：四大模式

|命令|功能|示例|结果|
|---|---|---|---|
|`r`|重复上一条非 `r` 命令|`ls ./home` → `r`|再次执行 `ls ./home`|
|`r -s <old> <new>`|全文文本替换|`ls ./home` → `r -s home repo`|`ls ./repo`|
|`r -l <new>`|替换最后一个参数|`ls ./home` → `r -l ./docs`|`ls ./docs`|
|`r -f <new>`|替换命令，保留参数|`ls ./home` → `r -f dir`|`dir ./home`|

> 💡 支持组合：`r -sl old new` = `-s -l`，`r -sf new` = `-s -f`

---

### 🔁 连续使用 `r` 的行为（关键！）

- `r` **不会递归到最原始的命令**
- 它的操作对象是：**“上一条以 `r` 执行出的真实命令”**
- 即：`Get-History` 中，从后往前，第一个 **不以 `r` 开头** 的命令
示例
```bash
1. ls ./home 
2. r -l mydocs → 执行: ls ./home 
3. r -l myVideos → 操作对象是: ls ./home → 执行: ls ./myVideos 
4. r -f dir → 操作对象是: ls ./home → 执行: dir ./home
```

### ⚠️ 注意事项（Important!）

| 问题                          | 说明                                    | 建议                                                            |
| --------------------------- | ------------------------------------- | ------------------------------------------------------------- |
| **`r` 被覆盖**                 | PowerShell 内建 `r` 是 `Get-History` 的别名 | 必须在配置中 `Remove-Item Alias:\r` 并 `Set-Alias r rreplace -Force` |
| **作用域问题**                   | `Set-Alias` 需在全局作用域生效                 | 使用 `-Scope Global`                                            |
| **加载顺序**                    | `rreplace` 函数必须先定义，再设置别名              | 确保函数在 `Set-Alias` 之前                                          |
| **复杂命令支持**                  | 仅按空格拆分，不解析引号、管道、转义符                   | 适用于简单命令，复杂场景慎用                                                |
| **`Invoke-Expression` 安全性** | 执行动态生成的命令                             | 确保你信任历史命令内容                                                   |
| **无参数时行为**                  | `r` 直接重复上一条非 `r` 命令                   | 不会无限递归                                                        |