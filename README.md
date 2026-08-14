# DeepSeek Harness Desktop

一个面向 Windows 的桌面启动器与安装脚本：把 DeepSeek Harness 以独立应用窗口打开，并安装指定的 Web UI / 皮肤插件。浏览器的地址栏、标签页等普通浏览器界面不会显示。

> **重要：来源必须区分**
>
> 本仓库不是 DeepSeek Harness 官方仓库，也不是 `dsh-web-ui` 官方仓库的镜像。本项目只负责 Windows 安装流程、桌面快捷方式、启动器、配置模板，以及一个可回滚的原生目录选择器窗口置前修复。

## 来源与归属

| 内容 | 来源/归属 | 本项目是否直接包含上游源码 |
|---|---|---|
| DeepSeek Harness 核心应用 | [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) | 否，通过 npm 安装 |
| Web UI、皮肤插件 | [zhu1090093659/dsh-web-ui](https://github.com/zhu1090093659/dsh-web-ui) | 否，通过 `dsh plugin` 安装 |
| 本桌面安装器、启动器、配置模板、Windows 修复 | [beitongxue/deepseek-harness-desktop](https://github.com/beitongxue/deepseek-harness-desktop) | 是，本仓库内容 |

皮肤包在运行时使用上游项目发布的 npm 包名，例如 `@linxin666/dsh-web-ui-all` 与 `@linxin666/dsh-client-ui-skin-blue-fantasy`。这里的包发布者名称与 GitHub 仓库拥有者 `zhu1090093659` 可能不同；它们都属于上表所列的 `dsh-web-ui` 来源范围。

## 当前版本策略

- DeepSeek Harness：`@deepseek-ai/dsh@0.1.0-rc.6`
- Web UI / 皮肤集合：`@linxin666/dsh-web-ui-all@0.1.12`
- 默认皮肤：`ui-skin-blue-fantasy`
- 本地验证记录：此前在一台 Windows 环境验证过 DeepSeek Harness `0.1.0-rc.6` 与 Web UI `0.1.6`；公开安装脚本固定到上面的版本，避免每次安装得到不可预期的版本。

如果上游发布新版本，请先在隔离环境测试，再修改 `install.ps1` 中的版本号，并同步更新本文档。

## 一键安装

### 前置条件

1. Windows 10/11。
2. Node.js 22 或更高版本，并且 `node.exe`、`npm.cmd` 在 PATH 中。
3. Google Chrome 或 Microsoft Edge，用于承载应用窗口。
4. 安装过程中可以访问 npm registry 和 GitHub。

### 安装步骤

1. 下载本仓库 ZIP 并解压到一个不会随意移动的目录。
2. 右键 `install.ps1`，选择“使用 PowerShell 运行”，或者在 PowerShell 执行：

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\install.ps1
   ```

3. 安装器会：
   - 安装固定版本的 DeepSeek Harness；
   - 安装来自 `zhu1090093659/dsh-web-ui` 的 Web UI / 皮肤包；
   - 写入默认蓝色幻想皮肤配置；
   - 对 Windows 原生“选择工作空间”窗口应用置前补丁；
   - 把启动文件复制到 `%LOCALAPPDATA%\DeepSeek-Harness-Desktop`；
   - 创建桌面快捷方式 `DeepSeek Harness.lnk`，并使用 `assets/DeepSeek Harness.ico` 图标。

4. 双击桌面图标启动。第一次启动服务可能需要几十秒。

> 安装器只修改当前 Windows 用户目录，不要求管理员权限。它会在覆盖已有 dsh 配置前保存备份，但不会读取、上传或提交凭据、登录会话、工作空间路径和日志。

## 皮肤配置

默认配置文件是：

```text
%USERPROFILE%\.dsh\cordis.patch.yml
```

当前模板启用 `ui-skin-blue-fantasy`，并禁用模板中列出的其他皮肤。皮肤包必须先安装成功，单独写 YAML 不能让不存在的皮肤工作。

若要恢复其他皮肤，请先确认对应的 npm 包确实已安装，再按上游 `dsh-web-ui` 项目的说明修改该配置。不要把个人配置文件、token 或 session 上传到 GitHub。

## 原生目录选择器修复

`patches/native-directory-picker-owner.patch.ps1` 只修改已安装的 `worker.cjs`：调用 Windows `GetForegroundWindow`，并把当前前台窗口作为 `IFileOpenDialog.Show(owner)` 的 owner。这样原生目录选择窗口仍保持 Windows 原来的样式，但会受 DeepSeek Harness 主窗口管理，不再容易被主界面遮住。

补丁具备以下安全边界：

- 修改前保存带时间戳的 `.codex-backup-*` 备份；
- 检查已验证的源码锚点，结构不匹配时拒绝盲改；
- 重复执行不会重复插入；
- 卸载脚本可以从备份恢复。

## 卸载

默认只移除桌面快捷方式、安装器复制的启动文件，并恢复本安装器覆盖的配置：

```powershell
.\uninstall.ps1
```

默认不会删除 `%USERPROFILE%\.dsh` 中的登录凭据、会话、工作空间或其他用户数据，也不会卸载全局 DeepSeek Harness。若确认要卸载 CLI，再显式执行：

```powershell
.\uninstall.ps1 -RemoveHarness
```

## 安全发布边界

本仓库刻意不包含：

- `.credentials.yaml`、API Key、密码、Token；
- session、浏览器 storage、登录缓存；
- 本机工作空间绝对路径；
- logs、临时验证文件；
- `node_modules`、完整 AppData 安装目录；
- 上游 DeepSeek Harness 或 `dsh-web-ui` 的源码副本。

安装器在用户本机重新从 npm 安装依赖，因此发布 ZIP 很小，也不会把维护者的账号状态带给下载者。

## 目录结构

```text
.
├─ assets/DeepSeek Harness.ico
├─ config/
│  ├─ skin.cordis.patch.yml
│  └─ web-profile.cordis.patch.yml
├─ docs/
│  ├─ INSTALL.zh-CN.md
│  ├─ SOURCES.zh-CN.md
│  └─ TROUBLESHOOTING.zh-CN.md
├─ patches/native-directory-picker-owner.patch.ps1
├─ install.ps1
├─ uninstall.ps1
├─ Start-DeepSeek-Harness.ps1
├─ Start DeepSeek Harness.vbs
└─ Start DeepSeek Harness.cmd
```

## 免责声明

DeepSeek Harness、dsh-web-ui、npm 包名、图标或相关商标归其各自权利人所有。本项目不代表上游项目，不对上游服务、模型、网络接口或第三方包的可用性作保证。使用前请自行阅读上游许可证与服务条款。
