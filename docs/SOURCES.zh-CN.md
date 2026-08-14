# 来源说明（中文）

本项目把“上游应用”“上游皮肤插件”“本项目自己的桌面封装”分开标注：

| 层级 | 项目 | 地址 | 本项目处理方式 |
|---|---|---|---|
| 核心应用 | DeepSeek Harness | https://github.com/deepseek-ai/deepseek-harness | 安装 `@deepseek-ai/dsh`，不复制上游源码 |
| Web UI / 皮肤 | dsh-web-ui | https://github.com/zhu1090093659/dsh-web-ui | 通过 `dsh plugin` 安装，不复制上游源码 |
| 桌面封装 | deepseek-harness-desktop | https://github.com/beitongxue/deepseek-harness-desktop | 本仓库维护安装、启动、配置和 Windows 修复 |

## 皮肤包名称

默认启用的皮肤条目为：

```yaml
- id: ui-skin-blue-fantasy
  name: '@linxin666/dsh-client-ui-skin-blue-fantasy'
```

皮肤集合安装包为：

```text
@linxin666/dsh-web-ui-all
```

`@linxin666` 是 npm 包发布者命名空间；皮肤项目的 GitHub 来源仍以 `zhu1090093659/dsh-web-ui` 为准。不要把 npm 发布者误写成 DeepSeek Harness 官方作者。

## 许可证提示

- DeepSeek Harness 上游仓库声明使用 MIT License。
- `dsh-web-ui` 上游仓库声明使用 Apache License 2.0；其仓库内或 npm 依赖树中的具体包可能另有许可证，应以对应包随附的 `LICENSE`、`package.json` 和 NOTICE 为准。
- 本仓库的安装器、启动器、配置模板和补丁按根目录 `LICENSE` 发布。

本项目没有把上述两个上游仓库的源码、`node_modules` 或构建产物提交进来，因此下载者应在本地安装时接受并遵守各上游及依赖包的许可证条款。
