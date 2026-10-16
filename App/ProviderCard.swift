import SwiftUI

@MainActor
struct ProviderCard: View {
    let session: ProviderSession
    let connect: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: session.provider.symbol)
                        .font(.title2.weight(.semibold)).foregroundStyle(session.provider.tint)
                        .frame(width: 46, height: 46)
                        .background(session.provider.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.provider.title).font(.title3.bold())
                        Text(session.snapshot?.plan?.capitalized ?? session.provider.subtitle)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if session.isRefreshing { ProgressView().controlSize(.small).accessibilityLabel("Checking usage") }
                    Button(action: connect) { Image(systemName: "ellipsis.circle").font(.title3) }
                        .buttonStyle(.plain).accessibilityLabel("Manage \(session.provider.title) connection")
                }
                if let snapshot = session.snapshot {
                    if snapshot.isStale(at: context.date) || session.message != nil {
                        Label("Last reading · refresh to confirm", systemImage: "clock.badge.exclamationmark")
                            .font(.caption.weight(.medium)).foregroundStyle(.orange)
                    }
                    ForEach(snapshot.windows) { window in
                        UsageWindowRow(window: window, tint: session.provider.tint, now: context.date)
                    }
                    Text("Checked \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("See what’s left before your next session.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Connect \(session.provider.title)", action: connect)
                        .buttonStyle(.borderedProminent).tint(session.provider.tint)
                }
                if let message = session.message {
                    Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

private struct UsageWindowRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let window: UsageWindow
    let tint: Color
    let now: Date

    private var amountLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            amountLayout {
                Text(window.title).font(.subheadline.weight(.medium))
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                if let remaining = window.remainingPercent(at: now) {
                    Text("\(remaining, specifier: "%.0f")% left")
                        .font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
                } else {
                    Text("Refresh needed").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            if let remaining = window.remainingPercent(at: now) {
                ProgressView(value: remaining, total: 100)
                    .tint(remaining <= 10 ? Color.orange : tint)
                    .accessibilityLabel("\(window.title), \(Int(remaining.rounded())) percent remaining")
            }
            if let reset = window.resetsAt, reset > now {
                Text("Resets \(reset, style: .relative) · \(reset.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(window.resetsAt == nil ? "Reset time unavailable" : "Reset time passed · check for a new reading")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
