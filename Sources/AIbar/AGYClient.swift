import Foundation

enum AGYClient {
    enum QueryError: LocalizedError {
        case notInstalled, failed
        var errorDescription: String? {
            switch self {
            case .notInstalled: "未找到 agy。请先安装并在终端完成登录和项目授权。"
            case .failed: "AGY 查询失败或超时。请在终端检查 agy 登录状态；上次读数已保留。"
            }
        }
    }

    static func parse(_ text: String, at now: Date = .now) throws -> AccountUsage {
        var windows: [UsageWindow] = []
        for line in text.components(separatedBy: .newlines) {
            let columns = line.components(separatedBy: "\t")
            guard columns.count == 4 else { continue }
            let group = columns[0]
            guard ["Gemini Models", "Claude and GPT models", "Gemini 4 Argon"].contains(group) else { continue }
            let window: String
            switch columns[1] {
            case "Weekly Limit Remaining", "Gemini 4 Argon Weekly Limit": window = "7 days"
            case "Five Hour Limit Remaining": window = "5 hours"
            default: throw QueryError.failed
            }
            guard columns[2].hasSuffix("%"),
                  let remaining = Double(columns[2].dropLast()), remaining.isFinite,
                  (0...100).contains(remaining) else { throw QueryError.failed }
            let name = "\(group) · \(window)"
            guard !windows.contains(where: { $0.name == name }) else { throw QueryError.failed }
            windows.append(.init(name: name, used: 100 - remaining,
                                 resetsAt: try UsageParser.date(columns[3].trimmingCharacters(in: .whitespacesAndNewlines))))
        }
        // A partial response must not replace a complete snapshot.
        guard windows.count == 5 else { throw QueryError.failed }
        return AccountUsage(id: "agy-live", provider: .antigravity, plan: "Antigravity · CLI 实时查询",
                            windows: windows, readAt: now)
    }

    @concurrent static func fetch() async throws -> AccountUsage {
        let manager = FileManager.default
        let candidates = ["/opt/homebrew/bin/agy", "/usr/local/bin/agy",
                          manager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/agy").path]
        guard let path = candidates.first(where: { manager.isExecutableFile(atPath: $0) }) else {
            throw QueryError.notInstalled
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        // /usage is a built-in command: never send a natural-language prompt or approve a trust dialog.
        process.arguments = ["--mode", "plan", "--print", "/usage", "--print-timeout", "20s"]
        let configuredWorkspace = Bundle.main.object(forInfoDictionaryKey: "AIbarAGYWorkingDirectory") as? String
        let workspace = configuredWorkspace.flatMap { manager.fileExists(atPath: $0) ? $0 : nil }
            ?? manager.currentDirectoryPath
        process.currentDirectoryURL = URL(fileURLWithPath: workspace, isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30, execute: timeout)
        defer { timeout.cancel() }
        let data = await withTaskCancellationHandler {
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return output
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
        try Task.checkCancellation()
        guard process.terminationStatus == 0, data.count <= 65_536,
              let text = String(data: data, encoding: .utf8) else { throw QueryError.failed }
        return try parse(text)
    }
}
