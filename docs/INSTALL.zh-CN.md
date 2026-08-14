# 安装说明（中文）

## 1. 建议安装方式

在仓库根目录打开 PowerShell，执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

安装脚本不需要管理员权限。若企业策略阻止 npm 或 PowerShell，请由管理员按组织策略放行，不要把账号凭据写入脚本。

## 2. 安装后文件位置

- 桌面快捷方式：`%USERPROFILE%\Desktop\DeepSeek Harness.lnk`
- 启动器副本：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop`
- DeepSeek Harness CLI：`%APPDATA%\npm\dsh.cmd`
- 用户配置：`%USERPROFILE%\.dsh`
- 启动日志：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs`

## 3. 版本与网络

安装器会从 npm 安装固定版本。若 npm registry 不可访问，安装会在依赖安装步骤失败；先解决网络、代理或 registry 配置，再重新执行即可。脚本不会把私有 registry token 写入仓库。

## 4. 从源码更新

更新仓库后先审阅 `install.ps1` 的版本号和变更，再执行安装。脚本会在覆盖 dsh 配置前创建备份。
