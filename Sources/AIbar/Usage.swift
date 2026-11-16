import Foundation

enum Provider: String, CaseIterable, Identifiable, Codable {
    case codex, kimi, minimax, antigravity
    var id: String { rawValue }
    var name: String {
        switch self {
        case .codex: "Codex"
        case .kimi: "Kimi"
        case .minimax: "MiniMax"
        case .antigravity: "AGY"
        }
    }
    var symbol: String {
        switch self {
        case .codex: "terminal"
        case .kimi: "moon.stars"
        case .minimax: "waveform"
        case .antigravity: "a.circle"
        }
    }
    var website: String {
        switch self {
        case .codex: "https://chatgpt.com/codex/settings/usage"
        case .kimi: "https://www.kimi.com/code/console"
        case .minimax: "https://platform.minimaxi.com/"
        case .antigravity: "https://antigravity.google/"
        }
    }
}

enum AGYUsageParser {
    private static let groupTitles: [String: String] = [
        "GEMINI MODELS": "Gemini Models",
        "CLAUDE AND GPT MODELS": "Claude and GPT models",
        "GEMINI 4 ARGON": "Gemini 4 Argon"
    ]

    static func parse(_ text: String, at now: Date = .now) throws -> AccountUsage {
        let percentPattern = try NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)\s*%"#)
        let timePattern = try NSRegularExpression(pattern: #"(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?"#)
        var group = ""
        var pendingName: String?
        var windows: [UsageWindow] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let upper = line.uppercased()
            if let title = groupTitles[upper] {
                group = title
                pendingName = nil
            }
            if upper.contains("WEEKLY LIMIT") { pendingName = "\(group) · 7 days" }
            if upper.contains("FIVE HOUR LIMIT") { pendingName = "\(group) · 5 hours" }
            let nsLine = line as NSString
            if let name = pendingName, !group.isEmpty,
               let match = percentPattern.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
               let remaining = Double(nsLine.substring(with: match.range(at: 1))) {
                guard (0...100).contains(remaining), !windows.contains(where: { $0.name == name }) else {
                    throw UsageParser.ParseError.invalidWindow
                }
                windows.append(.init(name: name, used: 100 - remaining, resetsAt: nil))
                pendingName = nil
            }
            if upper.hasPrefix("REFRESHES IN"), !windows.isEmpty {
                let time = String(line.dropFirst("Refreshes in".count)).trimmingCharacters(in: .whitespaces)
                let nsTime = time as NSString
                if let match = timePattern.firstMatch(in: time, range: NSRange(location: 0, length: nsTime.length)) {
                    let hasUnit = (1...3).contains { match.range(at: $0).location != NSNotFound }
                    if hasUnit {
                        func number(_ index: Int) -> Double {
                            let range = match.range(at: index)
                            return range.location == NSNotFound ? 0 : Double(nsTime.substring(with: range)) ?? 0
                        }
                        let seconds = number(1) * 3600 + number(2) * 60 + number(3)
                        windows[windows.count - 1].resetsAt = now.addingTimeInterval(seconds)
                    }
                }
            }
        }
        guard !windows.isEmpty else { throw UsageParser.ParseError.invalidWindow }
        return AccountUsage(id: "agy-import", provider: .antigravity, plan: "Antigravity · usage 导入",
                            windows: windows, readAt: now, manual: true)
    }
}

struct UsageWindow: Codable, Identifiable {
    var name: String
    var used: Double
    var resetsAt: Date?
    var id: String { name }
    func needsUpdate(at now: Date) -> Bool { resetsAt.map { $0 <= now } ?? false }
}

struct AccountUsage: Identifiable, Codable {
    var id: String
    var provider: Provider
    var plan: String?
    var windows: [UsageWindow]
    var readAt: Date
    var manual: Bool = false
    func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(readAt) > 900 || windows.contains { $0.needsUpdate(at: now) }
    }
}

enum UsageParser {
    private struct Entry: Decodable {
        var at: String
        var quota: Quota
    }
    private struct Quota: Decodable {
        var provider: String
        var plan: String?
        var windows: [Window]
        var readAt: String?
    }
    private struct Window: Decodable {
        var name: String
        var used: Double
        var resetsAt: String?
    }
    static func date(_ text: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: text) else { throw ParseError.invalidDate }
        return date
    }
    static func parse(_ data: Data) throws -> [AccountUsage] {
        // Decode supported entries separately so unrelated provider schemas do not break the panel.
        let root = try JSONSerialization.jsonObject(with: data)
        guard let entries = root as? [String: Any] else { throw ParseError.invalidRoot }
        var accounts: [AccountUsage] = []
        let mapping: [String: Provider] = ["codex": .codex, "kimi-code-cn": .kimi, "minimax-cn": .minimax]
        for (id, value) in entries.sorted(by: { $0.key < $1.key }) {
            guard let item = value as? [String: Any],
                  let quota = item["quota"] as? [String: Any],
                  let name = quota["provider"] as? String,
                  let provider = mapping[name] else { continue }
            let entry = try JSONDecoder().decode(Entry.self, from: JSONSerialization.data(withJSONObject: value))
            var windows: [UsageWindow] = []
            for window in entry.quota.windows {
                guard window.used.isFinite, (0...100).contains(window.used), !window.name.isEmpty,
                      !windows.contains(where: { $0.name == window.name }) else { throw ParseError.invalidWindow }
                windows.append(UsageWindow(name: window.name, used: window.used,
                                           resetsAt: try window.resetsAt.map(date)))
            }
            accounts.append(AccountUsage(id: id, provider: provider, plan: entry.quota.plan,
                                         windows: windows, readAt: try date(entry.quota.readAt ?? entry.at)))
        }
        return accounts
    }
    enum ParseError: LocalizedError {
        case invalidDate, invalidWindow, invalidRoot
        var errorDescription: String? { "额度缓存格式无效，请在 Magpie 中刷新后重试。" }
    }
}
