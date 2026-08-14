# 故障排查（中文）

## 双击桌面图标没有窗口

1. 确认 `%APPDATA%\npm\dsh.cmd` 存在。
2. 查看 `%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs\dsh-web.log` 和 `dsh-web-error.log`。
3. 在 PowerShell 手动运行：

   ```powershell
   & "$env:APPDATA\npm\dsh.cmd" web
   ```

4. 确认 3080 端口没有被其他程序占用，并确认 Chrome 或 Edge 已安装。

## 皮肤列表为空或只有默认样式

皮肤是通过 npm 包安装的，不是仅靠 YAML 文件生成。重新运行安装器，或检查：

```powershell
& "$env:APPDATA\npm\dsh.cmd" plugin --profile web list
```

如果上游包版本变更导致皮肤 id 不匹配，应以 `dsh-web-ui` 仓库当前说明为准更新 `config/skin.cordis.patch.yml`。

## 选择工作空间窗口仍被遮挡

以管理员权限运行不是首选。先确认补丁是否应用：

```powershell
& "$env:LOCALAPPDATA\DeepSeek-Harness-Desktop\patches\native-directory-picker-owner.patch.ps1" -DshRoot "$env:APPDATA\npm\node_modules\@deepseek-ai\dsh"
```

如果脚本提示源码锚点不匹配，说明上游 `worker.cjs` 结构已经变化。不要手工盲改；保留错误信息，针对新版本更新补丁脚本。

## 想恢复原来的配置

运行：

```powershell
.\uninstall.ps1
```

脚本会尝试从 `%USERPROFILE%\.dsh\backups\deepseek-harness-desktop` 恢复最近一次备份。它不会删除登录凭据或工作空间。

## PowerShell 提示禁止执行脚本

只对当前 PowerShell 进程临时放行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

不要为了本安装包修改整个系统的执行策略。
