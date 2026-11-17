AIbar 是 macOS 14+ 菜单栏 AI 订阅用量工具。

本次修复：AGY 查询失败、超时或取消后会暂停自动刷新，重启也不会重试；点击「恢复查询」并成功后才恢复每 5 分钟刷新。CLI 首次认证失败时仍可能打开浏览器。补齐与菜单栏符号一致的应用图标。安装新版后请退出旧进程，再打开新版。

- Apple Silicon（M 系列）：下载 `arm64.zip`。
- Intel Mac：下载 `x86_64.zip`。
- 解压后将 `AIbar.app` 拖入「应用程序」，运行后在顶部菜单栏查看。
- 无需安装 Xcode 或 Swift。

此版本仅有 ad-hoc 签名，未经过 Apple Developer ID 签名和公证。首次启动可能被拦截；确认来源后，可在「系统设置 → 隐私与安全性」中点击「仍要打开」。无需关闭系统 Gatekeeper。受公司设备管理策略约束的 Mac 可能无法允许。

Codex、Kimi、MiniMax 需要本机 Magpie 已生成额度缓存；AGY 实时查询需要已安装并登录的 `agy`，先在终端进入所选目录完成授权，再在 AIbar 齿轮菜单中选择该目录。也可以粘贴 usage 输出。AIbar 不附带这些 CLI 或登录凭证。

每个 ZIP 均附带 SHA-256 校验文件。完整使用说明见仓库 README。
