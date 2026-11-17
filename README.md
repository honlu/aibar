# AIbar

原生 macOS 菜单栏 AI 订阅用量监控工具，基于 SwiftUI + AppKit（`NSStatusItem` / `NSPopover`）构建，适配 macOS 14+ 与 Swift 6.2+，无第三方依赖、无 Dock 图标。

## 项目简介

AIbar 常驻于 macOS 顶部菜单栏，用于在一处集中查看多个 AI 编程订阅的实时用量与重置时间，无需频繁打开各平台网页控制台。

## 核心功能

- **菜单栏实时摘要**：在菜单栏显示当前选中平台与主窗口已用百分比，读数过期或查询失败时以 `·` 提示，并自动适配系统深浅色与全屏菜单栏。
- **多平台切换**：支持 **Codex**、**Kimi**、**MiniMax** 与 **Antigravity（AGY）**（Gemini 分组额度统一在 AGY 下展示）。
- **已用比例与状态分级**：面板所有数字均为**已用比例**，按阈值高亮显示（绿色 `<65%`、橙色 `≥65%`、红色 `≥90%`），并展示距离重置的相对时间与具体时刻。
- **多账户与过期识别**：支持同一 Magpie 平台下的多个账户（界面隐藏原始账户标识）；源数据超过 15 分钟或已越过重置时间时标记为「需更新」，不会将缺失或过期用量误判为 `0%`；读取失败时保留上次有效读数并提示。
- **AGY 实时查询与粘贴备用**：支持通过本机 `agy` CLI 实时查询额度，也可在面板中直接粘贴 `/usage` 文本输出作为备用导入。

## 数据源与刷新机制

| 来源 | 接入方式 | 刷新行为 |
| --- | --- | --- |
| Codex / Kimi / MiniMax | 只读本机 Magpie 缓存 `~/.config/magpie/quotas.json` | 启动、展开面板、每 60 秒或点击「重读缓存」时读取；Magpie 负责联网更新 |
| Antigravity / AGY | 调用本机 `agy --mode plan --print /usage --print-timeout 20s` 实时查询；支持粘贴备用 | 选中 AGY 时每 5 分钟自动查询；任何失败后暂停并保存状态，重启不重试；点击「恢复查询」且成功后恢复自动刷新 |

> **AGY 登录提示**：仅调用 CLI 也可能由 CLI 自行打开浏览器登录。AIbar 无法保证首次认证失败时不弹页；但任何失败、超时或取消后都会暂停自动查询，重启 App、切换平台或更改工作目录也不会自动重试。请先在终端恢复登录/网络，再点击「恢复查询」。主动查询前会确认此行为；粘贴导入不启动 CLI，也不会解除暂停。

> AGY 查询调用内置 `/usage` 命令，不发送自然语言提示，也不自动批准信任提示；需要本机已安装并登录 `agy`。请先在终端进入准备用于查询的目录完成 `agy` 登录和项目授权，再在齿轮菜单中点击「选择 AGY 工作目录…」。工作目录仅保存在本机，不会写入安装包；目录移动或删除后需重新选择。CLI 输出为五行 TSV（模型组、额度窗口、剩余百分比、ISO8601 重置时间），精度为整数 `1%`；粘贴导入模式保留文本中的小数，并按导入时刻估算重置时间。

## 下载与安装

