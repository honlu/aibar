import AppKit
import SwiftUI

@main
struct AIbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let store = UsageStore()
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "AIbar 订阅用量")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 480, height: 660)
        popover.contentViewController = NSHostingController(rootView: PopoverView(store: store))
        store.onChange = { [weak self] in self?.updateTitle() }
        updateTitle()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.store.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        if CommandLine.arguments.contains("--show") { togglePopover() }
    }
    private func updateTitle() {
        // Resizing a status button while its fullscreen menu bar is hidden can
        // invalidate the popover's anchor. Apply the latest title after closing.
        guard !popover.isShown else { return }
        let account = store.visibleAccounts.first
        let window = account?.windows.first
        let stale = account?.isStale(at: .now) ?? false
        let percent = window.map { "\(Int($0.used.rounded()))%" } ?? "—"
        let sourceFailed = store.selected == .antigravity ? store.agyError != nil : store.error != nil
        statusItem?.button?.title = " \(store.selected.name) \(percent)\(stale || sourceFailed ? " ·" : "")"
        statusItem?.button?.toolTip = "AIbar · 已用额度\(stale ? " · 读数需更新" : "")"
    }
    func popoverDidClose(_ notification: Notification) {
        updateTitle()
    }
    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        Task { await store.refresh() }
    }
    func applicationWillTerminate(_ notification: Notification) { refreshTask?.cancel() }
}
