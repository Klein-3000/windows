# symbolic 软连接管理工具

# 🔗 symbolic - 符号链接批量创建工具

为常用目录创建符号链接，实现“一处配置，多处访问”。

## 📌 功能

- ✅ 批量创建符号链接
- ✅ 支持目录与文件
- ✅ 可跨盘符链接
- ✅ 避免重复复制

## 🔧 使用方法
```powershell
symbolic -c                    # 查看 link.json 配置
symbolic                       # 创建所有配置的链接
symbolic -r                    # 删除所有链接（谨慎使用）
symbolic -s D:\link\app        # 检查单个链接状态
```