从 [GitHub Releases](https://github.com/honlu/aibar/releases) 下载：

- Apple Silicon（M 系列）：`AIbar-版本-arm64.zip`。
- Intel Mac：`AIbar-版本-x86_64.zip`。

要求 macOS 14 或更高版本。解压后将 `AIbar.app` 拖入「应用程序」并打开，应用只显示在顶部菜单栏，没有 Dock 图标。使用下载版本无需安装 Swift 或 Xcode。

当前版本没有 Apple 开发者证书，使用 ad-hoc 签名且未公证。首次运行可能被系统拦截。确认下载来自本仓库后，在「系统设置 → 隐私与安全性」中点击「仍要打开」，详见 [Apple 说明](https://support.apple.com/102445)。无需关闭 Gatekeeper；公司管理的设备可能禁止手动允许。

**安装应用并不会自动接入订阅账户**：Codex / Kimi / MiniMax 需要本机 Magpie 已刷新并生成 `~/.config/magpie/quotas.json`；AGY 需要本机 `agy` 已安装、登录并授权所选工作目录，或手动粘贴 usage 输出。AIbar 不包含上述工具，也不会提供账户登录入口。

可校验下载文件：

```sh
shasum -a 256 -c AIbar-0.1.0-arm64.zip.sha256
```

## 快速构建与运行

```sh
bash scripts/build-app.sh
open dist/AIbar.app
```

点击菜单栏图标查看用量面板，右下角齿轮菜单支持切换其他 Magpie 缓存文件、打开对应订阅网页及退出应用。

## 缓存与隐私

- 仅读取 Magpie 额度缓存文件，不读取第三方登录凭证或 API Key；AGY 查询由本机 CLI 使用自身登录态完成。
- 自动查询结果仅保存在内存中；选中的平台、自定义缓存路径、AGY 工作目录、自动查询暂停状态与 AGY 粘贴导入结果保存在本机 `UserDefaults`。
- 当前构建脚本使用本机 ad-hoc 签名，不含 Developer ID 公证；缓存路径按非 App Sandbox 本地应用实现，若需上架 Mac App Store 需另行配置 security-scoped bookmarks。

## 开发与测试

可使用 Xcode 打开 [Package.swift](Package.swift) 进行开发，或通过命令行运行与测试：

```sh
# 运行全部单元测试（liveAGYQuery 默认跳过，需设置 AIBAR_LIVE_AGY=1 启用）
swift test

# 启动并在启动时直接展开面板
swift run AIbar --show
```

若在受限沙箱环境下运行测试，可将缓存与构建目录指向临时路径：

```sh
CLANG_MODULE_CACHE_PATH=/tmp/aibar-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/aibar-module-cache swift test --disable-sandbox --cache-path /tmp/aibar-spm-cache --scratch-path /tmp/aibar-build
```

规格文档：[menubar.md](.spec-dev/specs/menubar.md)。AGY 粘贴导入使用英文标准标题（`Gemini Models` / `Claude and GPT Models` / `Gemini 4 Argon`），CLI 输出格式变更时需同步更新解析器。

## 自动构建与发布

GitHub Actions 在推送、Pull Request 或手动触发时运行测试，并分别构建 Apple Silicon 和 Intel 安装包。Actions 运行页中的 Artifacts 保留 14 天；公开下载请使用 Releases。

发布三段式版本标签后，工作流会在两种架构均验证成功后自动创建 GitHub Release，附上 ZIP 和 SHA-256 校验文件：

```sh
git tag v0.1.0
git push origin v0.1.0
```

发布前先确保版本代码已经合入默认分支。标签必须是 `v主版本.次版本.修订版本`；版本号会写入应用 Info.plist。本地可用 `AIBAR_VERSION=0.1.2 bash scripts/build-app.sh` 指定版本。

CI 使用 Xcode 26.2（Swift 6.2）与 macOS 15 runner，只需 GitHub 自带的 `GITHUB_TOKEN`，不需要 Apple 证书或额外 Secrets。未包含自动更新功能，升级时下载新版并替换应用。

## 开源许可

[MIT License](LICENSE)。AIbar 是独立工具，与展示的各平台无官方关联。

## 应用图标

应用使用与菜单栏相同的 `chart.bar.xaxis` 符号。多尺寸图标位于 `Resources/AIbar.icns`，构建时写入 `.app` 并配置 `CFBundleIconFile`。

需要重新生成时，在 macOS 上运行：

```sh
swift scripts/generate-icon.swift /tmp/AIbar.iconset
iconutil -c icns /tmp/AIbar.iconset -o Resources/AIbar.icns
```
