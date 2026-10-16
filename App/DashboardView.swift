import SwiftUI

@MainActor
struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var codex = ProviderSession(provider: .codex)
    @State private var claude = ProviderSession(provider: .claude)
    @State private var selected: Provider?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DashboardHeader()
                    ProviderCard(session: codex, connect: { selected = .codex })
                    ProviderCard(session: claude, connect: { selected = .claude })
                    Label("Private to your iPhone", systemImage: "lock.shield")
                        .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 6)
                    Text("Readings refresh when you open the app or pull down. Your Mac can stay off.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(20).frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.pageBackground)
            .navigationTitle("Usage Check")
            .refreshable { await refreshSaved() }
            .sheet(item: $selected) { provider in
                ConnectionView(session: provider == .codex ? codex : claude)
            }
            .task { await refreshSaved() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshSaved() } }
            }
        }
        .tint(.codexTint)
    }

    private func refreshSaved() async {
        await codex.refreshSavedSession()
        await claude.refreshSavedSession()
    }
}

private struct DashboardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A little room\nto keep going.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Your coding limits, together.")
                .font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
}

extension Color {
    static let codexTint = Color(red: 0.08, green: 0.55, blue: 0.44)
    static let claudeTint = Color(red: 0.74, green: 0.36, blue: 0.24)
    #if os(iOS)
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    #else
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    #endif
}

extension Provider {
    var tint: Color { self == .codex ? .codexTint : .claudeTint }
    var symbol: String { self == .codex ? "terminal" : "sparkle" }
}
