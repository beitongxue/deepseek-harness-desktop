# 故障排查（中文）

## 1. 双击桌面图标没有窗口

先在源码目录执行：

```powershell
.\diagnose.ps1
.\Start-DeepSeek-Harness.ps1 -Status
```

然后查看：

```text
%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs\dsh-web.log
%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs\dsh-web-error.log
```

如果安装目录不可写，日志会回退到同目录下的 LocalAppData 日志路径。

## 2. 未找到 dsh.cmd

```powershell
Test-Path "$env:APPDATA\npm\dsh.cmd"
Get-Command dsh.cmd
```

如果命令不存在，先安装 DeepSeek Harness；如果已经安装但不在 PATH，可重启 PowerShell，或确认 npm global bin 目录已加入 PATH。

## 3. 已有安装却提示 Web UI 缺失

`-DesktopOnly` 不会凭空下载 Web UI。确认 profile 中存在：

```powershell
Test-Path "$env:USERPROFILE\.dsh\profiles\web\node_modules\@linxin666\dsh-web-ui-all\package.json"
```

如果不存在，改用全新安装流程：

```powershell
.\install.ps1
```

## 4. 皮肤列表为空或出现 duplicate loader entry

皮肤必须是实际存在的 npm package。安装器将皮肤作为 profile dependency，并只在全局 managed patch 中激活，避免同时出现在 bundle 和 patch 中。

重新修复：

```powershell
.\repair.ps1
.\diagnose.ps1 -FailOnError
```

不要手动把同一皮肤同时加入 `dsh.profile.bundles` 和 `cordis.patch.yml`。

## 5. 选择工作空间窗口仍被遮挡

确认诊断中的 `nativePickerPatched` 为 `True`。如果补丁提示源码锚点不匹配，说明上游 `worker.cjs` 结构已经变化。不要盲目替换字符串；保留原文件并针对新版本更新：

```text
patches/native-directory-picker-owner.patch.ps1
```

## 6. 端口 3180 被占用

```powershell
.\Start-DeepSeek-Harness.ps1 -Status
Get-NetTCPConnection -LocalPort 3180 -State Listen
```

如果已有正常 DSH 服务，启动器会复用它；如果是其他程序占用，请停止该程序或调整上游 profile 的端口配置后再启动。

## 7. 想恢复原来的配置

默认卸载只删除安装器的 marked managed block：

```powershell
.\uninstall.ps1
```

恢复本次安装记录的精确备份：

```powershell
.\uninstall.ps1 -RestoreConfig
```

旧版本状态文件如果只有备份文件名而没有目标路径，脚本会拒绝猜测并提示手动处理。

## 8. PowerShell 禁止执行脚本

只对当前 PowerShell 进程临时放行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

不要为了本项目修改整个系统的执行策略。
## 9. 点击“检查更新”提示未找到 pnpm

桌面服务进程可能继承了旧的 Windows PATH；即使 IDE 或终端能运行 pnpm，已经启动的 DSH 也不一定能找到它。先运行：

```powershell
.\install.ps1 -DesktopOnly -Repair
& "$env:APPDATA\npm\pnpm.cmd" --version
```

随后**完全退出并重新打开** DeepSeek Harness（可先执行 `.\Start-DeepSeek-Harness.ps1 -Stop`，再双击桌面图标）。安装器会在缺失时安装所需 pnpm、更新用户 PATH，并让桌面启动器把 npm 全局目录传给 DSH 服务。
