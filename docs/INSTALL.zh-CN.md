# 安装说明（中文）

## 1. 全新安装

在仓库根目录打开 PowerShell，执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

安装器会按 `versions.json` 安装 DSH 和 Web UI，并将桌面封装安装到：

```text
%LOCALAPPDATA%\DeepSeek-Harness-Desktop
```

## 2. 已有 DSH/Web UI 的接入

如果你已经安装好 DeepSeek Harness 和 `dsh-web-ui`，不要重复安装，执行：

```powershell
.\install.ps1 -DesktopOnly
```

如果已有 profile 中缺少 Web UI 或皮肤，这个模式会明确报错，而不是悄悄生成一个不完整的桌面程序。全新机器请使用不带 `-DesktopOnly` 的命令。

## 3. 修复

```powershell
.\repair.ps1
```

默认只修复桌面封装、配置、皮肤依赖和原生补丁，不重新安装 DSH/Web UI。

## 4. 安装后文件位置

- 桌面快捷方式：`%USERPROFILE%\Desktop\DeepSeek Harness.lnk`
- 启动器副本：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop`
- DeepSeek Harness CLI：`%APPDATA%\npm\dsh.cmd`
- 用户配置：`%USERPROFILE%\.dsh`
- Web profile：`%USERPROFILE%\.dsh\profiles\web`
- 安装状态：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop\install-state.json`
- 启动日志：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs`
- 配置备份：`%USERPROFILE%\.dsh\backups\deepseek-harness-desktop`

## 5. 验证

```powershell
.\diagnose.ps1 -FailOnError
.\Start-DeepSeek-Harness.ps1 -NoBrowser
```

## 6. 网络与安全

安装过程中需要访问 npm registry。脚本不会读取、上传或提交 token、凭据、session、工作空间路径和日志。请不要将 `.dsh` 目录或备份目录提交到 GitHub。
