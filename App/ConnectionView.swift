import SwiftUI
import WebKit

@MainActor
struct ConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: ProviderSession
    @State private var confirmingDisconnect = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sign in directly at \(session.provider.host). Once your usage page loads, tap Read usage.")
                        .font(.footnote)
                    Text("Website sessions stay in this app. The dashboard saves only usage readings. Some sign-in providers may block embedded browsers.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let message = session.message {
                        Text(message).font(.caption).foregroundStyle(.orange)
                    }
                    if session.organizations.count > 1 {
                        Picker("Claude workspace", selection: $session.organizationID) {
                            Text("Choose workspace").tag("")
                            ForEach(session.organizations) { organization in
                                Text(organization.name).tag(organization.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }.padding(16)
                Divider()
                ProviderBrowser(webView: session.webView)
                    .overlay(alignment: .top) {
                        if session.isLoadingPage { ProgressView().padding(8).background(.regularMaterial, in: Capsule()) }
                    }
                Divider()
                HStack {
                    Button("Usage page", systemImage: "arrow.clockwise", action: session.openUsagePage)
                    Spacer()
                    Button(action: readUsage) {
                        if session.isRefreshing { ProgressView().padding(.horizontal) }
                        else { Text("Read usage").fontWeight(.semibold) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(session.isRefreshing || session.isLoadingPage)
                }.padding(16)
            }
            .navigationTitle("Connect \(session.provider.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Disconnect", role: .destructive) { confirmingDisconnect = true }
                        .disabled(session.isRefreshing)
                }
            }
            .confirmationDialog("Remove this app’s \(session.provider.title) session and saved reading?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive, action: disconnect)
            }
            .onAppear {
                if session.webView.url?.host != session.provider.host { session.openUsagePage() }
            }
        }
        .tint(session.provider.tint)
        .interactiveDismissDisabled(session.isRefreshing)
    }

    private func readUsage() {
        Task { await session.refresh() }
    }

    private func disconnect() {
        Task {
            await session.disconnect()
            dismiss()
        }
    }
}

#if os(iOS)
private struct ProviderBrowser: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#else
private struct ProviderBrowser: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
