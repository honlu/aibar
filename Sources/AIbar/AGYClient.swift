import Foundation
import Darwin

enum AGYClient {
    enum QueryError: LocalizedError {
        case notInstalled, workspaceNotConfigured, failed
        var errorDescription: String? {
            switch self {
            case .notInstalled: "未找到 agy，请先安装 Antigravity CLI。"
            case .workspaceNotConfigured: "请重新选择有效的 AGY 工作目录。"
            case .failed: "AGY 查询失败或超时，上次读数已保留。"
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

    @concurrent static func fetch(workspacePath: String? = nil) async throws -> AccountUsage {
        let manager = FileManager.default
        guard let workspacePath else { throw QueryError.workspaceNotConfigured }
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: workspacePath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw QueryError.workspaceNotConfigured
        }
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
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        let forceStop = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30, execute: timeout)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 32, execute: forceStop)
        defer { timeout.cancel(); forceStop.cancel() }
        let data = await withTaskCancellationHandler {
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return output
        } onCancel: {
            if process.isRunning { process.terminate() }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        try Task.checkCancellation()
        guard process.terminationStatus == 0, data.count <= 65_536,
              let text = String(data: data, encoding: .utf8) else { throw QueryError.failed }
        return try parse(text)
    }
}
