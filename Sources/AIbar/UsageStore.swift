import AppKit
import Observation

@MainActor @Observable
final class UsageStore {
    var selected: Provider {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: "selectedProvider"); onChange?() }
    }
    private(set) var accounts: [AccountUsage] = []
    private(set) var error: String?
    private(set) var isRefreshingMagpie = false
    private(set) var isRefreshingAGY = false
    var isRefreshing: Bool { isRefreshingMagpie || isRefreshingAGY }
    private(set) var agy: AccountUsage?
    private(set) var agyError: String?
    private var lastAGYAttempt: Date?
    var onChange: (() -> Void)?
    var sourcePath: String {
        UserDefaults.standard.string(forKey: "quotaPath") ??
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/magpie/quotas.json").path
    }
    var visibleAccounts: [AccountUsage] {
        switch selected {
        case .antigravity: agy.map { [$0] } ?? []
        default: accounts.filter { $0.provider == selected }
        }
    }
    init() {
        let savedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "codex"
        selected = savedProvider == "gemini" ? .antigravity : Provider(rawValue: savedProvider) ?? .codex
        UserDefaults.standard.set(selected.rawValue, forKey: "selectedProvider")
        if let data = UserDefaults.standard.data(forKey: "agyImport") {
            agy = try? JSONDecoder().decode(AccountUsage.self, from: data)
        }
    }
    func refresh(forceAGY: Bool = false) async {
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
        if selected == .antigravity,
           !isRefreshingAGY,
           forceAGY || lastAGYAttempt.map({ Date.now.timeIntervalSince($0) >= 300 }) ?? true {
            isRefreshingAGY = true
            lastAGYAttempt = .now
            do {
                agy = try await AGYClient.fetch(workspacePath: UserDefaults.standard.string(forKey: "agyWorkingDirectory"))
                agyError = nil
            } catch is CancellationError {
                // Keep prior state on task cancellation.
            } catch {
                agyError = (error as? AGYClient.QueryError)?.errorDescription ?? "AGY 用量格式无法识别，上次读数已保留。"
            }
            isRefreshingAGY = false
            onChange?()
        }
    }
    func chooseSource() {
        let panel = NSOpenPanel()
        panel.title = "选择 Magpie quotas.json"
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "quotaPath")
            Task { await refresh() }
        }
    }
    func importAGY(_ text: String) throws {
        let value = try AGYUsageParser.parse(text)
        let data = try JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: "agyImport")
        agy = value
        agyError = nil
        onChange?()
    }
    func chooseAGYWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择已完成 agy 授权的工作目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "agyWorkingDirectory")
            Task { await refresh(forceAGY: true) }
        }
    }
    func openWebsite() {
        if let url = URL(string: selected.website) { NSWorkspace.shared.open(url) }
    }
}
