AIbar 是 macOS 14+ 菜单栏 AI 订阅用量工具。

本次修复：AGY 查询失败、超时或取消后会暂停自动刷新，重启也不会重试；点击「检查 AGY 用量」并成功后才恢复每 5 分钟刷新。CLI 首次认证失败时仍可能打开浏览器。补齐与菜单栏符号一致的应用图标。安装新版后请退出旧进程，再打开新版。

- 官方仅提供 Apple Silicon（M 系列）DMG：下载 `AIbar-版本-arm64.dmg`，打开后将 `AIbar.app` 拖入「Applications / 应用程序」。无需安装 Xcode 或 Swift。
- Intel Mac 请参考 README 在本机从源码构建。

此版本仅有 ad-hoc 签名，未经过 Apple Developer ID 签名和公证。首次启动可能被拦截；确认来源后，可在「系统设置 → 隐私与安全性」中点击「仍要打开」。无需关闭系统 Gatekeeper。受公司设备管理策略约束的 Mac 可能无法允许。

Codex、Kimi、MiniMax 需要本机 Magpie 已生成额度缓存；AGY 实时查询需要本机已安装 `agy`，点击「检查 AGY 用量」即可直接调用 CLI，首次会弹窗选择工作目录；只有 CLI 要求交互认证或授权时才需用户处理。也可以粘贴 usage 输出。AIbar 不附带这些 CLI 或登录凭证。

DMG 附带 SHA-256 校验文件。完整使用及源码构建说明见仓库 README。
