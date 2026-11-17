import SwiftUI

extension Provider {
    var tint: Color {
        switch self {
        case .codex: .mint
        case .kimi: .purple
        case .minimax: .orange
        case .antigravity: .cyan
        }
    }
}

struct PopoverView: View {
    @Bindable var store: UsageStore
    @State private var importingAGY = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 20) {
                header
                providerPicker
                ScrollView {
                    VStack(spacing: 12) {
                        if store.visibleAccounts.isEmpty { emptyState }
                        ForEach(Array(store.visibleAccounts.enumerated()), id: \.element.id) { index, account in
                            accountCard(account, index: index, now: context.date)
                        }
                        if store.selected == .antigravity {
                            Button("粘贴 usage 输出", systemImage: "doc.on.clipboard") { importingAGY = true }
                                .buttonStyle(.bordered)
                            if let error = store.agyError {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.orange).padding(12)
                            }
                        }
                        if let error = store.error, store.selected != .antigravity {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange).padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding(1)
                }.frame(maxHeight: 390)
                footer
            }
            .padding(24)
            .frame(width: 480, height: 660)
            .background(.regularMaterial)
            .sheet(isPresented: $importingAGY) { AGYImportView(store: store) }

        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2).foregroundStyle(.mint)
                .frame(width: 40, height: 40)
                .background(.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("AIbar").font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("你的 AI 额度，一眼掌握").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("SUBSCRIPTIONS").font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5).foregroundStyle(.tertiary)
        }
    }

    private var providerPicker: some View {
        HStack(spacing: 4) {
            ForEach(Provider.allCases) { provider in
                Button {
                    store.selected = provider
                    Task { await store.refresh() }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: provider.symbol).font(.system(size: 18, weight: .medium))
                        Text(provider.name).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(store.selected == provider ? provider.tint : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(store.selected == provider ? provider.tint.opacity(0.12) : .clear,
                                in: RoundedRectangle(cornerRadius: 13))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(store.selected == provider ? [.isSelected] : [])
            }
        }.padding(5).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 17))
    }

    private func accountCard(_ account: AccountUsage, index: Int, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(account.provider == .antigravity ? "Antigravity · 模型额度" : "\(account.provider.name) · 账户 \(index + 1)")
                        .font(.system(size: 15, weight: .semibold))
                    Text(account.plan.flatMap { $0.isEmpty ? nil : $0.capitalized } ?? "Coding Plan")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(account.provider == .antigravity ? (account.manual ? "粘贴导入" : "CLI 查询") : account.manual ? "手动记录" : account.isStale(at: now) ? "需更新" : "缓存读数")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(store.selected.tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(store.selected.tint)
            }
            if account.windows.isEmpty {
                Text("来源未返回额度窗口").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(account.windows) { window in
                windowRow(window, now: now)
            }
            HStack(spacing: 5) {
                Image(systemName: account.manual ? "pencil" : "clock")
                Text(account.provider == .antigravity ? (account.manual ? "导入于" : "查询于") : account.manual ? "记录于" : "源数据更新于")
                Text(account.readAt, style: .relative)
                if account.isStale(at: now) { Text("· 请刷新来源").foregroundStyle(.orange) }
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(store.selected.tint.opacity(0.25), lineWidth: 1))
    }

    private func windowRow(_ window: UsageWindow, now: Date) -> some View {
        let color: Color = window.used >= 90 ? .red : window.used >= 65 ? .orange : .mint
        let formattedUsed = window.used.formatted(.number.precision(.fractionLength(0...1)))
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(window.name.replacingOccurrences(of: "5 hours", with: "5 小时窗口")
                    .replacingOccurrences(of: "7 days", with: "7 天窗口"))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("已用 \(formattedUsed)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.07))
                    Capsule().fill(color.gradient).frame(width: geometry.size.width * min(max(window.used, 0), 100) / 100)
                }
            }.frame(height: 7)
                .accessibilityLabel("\(window.name)，已用 \(formattedUsed)%")
            if let reset = window.resetsAt {
                HStack(spacing: 3) {
                    if reset <= now {
                        Text("重置时间已过 · 等待新读数").foregroundStyle(.orange)
                    } else {
                        Text(reset, style: .relative)
                        Text("后重置 ·")
                        Text(reset, format: .dateTime.month(.twoDigits).day().hour().minute())
                    }
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("重置时间未知").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.selected.symbol).font(.system(size: 30)).foregroundStyle(store.selected.tint)
            Text("尚无 \(store.selected.name) 读数")
                .font(.headline)
            Text(store.selected == .antigravity ? "点击「检查 AGY 用量」，AIbar 会自动调用本机 agy 查询。首次需要选择工作目录；若 CLI 要求登录，再完成认证。"
                 : "请先在 Magpie 中刷新此订阅的额度。AIbar 会读取本机缓存。")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if store.selected == .antigravity {
                Button("检查 AGY 用量", systemImage: "arrow.clockwise") { checkAGYUsage() }
                    .buttonStyle(.bordered).disabled(store.isRefreshingAGY)
            } else {
                Button("打开 \(store.selected.name)", systemImage: "arrow.up.right") { store.openWebsite() }
                    .buttonStyle(.bordered)
            }
        }.padding(.vertical, 26).padding(.horizontal, 22).frame(maxWidth: .infinity)
    }

    private func checkAGYUsage() {
        if !store.hasAGYWorkingDirectory && !store.chooseAGYWorkingDirectory() { return }
        Task { await store.queryAGY() }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(store.selected == .antigravity ? (store.agy?.manual == true ? "导入时间不代表源数据时间 · 重置时间按导入时刻估算" : "agy /usage · 失败后暂停自动查询 · 已用 = 100% − 剩余") : "只读 Magpie 缓存 · 每分钟检查 · 不读取密钥")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            HStack {
                Button {
                    if store.selected == .antigravity {
                        checkAGYUsage()
                    } else {
                        Task { await store.refresh() }
                    }
                } label: {
                    Label(store.isRefreshing ? "读取中…" : store.selected == .antigravity ? "检查 AGY 用量" : "重读缓存", systemImage: "arrow.clockwise")
                }.disabled(store.isRefreshing).help("AGY 可能要求浏览器登录；失败后暂停自动查询，成功后每 5 分钟刷新")
                Spacer()
                Menu {
                    Button("选择 Magpie 缓存…") { store.chooseSource() }
                    Button("选择 AGY 工作目录…") { store.chooseAGYWorkingDirectory() }
                    Button("打开订阅页面") { store.openWebsite() }
                    Divider()
                    Button("退出 AIbar") { NSApplication.shared.terminate(nil) }
                } label: { Image(systemName: "gearshape") }
                .menuStyle(.borderlessButton).fixedSize().help("设置")
            }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }
}

struct AGYImportView: View {
    let store: UsageStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导入 Antigravity usage").font(.headline)
            Text("复制 agy 的 usage 输出。98% remaining 会显示为 2% 已用；请使用刚查询的结果。")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.system(size: 11, design: .monospaced))
                .frame(height: 240).border(.secondary.opacity(0.2))
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("导入") {
                    do { try store.importAGY(text); dismiss() }
                    catch { self.error = "未识别用量，请粘贴包含模型组标题、窗口和百分比的完整 usage 文本。" }
                }.disabled(text.isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 430)
    }
}

