import Foundation
import Testing
@testable import AIbar

@Test func magpieWindowsAndDates() throws {
    let data = Data(#"{"account":{"at":"2026-11-16T11:00:00+08:00","quota":{"provider":"kimi-code-cn","readAt":"2026-11-16T03:01:00.123456Z","windows":[{"name":"5 hours","used":0,"resetsAt":"2026-11-16T16:00:00+08:00"},{"name":"7 days","used":100}]}}}"#.utf8)
    let accounts = try UsageParser.parse(data)
    let account = try #require(accounts.first)
    #expect(account.provider == .kimi)
    #expect(account.windows.map(\.used) == [0, 100])
    #expect(account.windows[1].resetsAt == nil)
    // Foundation's ISO8601 formatter retains milliseconds; quota age is displayed in seconds.
    #expect(abs(account.readAt.timeIntervalSince1970 - 1794798060.123456) < 0.001)
    #expect(account.windows[0].resetsAt?.timeIntervalSince1970 == 1794816000)
}

@Test(arguments: [-1.0, 101, 999]) func invalidPercentRejected(_ percent: Double) {
    let data = Data("{\"x\":{\"at\":\"2026-11-16T00:00:00Z\",\"quota\":{\"provider\":\"codex\",\"windows\":[{\"name\":\"5 hours\",\"used\":\(percent)}]}}}".utf8)
    #expect(throws: (any Error).self) { try UsageParser.parse(data) }
}

@Test func multipleAccountsAndUnknownProviders() throws {
    let data = Data(#"{"a":{"at":"2026-11-16T00:00:00Z","quota":{"provider":"codex","windows":[]}},"b":{"at":"2026-11-16T00:00:00Z","quota":{"provider":"codex","windows":[]}},"unrelated":{"quota":{"provider":"other","differentSchema":true}}}"#.utf8)
    #expect(try UsageParser.parse(data).map(\.id) == ["a", "b"])
}

@Test func staleDoesNotEraseUsage() {
    let now = Date(timeIntervalSince1970: 10000)
    let account = AccountUsage(id: "test", provider: .codex,
                               windows: [.init(name: "5h", used: 100, resetsAt: now.addingTimeInterval(-1))], readAt: now)
    #expect(account.isStale(at: now))
    #expect(account.windows[0].used == 100)
    let old = AccountUsage(id: "old", provider: .codex, windows: [], readAt: now.addingTimeInterval(-901))
    #expect(old.isStale(at: now))
}

@Test func agyRemainingConversionAndGroups() throws {
    let text = """
    GEMINI MODELS
    Models within this group: Gemini 4 Hydrogen, Gemini 3.8 Flash
    Weekly Limit Remaining
    [====== ] 98.91%
    Refreshes in 129h 34m
    Five Hour Limit Remaining
    [====== ] 98.00%
    Refreshes in 4h 16m
    CLAUDE AND GPT MODELS
    Weekly Limit Remaining
    [=======] 100.00%
    Quota available
    GEMINI 4 ARGON
    Gemini 4 Argon Weekly Limit
    [=====  ] 78.22%
    Refreshes in 129h 17m
    """
    let now = Date(timeIntervalSince1970: 10000)
    let account = try AGYUsageParser.parse(text, at: now)
    #expect(account.windows.count == 4)
    #expect(abs(account.windows[0].used - 1.09) < 0.001)
    #expect(account.windows[1].used == 2)
    #expect(account.windows[2].used == 0)
    #expect(abs(account.windows[3].used - 21.78) < 0.001)
    #expect(account.windows[0].resetsAt == now.addingTimeInterval(466440))
    #expect(account.windows[2].resetsAt == nil)
}

@Test func agyRejectsNonQuotaOutput() {
    #expect(throws: (any Error).self) { try AGYUsageParser.parse("Account: hidden\nUsage: 50 tokens") }
}

@Test func agyPasteEdgeCasesAndCanonicalTitles() throws {
    let text = """
    GEMINI MODELS
    Weekly Limit Remaining
    99.5%
    Refreshes in 0m
    Five Hour Limit Remaining
    50%
    Refreshes in 45m
    CLAUDE AND GPT MODELS
    Weekly Limit Remaining
    100%
    Refreshes in soon
    """
    let now = Date(timeIntervalSince1970: 10000)
    let account = try AGYUsageParser.parse(text, at: now)
    #expect(account.windows.map(\.name) == [
        "Gemini Models · 7 days",
        "Gemini Models · 5 hours",
        "Claude and GPT models · 7 days"
    ])
    #expect(account.windows[0].resetsAt == now)
    #expect(account.windows[1].resetsAt == now.addingTimeInterval(45 * 60))
    #expect(account.windows[2].resetsAt == nil)
}

@Test func magpieReadAtFallbackAndInvalidResetDate() throws {
    let fallbackData = Data(#"{"a":{"at":"2026-11-16T11:00:00+08:00","quota":{"provider":"codex","windows":[]}}}"#.utf8)
    let accounts = try UsageParser.parse(fallbackData)
    #expect(accounts.first?.readAt == (try UsageParser.date("2026-11-16T03:00:00Z")))

    let badReset = Data(#"{"a":{"at":"2026-11-16T11:00:00+08:00","quota":{"provider":"codex","windows":[{"name":"5 hours","used":10,"resetsAt":"bad"}]}}}"#.utf8)
    #expect(throws: (any Error).self) { try UsageParser.parse(badReset) }
}

private let printUsage = """
Gemini Models\tWeekly Limit Remaining\t99%\t2026-11-21T13:39:22Z
Gemini Models\tFive Hour Limit Remaining\t98%\t2026-11-16T08:20:57Z
Claude and GPT models\tWeekly Limit Remaining\t100%\t2026-11-23T04:43:34Z
Claude and GPT models\tFive Hour Limit Remaining\t100%\t2026-11-16T09:43:34Z
Gemini 4 Argon\tGemini 4 Argon Weekly Limit\t78%\t2026-11-21T13:22:17Z
"""

@Test func agyStructuredOutput() throws {
    let result = try AGYClient.parse(printUsage)
    #expect(result.windows.map(\.used) == [1, 2, 0, 0, 22])
    #expect(result.manual == false)
    #expect(result.windows[0].resetsAt == (try UsageParser.date("2026-11-21T21:39:22+08:00")))
    #expect(result.windows.map(\.name).contains("Gemini 4 Argon · 7 days"))
}

@Test func agyPartialAndInvalidOutputRejected() {
    #expect(throws: (any Error).self) { try AGYClient.parse(String(printUsage.split(separator: "\n").first!)) }
    #expect(throws: (any Error).self) { try AGYClient.parse(printUsage.replacingOccurrences(of: "99%", with: "101%")) }
    #expect(throws: (any Error).self) { try AGYClient.parse(printUsage.replacingOccurrences(of: "2026-11-21T13:39:22Z", with: "invalid")) }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["AIBAR_LIVE_AGY"] == "1"))
func liveAGYQuery() async throws {
    let result = try await AGYClient.fetch(workspacePath: FileManager.default.currentDirectoryPath)
    #expect(result.windows.count == 5)
    #expect(result.windows.allSatisfy { (0...100).contains($0.used) && $0.resetsAt != nil })
}

@Test func agyRequiresLocalWorkspace() async {
    for path: String? in [nil, "/nonexistent-aibar-workspace", "/dev/null"] {
        do {
            _ = try await AGYClient.fetch(workspacePath: path)
            Issue.record("AGY must not run without an existing selected directory")
        } catch AGYClient.QueryError.workspaceNotConfigured {
            // Missing configuration must fail before any CLI can start.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
