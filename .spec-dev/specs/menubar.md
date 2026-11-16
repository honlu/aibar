# AIbar 菜单栏用量

macOS 14+，SwiftUI 内容 + AppKit NSStatusItem / NSPopover，无 Dock 图标。
工具为 Codex、AGY、Magpie Kimi / MiniMax Coding Plan；Gemini 模型组统一由 AGY 展示。

面板展开期间冻结 NSStatusItem 标题和宽度；切换工具及异步刷新仅更新面板内容，关闭面板后再显示最新菜单栏标题。避免全屏自动隐藏菜单栏中，状态按钮重排使 NSPopover 锚点失效。

## 数据契约

- Magpie 只读 `~/.config/magpie/quotas.json`，不读取 providers / logins / API Key，不直接发网络请求。支持选择其他 quotas.json。
- 根对象按账户标识分组；每项含 at、quota.provider、quota.plan?、quota.windows[]、quota.readAt?。window.name 是服务端窗口名，used 是已用百分比（0…100），resetsAt 为可选 ISO8601 日期。readAt 优先于 at。
- 只识别 codex、kimi-code-cn、minimax-cn；保留同平台多个账户，隐藏原始账户标识。百分比越界或日期无效时报错，保留上次读数并显示读取失败。15 分钟以上或已越过重置点的读数标为需更新，不能据旧读数推定额度已归零。
- 启动、打开面板、每 60 秒和手动刷新均重读缓存；不强制 Magpie 联网刷新。读取失败不更新源时间。
- 用户已允许 agy 信任当前项目。已移除独立 Gemini 网页订阅及手动记录入口；旧版保存的 Gemini 选中偏好迁移到 AGY。自动查询使用 `agy --mode plan --print /usage --print-timeout 20s`，工作目录来自构建时写入的 Info.plist `AIbarAGYWorkingDirectory`，不会自动批准任何提示。CLI 自行使用其登录态联网；解析五行 TSV（组、窗口、剩余百分比、ISO8601 重置时间），已用=100−remaining。比例为 CLI 提供的整数，不能冒充小数精度；缺组、越界、日期损坏或非零退出均保留旧读数并提示。30 秒外部看门狗终止未退出的 CLI。选中 AGY 时最多每 5 分钟自动查询，按钮强制刷新。
- 支持粘贴英文 usage 输出备用：按 Gemini Models / Claude and GPT Models / Gemini 4 Argon 分组，已用=100−remaining；重置时间=导入时刻+Refreshes in 时长，界面标明估算和导入时间。缺失重置时间为未知，不推断已归零。
- UserDefaults 仅保存所选工具、缓存文件路径、AGY 导入解析结果；不保存原始 usage 文本，不复制第三方密钥。

## 验证

Swift build/test 检查编译与缓存解码；构造独立样本验证 0/100/越界、时区、未知平台、多账户、缺失窗口/日期、过期状态。运行 app 并检查实际 SwiftUI 产物；真实缓存读取仅输出账户数量，不输出账户 ID 或凭据。AGY 的 Gemini 分组查询保留，移除的仅为独立网页订阅入口。

全屏定位回归：在 herdr 全屏空间中展开自动隐藏的菜单栏，打开 AIbar，移动鼠标到面板等待菜单栏隐藏，再依次切换四个工具、刷新并等待异步返回；面板应保持原位置。关闭后菜单栏标题显示最新所选工具及读数；再次展开仍锚定状态项。此交互需要真实全屏环境验收，构建或解析测试不能替代。
