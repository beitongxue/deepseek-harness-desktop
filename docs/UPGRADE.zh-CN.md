# 升级策略

## 桌面封装升级

拉取新源码后，如果只想升级启动器、诊断脚本或补丁：

```powershell
.\install.ps1 -DesktopOnly -Repair
```

这不会重新安装 DSH 或 Web UI。

## DSH/Web UI 升级

版本集中在仓库根目录的 `versions.json`。修改前先确认上游包可用，并在测试用户或备份环境中验证：

```powershell
Get-Content .\versions.json
```

确认版本后执行：

```powershell
.\install.ps1 -Repair
```

该命令会按 `versions.json` 重新安装 DSH/Web UI，然后重新合并 profile、皮肤和桌面补丁。

## 升级前备份

安装器会自动备份被修改的已有 Cordis patch。若要额外保存用户数据，请自行复制：

```powershell
Copy-Item "$env:USERPROFILE\.dsh" "$env:USERPROFILE\.dsh.backup" -Recurse
```

不要把这个备份目录提交到 GitHub；其中可能含有登录凭据和 session。

## 升级后验证

```powershell
.\diagnose.ps1 -FailOnError
.\Start-DeepSeek-Harness.ps1 -Status
```

如果当前 DSH 已内置 `GetForegroundWindow()` 所有者传递，安装器会识别为上游已支持并不再写入补丁或备份。若原生补丁仍因上游 `worker.cjs` 结构变化而失败，安装器会停止并保留原文件；不要手工盲改，应先检查错误中的锚点，再针对新版本更新 `patches/native-directory-picker-owner.patch.ps1`。

## 回滚

1. 停止服务：`.\Start-DeepSeek-Harness.ps1 -Stop`
2. 运行 `.\uninstall.ps1 -RestoreConfig` 恢复本次安装记录中的精确配置备份。
3. 按 npm 的版本管理方式安装上一个已验证的 DSH/Web UI 版本。
4. 重新执行 `.\install.ps1 -DesktopOnly` 完成桌面接入。
