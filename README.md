# Usage Check

Originally called Headroom, this app now appears as **Usage Check** on the iPhone and on its dashboard. The existing Xcode project remains `Headroom.xcodeproj`; its app identity and signing settings are preserved so updating the app retains your data.

A small, native iPhone prototype for seeing the remaining **Codex** and **Claude** subscription allowance in one place. It runs on the iPhone alone; no Mac companion or hosted service is required by the design.

**Status: simulator tested with both accounts.** On October 16, 2026, Headroom built successfully with Xcode 27.1 for the iPhone simulator and as an unsigned release for iPhone hardware. All seven XCTest cases and all fifteen mocked JavaScript reader checks passed. Live Codex and Claude reads both succeeded and were compared with the providers' usage pages. Saved sessions survived app restarts and app updates, and automatic foreground refresh worked. Dark mode and accessibility text sizes were reviewed; two issues found in testing were fixed and verified. See `TEST-RESULTS.md`. Code signing and physical-device validation remain to be done; no app has been installed on a physical iPhone.

## Run on your iPhone

1. Install the full Xcode app from Apple, open it once, and install iOS platform support.
2. Open `Headroom.xcodeproj` in Xcode. Select the **Headroom** scheme.
3. In **Signing & Capabilities**, choose your development team and replace `com.example.Headroom` with a unique bundle identifier.
4. Select an iPhone running iOS 17 or newer, enable Developer Mode if prompted, and run the app. A simulator can be used for initial layout checks.
5. Tap **Connect Codex**, sign in directly on the ChatGPT website, navigate to the Codex usage page, then tap **Read usage**.
6. Repeat for Claude. If more than one Claude workspace appears, explicitly select the one to track and read again.

Connecting to a provider is optional; the other card works independently. No API billing key is needed for this website-session approach.

## What it does

- Separate Codex and Claude cards, with plan names read from provider metadata and a remaining percentage for each reported quota window.
- Session and weekly windows, plus model-specific windows when reported.
- Actual provider reset dates and relative time until reset.
- A local cache with the time the reading was fetched.
- Refresh when the app becomes active and by pulling down; no continuous background polling.
- A minimum 30-second interval between attempts, and a cooldown for HTTP 429 responses.
- Explicit errors for missing data, sign-in requirements, blocked access, and network problems.
- A disconnect action that clears the selected provider's website data and cached reading from this app.
- Native layout that follows the system's light/dark appearance and text size.

Codex is specifically the coding allowance associated with your ChatGPT subscription. The app does not treat it as a measure of every model's conversational ChatGPT allowance.

## How the connection works

Each provider has a persistent, separate WebKit website data store. The user signs in on the provider's own HTTPS website. The app executes a short, read-only script in an isolated WebKit content world, restricted to that provider's exact origin.

The reader uses the website session to request usage. For Codex, it first attempts a cookie-authenticated usage request. If that returns 401, it obtains the website session's short-lived access token and retries within WebKit. Passwords, cookies, and that access token are never returned to Swift, printed, or copied into the app's preferences. Only selected usage fields, a plan label, and Claude workspace identifiers/names cross the bridge. Usage readings and the selected Claude workspace are stored in the app's local preferences; provider login sessions stay in WebKit's storage. The app includes no analytics service or app-owned server.

This uses **website interfaces, not a documented public iPhone subscription-usage API**. The provider can change those interfaces or block embedded browsers. Some Google/Apple/SSO sign-in flows and bot-verification pages may not work in WebKit. Those cases require testing with your accounts; the prototype does not bypass verification or promise that every login method works. If a provider blocks embedded access, an alternative supported authentication method will be needed before the app can be considered functional for that account.

Numbers older than 15 minutes or followed by a failed check are labeled as a last reading. After a window's reset time passes, its percentage becomes unknown until a successful new reading; the app never assumes it has returned to 100%.

## Validate

With full Xcode selected:

```sh
swift test
xcodebuild -project Headroom.xcodeproj -scheme Headroom \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
node Tests/reader-tests.mjs
```

The XCTest file has seven cases for calculations, malformed/missing data, timestamps, additional quotas, and cache round-tripping. All seven now pass using the actual XCTest framework in Xcode 27.1. The fifteen JavaScript checks run without provider credentials and cover successful reads, the token retry, origin restrictions, workspace selection, field filtering, rate limits, and access blocks. The mocked checks alone do not establish live service compatibility; a separate live Codex request succeeded in the iOS simulator.

Before relying on it on a physical iPhone, choose your signing team and validate the same sign-in and usage flows on that device. Workspace switching (if applicable) and clearing a real session with Disconnect remain additional integration checks. Never put real credentials in fixtures or screenshots.

## Sources and installed skills

Website request shapes were inspected in the original [CodexBar source](https://github.com/steipete/CodexBar), commit `a91669f2ff972ac2a549ed8c20725fdc1a510194`, specifically its Codex usage fetcher, OpenAI website session reader, and Claude website usage fetcher. Headroom uses a small independent implementation, with no CodexBar dependency.

Official context: [Codex account rate limits](https://learn.chatgpt.com/docs/app-server) and [Claude usage windows](https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work). The documented Codex desktop app-server and Claude Code status-line integrations are different from the website interfaces used by this iPhone prototype.

Five skills from [Dimillian/Skills](https://github.com/Dimillian/Skills) were installed in your personal Codex skills folder and become available on your next turn:

- `swiftui-ui-patterns`
- `swiftui-view-refactor`
- `swift-concurrency-expert`
- `swiftui-liquid-glass`
- `swiftui-performance-audit`

The UI uses the patterns and view-composition guidance. Liquid Glass and performance-audit skills are available for later work; the app relies on standard SwiftUI controls and supports iOS 17+.

Claude plan labels are read from `/api/account` and matched to the selected workspace. Plan metadata is optional: unavailable or unrecognized metadata leaves a generic label while usage continues to work. The live simulator check confirmed **Pro** for the signed-in Claude account.

## App icon

The teal and terracotta gauge icon is included in `App/Assets.xcassets/AppIcon.appiconset` and selected for both Debug and Release builds. The source is an opaque 1024 × 1024 RGB PNG; the simulator and iPhone Release builds both compile it successfully. To update the icon on an already installed iPhone copy, select your phone and Run the project again. Generation details and the exact ImageGen prompt are in `ICON-DESIGN.md`.
