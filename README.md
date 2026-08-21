# DeepSeek Harness Desktop

这是一个 Windows 桌面封装器：它把 DeepSeek Harness CLI、`dsh-web-ui` Web UI 和可选皮肤接入到一个可诊断、可升级、可卸载的启动流程中。

> 本项目不是 DeepSeek Harness 或 `dsh-web-ui` 的源码副本，也不会把账号凭据、session、工作空间或 `node_modules` 提交到 GitHub。

## 先理解两个概念

- **下载源码**：把本仓库复制到任意源码目录，只获得安装脚本和桌面启动文件。
- **安装运行环境**：运行 `install.ps1`，才会在本机的 npm 全局目录和 `%USERPROFILE%\.dsh` 中安装/接入 DSH、Web UI、皮肤并写入配置。

如果你已经安装过 DeepSeek Harness 和 Web UI，不需要重新下载安装，使用接入模式：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1 -DesktopOnly
```

## 前置条件

- Windows 10/11
- Node.js 22 或更高版本，`node.exe` 和 `npm.cmd` 可在 PATH 中找到；无需预先运行 `corepack enable`
- 能访问 npm registry；如使用私有 registry，请在本机配置 npm，不要把 token 写入仓库
- Chrome 或 Edge 不是硬性依赖；没有它们时启动器会调用系统默认浏览器

## 三种常用操作

### 全新安装

```powershell
.\install.ps1
```

安装器会自动安装清单中的 DSH、Web UI 和 pnpm 版本，并注册默认皮肤。它还会把 npm 的全局目录加入用户 PATH，并在桌面启动 DSH 时再次注入该目录，避免“检查更新”找不到 pnpm。

### 已有 DSH/Web UI，只安装桌面封装

```powershell
.\install.ps1 -DesktopOnly
```

该模式不会重新安装核心或 Web UI，只检查已有 `dsh.cmd`、web profile 和皮肤资源，然后完成配置、启动器、诊断信息和原生目录选择器补丁。

### 修复已有接入

```powershell
.\repair.ps1
```

`repair.ps1` 默认等同于 `install.ps1 -DesktopOnly -Repair`，不会因为修复桌面封装而强制升级 DSH/Web UI。

## 启动、状态和停止

双击桌面快捷方式，或运行：

```powershell
.\Start-DeepSeek-Harness.ps1
.\Start-DeepSeek-Harness.ps1 -Status
.\Start-DeepSeek-Harness.ps1 -Stop
.\Start-DeepSeek-Harness.ps1 -NoBrowser
```

启动器会记录 PID，检查 `127.0.0.1:3180` 是否已有服务，避免重复启动。日志位于安装目录的 `logs` 子目录；若安装目录不可写，则回退到 `%LOCALAPPDATA%\DeepSeek-Harness-Desktop\logs`。

## 诊断

```powershell
.\diagnose.ps1
.\diagnose.ps1 -Json
.\diagnose.ps1 -FailOnError
```

诊断会检查 DSH 命令、Web UI、皮肤包、managed patch、原生补丁、3180 端口、快捷方式和安装状态文件。

## 配置和数据边界

安装器只管理带有以下标记的区域：

```text
# BEGIN deepseek-harness-desktop:skin
...
# END deepseek-harness-desktop:skin
```

它不会整体覆盖 `%USERPROFILE%\.dsh\cordis.patch.yml` 或 `profiles\web\cordis.patch.yml`，也不会删除登录凭据、session、workspace。每次真正修改已有配置前，会把原文件备份到：

```text
%USERPROFILE%\.dsh\backups\deepseek-harness-desktop
```

## 版本清单

版本集中在 `versions.json`：

- DSH：`@deepseek-ai/dsh`
- Web UI：`@linxin666/dsh-web-ui-all`
- 默认皮肤：`blue-fantasy`
- pnpm：用于 DeepSeek Harness 的更新检查
- 默认端口：`3180`

升级前请先在隔离环境验证上游版本，修改 `versions.json` 后执行 `.\install.ps1 -Repair`；如果只想升级桌面封装，不要修改版本清单，执行 `.\install.ps1 -DesktopOnly -Repair`。

## 卸载

默认只移除桌面封装、快捷方式和本安装器的 managed 配置块：

```powershell
.\uninstall.ps1
```

恢复安装前的精确配置备份：

```powershell
.\uninstall.ps1 -RestoreConfig
```

明确移除本 profile 中安装器管理的 Web UI/皮肤依赖：

```powershell
.\uninstall.ps1 -RemoveWebUi
```

明确卸载全局 DSH CLI：

```powershell
.\uninstall.ps1 -RemoveHarness
```

这些选项可以组合。卸载脚本会校验安装状态和目标路径，拒绝递归删除未登记目录或源码目录。

## 目录位置

| 内容 | 位置 |
|---|---|
| 桌面封装安装目录 | `%LOCALAPPDATA%\DeepSeek-Harness-Desktop` |
| DSH CLI | `%APPDATA%\npm\dsh.cmd` |
| DSH 用户数据与 profile | `%USERPROFILE%\.dsh` |
| Web profile | `%USERPROFILE%\.dsh\profiles\web` |
| 安装状态 | `%LOCALAPPDATA%\DeepSeek-Harness-Desktop\install-state.json` |
| 备份 | `%USERPROFILE%\.dsh\backups\deepseek-harness-desktop` |

## 目录结构

```text
.
├─ assets/DeepSeek Harness.ico
├─ config/
├─ docs/
│  ├─ EXISTING-INSTALL.zh-CN.md
│  ├─ INSTALL.zh-CN.md
│  ├─ SOURCES.zh-CN.md
│  ├─ TROUBLESHOOTING.zh-CN.md
│  └─ UPGRADE.zh-CN.md
├─ patches/native-directory-picker-owner.patch.ps1
├─ scripts/Common.ps1
├─ diagnose.ps1
├─ install.ps1
├─ repair.ps1
├─ uninstall.ps1
├─ Start-DeepSeek-Harness.ps1
├─ Start DeepSeek Harness.cmd
└─ Start DeepSeek Harness.vbs
```

## 上游来源和许可证

请查看 `docs/SOURCES.zh-CN.md` 与 `THIRD_PARTY_NOTICES.md`。DeepSeek Harness、dsh-web-ui、npm 包名和相关商标归其各自权利人所有。
