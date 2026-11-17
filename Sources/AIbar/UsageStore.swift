import AppKit
import Observation

@MainActor @Observable
final class UsageStore {
    var selected: Provider {
        didSet { defaults.set(selected.rawValue, forKey: "selectedProvider"); onChange?() }
    }
    private(set) var accounts: [AccountUsage] = []
    private(set) var error: String?
    private(set) var isRefreshingMagpie = false
    private(set) var isRefreshingAGY = false
    var isRefreshing: Bool { isRefreshingMagpie || isRefreshingAGY }
    private(set) var agy: AccountUsage?
    private(set) var agyError: String?
    private(set) var agyAutoRefreshPaused: Bool {
        didSet { defaults.set(agyAutoRefreshPaused, forKey: "agyAutoRefreshPaused") }
    }
    private var lastAGYAttempt: Date?
    private let defaults: UserDefaults
    private let agyQuery: (String?) async throws -> AccountUsage
    var onChange: (() -> Void)?
    var sourcePath: String {
        defaults.string(forKey: "quotaPath") ??
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/magpie/quotas.json").path
    }
    var visibleAccounts: [AccountUsage] {
        switch selected {
        case .antigravity: agy.map { [$0] } ?? []
        default: accounts.filter { $0.provider == selected }
        }
    }
    init(defaults: UserDefaults = .standard,
         agyQuery: @escaping (String?) async throws -> AccountUsage = {
             try await AGYClient.fetch(workspacePath: $0)
         }) {
        self.defaults = defaults
        self.agyQuery = agyQuery
        agyAutoRefreshPaused = defaults.bool(forKey: "agyAutoRefreshPaused")
        let savedProvider = defaults.string(forKey: "selectedProvider") ?? "codex"
        selected = savedProvider == "gemini" ? .antigravity : Provider(rawValue: savedProvider) ?? .codex
        defaults.set(selected.rawValue, forKey: "selectedProvider")
        if agyAutoRefreshPaused {
            agyError = "AGY 自动查询已暂停。点击「检查 AGY 用量」重新检查；若提示登录再完成认证。"
        }
        if let data = defaults.data(forKey: "agyImport") {
            agy = try? JSONDecoder().decode(AccountUsage.self, from: data)
        }
    }
    func refresh(at now: Date = .now) async {
        if !isRefreshingMagpie {
            isRefreshingMagpie = true
            let path = sourcePath
            do {
                let loaded = try await Task.detached(priority: .utility) {
                    try UsageParser.parse(Data(contentsOf: URL(fileURLWithPath: path)))
                }.value
                accounts = loaded
                error = nil
            } catch is CancellationError {
                // Keep prior state on task cancellation.
            } catch {
                self.error = "无法读取 Magpie 额度缓存。请确认 Magpie 已刷新额度，或重新选择缓存文件。上次读数已保留。"
            }
            isRefreshingMagpie = false
            onChange?()
        }
        if selected == .antigravity, !agyAutoRefreshPaused,
           lastAGYAttempt.map({ now.timeIntervalSince($0) >= 300 }) ?? true {
            await queryAGY(at: now)
        }
    }
    func queryAGY(at now: Date = .now) async {
        guard selected == .antigravity, !isRefreshingAGY else { return }
        isRefreshingAGY = true
        lastAGYAttempt = now
        // Persist the pause before launching: failure, cancellation or app termination must not retry.
        agyAutoRefreshPaused = true
        defer { isRefreshingAGY = false; onChange?() }
        do {
            agy = try await agyQuery(defaults.string(forKey: "agyWorkingDirectory"))
            agyError = nil
            agyAutoRefreshPaused = false
        } catch is CancellationError {
            agyError = "AGY 查询已取消，自动查询已暂停。点击「检查 AGY 用量」重试。"
        } catch {
            agyError = ((error as? AGYClient.QueryError)?.errorDescription
                        ?? "AGY 用量格式无法识别，上次读数已保留。")
                + " 自动查询已暂停，可点击「检查 AGY 用量」重试。"
        }
    }
    func chooseSource() {
        let panel = NSOpenPanel()
        panel.title = "选择 Magpie quotas.json"
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: "quotaPath")
            Task { await refresh() }
        }
    }
    func importAGY(_ text: String) throws {
        let value = try AGYUsageParser.parse(text)
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: "agyImport")
        agy = value
        agyError = nil
        onChange?()
    }
    var hasAGYWorkingDirectory: Bool {
        guard let path = defaults.string(forKey: "agyWorkingDirectory") else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    @discardableResult func chooseAGYWorkingDirectory() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "选择 AGY 工作目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: "agyWorkingDirectory")
            // Choosing a directory must not clear a previous failure or trigger authentication.
            return true
        }
        return false
    }
    func openWebsite() {
        if let url = URL(string: selected.website) { NSWorkspace.shared.open(url) }
    }
}
