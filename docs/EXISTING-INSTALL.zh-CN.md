# 已有安装接入指南

本指南适用于你已经在 Windows 上安装了 DeepSeek Harness 和 `dsh-web-ui`，现在只想把本项目作为桌面窗口使用的情况。

## 1. 下载源码不等于安装

把 GitHub ZIP 解压到源码目录，只会得到 PowerShell 脚本。不会自动创建桌面快捷方式，也不会自动生成 `%LOCALAPPDATA%\DeepSeek-Harness-Desktop`。

在源码目录执行下面命令才会进行接入：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1 -DesktopOnly
```

## 2. 接入模式会做什么

- 查找现有 `dsh.cmd`
- 检查 `%USERPROFILE%\.dsh\profiles\web` 中的 Web UI
- 确保皮肤包存在并写入 web profile dependency
- 只更新标记的 managed patch，不覆盖你自己的配置
- 应用可验证的原生目录选择器补丁
- 复制桌面启动器和图标到安装目录
- 创建桌面快捷方式
- 写入 `install-state.json`

## 3. 接入前检查

```powershell
Get-Command node.exe
Get-Command npm.cmd
Test-Path "$env:APPDATA\npm\dsh.cmd"
Test-Path "$env:USERPROFILE\.dsh\profiles\web\package.json"
```

如果没有 DSH，先按上游文档安装；如果没有 Web UI，不要使用 `-DesktopOnly`，改用：

```powershell
.\install.ps1
```

## 4. 接入后确认

```powershell
.\diagnose.ps1
.\Start-DeepSeek-Harness.ps1 -NoBrowser
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:3180
```

## 5. 重要路径

- 桌面封装：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop`
- DSH：`%APPDATA%\npm\dsh.cmd`
- profile：`%USERPROFILE%\.dsh\profiles\web`
- 日志：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs`
- 状态：`%LOCALAPPDATA%\DeepSeek-Harness-Desktop\install-state.json`
- 备份：`%USERPROFILE%\.dsh\backups\deepseek-harness-desktop`

## 6. 失败时如何修复

```powershell
.\repair.ps1
.\diagnose.ps1 -FailOnError
```

如果只是想重新生成桌面封装，不想碰核心版本，始终优先使用 `repair.ps1` 或 `install.ps1 -DesktopOnly -Repair`。
