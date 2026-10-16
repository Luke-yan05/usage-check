import Foundation
import Observation
import WebKit

struct Organization: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
@Observable
final class ProviderSession: NSObject {
    let provider: Provider
    @ObservationIgnored let webView: WKWebView
    private(set) var snapshot: UsageSnapshot?
    private(set) var isRefreshing = false
    private(set) var isLoadingPage = false
    private(set) var message: String?
    private(set) var organizations: [Organization] = []
    var organizationID: String {
        didSet {
            UserDefaults.standard.set(organizationID, forKey: organizationKey)
            if oldValue != organizationID {
                generation += 1
                snapshot = nil
                lastAttempt = nil
                UserDefaults.standard.removeObject(forKey: cacheKey)
            }
        }
    }
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var retryAt: Date?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var readAfterLoad = false
    private var cacheKey: String { "headroom.\(provider.rawValue).snapshot" }
    private var organizationKey: String { "headroom.\(provider.rawValue).organization" }

    init(provider: Provider) {
        self.provider = provider
        organizationID = UserDefaults.standard.string(forKey: "headroom.\(provider.rawValue).organization") ?? ""
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: provider.storageID)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(UsageSnapshot.self, from: data), cached.provider == provider {
            snapshot = cached
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func openUsagePage() {
        webView.load(URLRequest(url: provider.usageURL))
    }

    func refreshSavedSession() async {
        guard snapshot != nil else { return }
        if webView.url?.host == provider.host && !webView.isLoading {
            await refresh(automatically: true)
        } else if !webView.isLoading {
            readAfterLoad = true
            openUsagePage()
        }
    }

    func refresh(automatically: Bool = false) async {
        guard !isRefreshing else { return }
        let now = Date()
        if let retryAt, retryAt > now {
            if !automatically {
                message = "The provider asked us to wait. Try again after \(retryAt.formatted(date: .omitted, time: .shortened))."
            }
            return
        }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < 30 {
            if !automatically { message = "Please wait 30 seconds between usage checks." }
            return
        }
        guard webView.url?.scheme == "https", webView.url?.host == provider.host, !webView.isLoading else {
            message = "Open the usage page, finish signing in, then tap Read usage."
            return
        }
        isRefreshing = true
        lastAttempt = now
        let requestGeneration = generation
        let selectedOrganization = organizationID
        defer { isRefreshing = false }
        do {
            guard let scriptURL = Bundle.main.url(forResource: "ReadUsage", withExtension: "js") else {
                throw SessionFailure.missingScript
            }
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
            let result = try await webView.callAsyncJavaScript(script,
                arguments: ["provider": provider.rawValue, "organizationID": selectedOrganization],
                in: nil, contentWorld: .defaultClient)
            guard requestGeneration == generation else { return }
            guard let text = result as? String, let data = text.data(using: .utf8),
                  let reply = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw UsageParseError.unexpectedResponse
            }
            if let choices = reply["organizations"] {
                organizations = try JSONDecoder().decode([Organization].self, from: JSONSerialization.data(withJSONObject: choices))
            }
            if let error = reply["error"] as? String {
                if error == "rateLimited" {
                    retryAt = Date().addingTimeInterval((reply["retryAfter"] as? Double) ?? 60)
                }
                message = Self.message(for: error)
                return
            }
            guard let payload = reply["payload"] as? [String: Any] else { throw UsageParseError.unexpectedResponse }
            let parsed = try UsageParser.parse(JSONSerialization.data(withJSONObject: payload), provider: provider)
            if let selected = reply["selectedOrganizationID"] as? String { organizationID = selected }
            snapshot = parsed
            message = nil
            retryAt = nil
            let cache = try JSONEncoder().encode(parsed)
            UserDefaults.standard.set(cache, forKey: cacheKey)
        } catch {
            guard requestGeneration == generation else { return }
            message = error is UsageParseError || error is SessionFailure
                ? error.localizedDescription : "Couldn’t read usage. Check your connection and reopen the provider’s usage page."
        }
    }

    func disconnect() async {
        generation += 1
        readAfterLoad = false
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        snapshot = nil
        organizationID = ""
        organizations = []
        message = nil
        lastAttempt = nil
        retryAt = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        await webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }

    private static func message(for code: String) -> String {
        switch code {
        case "signedOut", "wrongOrigin": "Finish signing in on the provider’s website, open its usage page, then tap Read usage."
        case "accessBlocked": "The provider blocked this request. Open its usage page to complete any verification. Embedded sign-in may be unsupported for your account."
        case "chooseOrganization": "Choose your Claude workspace below, then tap Read usage again."
        case "noOrganization": "No Claude chat workspace was found for this account."
        case "rateLimited": "Too many checks. Wait before trying again; your last reading is still shown."
        case "timeout": "The usage check timed out. Check your connection and try again."
        case "serverError": "The provider is temporarily unavailable. Try again later."
        default: "The website’s usage interface could not be read. Open its usage page to check your account."
        }
    }
}

private enum SessionFailure: LocalizedError {
    case missingScript
    var errorDescription: String? { "The usage reader is missing from the app. Rebuild with ReadUsage.js in Copy Bundle Resources." }
}

extension ProviderSession: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoadingPage = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoadingPage = false
        if readAfterLoad && webView.url?.host == provider.host {
            readAfterLoad = false
            Task { await refresh(automatically: true) }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoadingPage = false
        if (error as NSError).code != NSURLErrorCancelled { message = "The provider’s page couldn’t load. Check your connection and try again." }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoadingPage = false
        message = "The provider’s page couldn’t finish loading."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // HTTPS login redirects may go to the user's identity provider. Never run our reader there.
        let url = navigationAction.request.url
        return url?.scheme == "https" || url?.absoluteString == "about:blank" ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, navigationAction.request.url?.scheme == "https" {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
