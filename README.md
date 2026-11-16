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
| Antigravity / AGY | 调用本机 `agy --mode plan --print /usage --print-timeout 20s` 实时查询；支持粘贴备用 | 选中 AGY 时每 5 分钟自动查询，点击「查询额度」立即刷新；30 秒看门狗与任务取消保护 |

> AGY 查询调用内置 `/usage` 命令，不发送自然语言提示，也不自动批准信任提示；需要本机已安装并登录 `agy`。构建脚本会将当前工程路径写入 `Info.plist` 的 `AIbarAGYWorkingDirectory` 作为查询工作目录，移动工程后需重新构建。CLI 输出为五行 TSV（模型组、额度窗口、剩余百分比、ISO8601 重置时间），精度为整数 `1%`；粘贴导入模式保留文本中的小数，并按导入时刻估算重置时间。

## 快速构建与运行

```sh
bash scripts/build-app.sh
open dist/AIbar.app
```

点击菜单栏图标查看用量面板，右下角齿轮菜单支持切换其他 Magpie 缓存文件、打开对应订阅网页及退出应用。

## 缓存与隐私

- 仅读取 Magpie 额度缓存文件，不读取第三方登录凭证或 API Key；AGY 查询由本机 CLI 使用自身登录态完成。
- 自动查询结果仅保存在内存中；选中的平台、自定义缓存路径与 AGY 粘贴导入结果保存在本机 `UserDefaults`。
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
