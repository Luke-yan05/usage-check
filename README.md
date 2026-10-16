# Usage Check

A native iPhone app that displays the remaining **Codex** and **Claude** subscription allowance in one place. It runs on your phone without a Mac companion or an app-owned server.

Codex figures cover coding usage associated with a ChatGPT subscription. They do not represent all conversational ChatGPT limits.

## Features

- Separate provider cards with subscription plan labels when available.
- Remaining percentages, usage windows, and reset times reported by each provider.
- Additional model-specific limits when available.
- Refresh on opening the app and pull to refresh.
- A local cache showing when each reading was fetched.
- Support for light and dark appearance and larger text sizes.
- Independent connections and a disconnect action for each provider.

## Requirements

- An iPhone running iOS 17 or later.
- A Mac with Xcode and iOS platform support to build and install the app.
- An Apple Account for device signing.
- A relevant Codex or Claude subscription and internet access for fresh readings.

The project currently targets iPhone. Native iPad support has not been validated.

## Build and install

1. Download or clone this repository and open `Headroom.xcodeproj` in Xcode.
2. Select the **Headroom** scheme. The installed app is named **Usage Check**.
3. Copy `LocalSigning.xcconfig.example` to `LocalSigning.xcconfig` in the project folder. Replace the placeholders with your Apple development team ID and a unique bundle identifier, such as `com.yourname.usagecheck`. The local file is ignored by Git. You can find your team ID in Xcode's account settings or your Apple developer account.
4. Select your connected iPhone as the run destination. Enable Developer Mode and trust your developer profile if prompted, then click Run. A simulator can be used for initial testing without device signing.
5. Connect Codex or Claude and sign in on the provider's website inside the app. Tap **Read usage**. If Claude offers multiple workspaces, select the workspace to track.

Each person uses their own Apple Account for signing and their own provider accounts. Once installed, the app works without being connected to the Mac. Free Apple Personal Team installations require rebuilding and reinstalling after the provisioning profile expires, normally after seven days.

## Privacy and connections

Each provider has a separate persistent WebKit website data store. Sign-in happens on the provider's own HTTPS website. The app requests usage through that website session; no API billing key is required.

Passwords, cookies, and access tokens are not returned to the native usage reader, logged by it, or saved in the app's preferences. The app stores selected usage readings and the chosen Claude workspace locally. Login sessions remain in WebKit storage. Disconnect clears the selected provider's website data and cached reading from this app.

The app includes no analytics service or app-owned server. Do not commit credentials, personal signing files, or account screenshots to the repository.

## Limitations

Usage is read through provider website interfaces rather than a documented public subscription-usage API. Website changes, embedded-browser restrictions, and some sign-in methods can prevent reading. Verify important readings on the provider's official usage page.

There is no continuous background polling. Readings older than 15 minutes or followed by a failed refresh are marked as a last reading. After a reset time passes, the percentage remains unknown until a successful refresh. Requests have a minimum 30-second interval, with additional cooldown after rate limiting.

This is an independent project and is not affiliated with OpenAI or Anthropic.

## Development

Run the local checks with Xcode selected:

```sh
swift test
node Tests/reader-tests.mjs
xcodebuild -project Headroom.xcodeproj -scheme Headroom \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

See [Testing](TEST-RESULTS.md) for coverage and remaining integration checks.

## Acknowledgments

The [CodexBar project](https://github.com/steipete/CodexBar) was a reference for provider website request formats. Usage Check uses an independent implementation and has no CodexBar dependency.
