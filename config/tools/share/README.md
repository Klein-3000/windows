# 🌐 share - SMB 共享管理工具

一键启用/禁用多个文件夹的网络共享，适用于机房批量部署。

## 📌 功能

- ✅ 批量创建 SMB 共享
- ✅ 支持 Everyone 完全访问
- ✅ 状态查看与配置管理
- ✅ 可指定单个共享操作

## 🔧 使用方法

```powershell
share -s                    # 查看当前共享状态
share -e                    # 启用所有配置的共享
share -e application        # 只启用 application 共享
share -d                    # 禁用所有配置的共享
share -d artemis            # 只禁用 artemis 共享
share -c                    # 查看 shares.json 配置
```