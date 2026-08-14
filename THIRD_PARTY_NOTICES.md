# Third-party notices

本文件用于明确本项目与上游来源的边界。上游代码不随本仓库分发，而是在安装时通过 npm 获取。

## 1. DeepSeek Harness

- 项目：DeepSeek Harness
- 来源：https://github.com/deepseek-ai/deepseek-harness
- npm 包：`@deepseek-ai/dsh`
- 上游许可证：MIT License（以该仓库当前 `LICENSE` 文件为准）
- 本项目使用方式：`install.ps1` 安装固定版本；本仓库不包含其源码或 `node_modules`。

## 2. dsh-web-ui

- 项目：dsh-web-ui
- 来源：https://github.com/zhu1090093659/dsh-web-ui
- npm 包：`@linxin666/dsh-web-ui-all`、`@linxin666/dsh-client-ui-skin-blue-fantasy`
- 上游仓库许可证：Apache License 2.0（以该仓库当前 `LICENSE` 文件及各 npm 包随附文件为准）
- 本项目使用方式：通过 DeepSeek Harness 的插件命令安装；本仓库不包含其源码或构建产物。

## 3. 运行时依赖的许可证

安装后，npm 依赖树可能包含其他第三方包。使用者应在本机安装目录检查相应包的 `LICENSE`、`NOTICE` 与 `package.json`，并遵守其许可证。本项目不重新打包或再分发这棵依赖树。

## 4. 本项目自己的代码

本仓库中的 PowerShell、VBScript、配置模板、文档与补丁脚本按根目录 `LICENSE` 发布。本项目的桌面封装不改变或重新声明上游项目的版权、商标或许可证。
