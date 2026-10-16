# Usage Check test results

Test date: October 16, 2026 (America/Los_Angeles).

## Passed

- Xcode 27.1 (27A9275), final simulator Debug build for iPhone 18 Pro running iOS 27.0.
- Final Release build for generic iPhone hardware, with code signing disabled. Nothing was installed on a physical iPhone.
- Seven XCTest cases, zero failures: quota calculations, expired readings, missing/null windows, invalid percentages, Claude dates and fractional values, additional Codex limits, and cache encoding/decoding. The calculation code was unchanged by the simulator fixes.
- Fifteen mocked JavaScript reader checks: normal fetch, bearer retry, exact-origin restriction, Claude workspace choice, field filtering, HTTP 429, and HTTP 403. The suite also verifies Pro and legacy Pro metadata, Max and Team labels, unknown-plan fallback, exact workspace matching, privacy filtering, and keeping usage available when plan lookup fails.
- Live Codex subscription usage read succeeded. Its official usage page showed 75% remaining for the five-hour window and 91% for the week when compared; those values matched the dashboard reading at that point.
- Live Claude subscription usage read succeeded. Its official usage page showed 40% used for the session and 15% used for the week when compared; Headroom correctly showed 60% and 85% remaining. These are time-specific observations, not fixed data. Later automatic refreshes retrieved newer values.
- Both readings and website sessions survived process termination/relaunch and installing app updates over the simulator copy.
- Automatic refresh updated both timestamps and readings after cold launch and after returning from another simulator app.
- A quick return within the 30-second cooldown was tested again after the correction below; no false warning appeared.
- Claude sign-in page loads inside the app. Reading while signed out shows an error and no fabricated percentage.
- Dashboard visually reviewed in light and dark appearance, with standard Large text and Accessibility Large text. Original simulator appearance and text-size settings were restored.

## Fixes made and verified

1. At accessibility text sizes, quota names and remaining percentages now stack vertically. Reset dates now wrap as one continuous sentence instead of separate fragments. The corrected layout was inspected in the running simulator.
2. Automatic foreground refresh now skips its cooldown quietly. Previously, returning to the app too quickly showed a wait message and incorrectly marked a fresh reading as needing confirmation. Manual Read usage requests still explain the cooldown. The failing quick-return scenario was repeated successfully after the fix.

Both final simulator and iPhone Release configurations build successfully after these changes. The only compiler warning was Apple's App Intents metadata step noting that the app does not use AppIntents.framework. No Swift compilation warnings or errors occurred in the final successful builds.

3. Claude now reads its subscription plan from account metadata, matches it to the selected workspace, and returns only the resulting plan label. A live simulator check confirmed **Pro** below Claude while Codex still showed **Plus**. Unknown or unavailable plan metadata retains the generic label without losing usage. Both simulator and iPhone Release builds passed with this change.

## Remaining scope

- Select a development team, sign the app, and validate on the actual iPhone.
- Multiple-Claude-workspace switching and Disconnect against a real signed-in account have not been exercised end to end; your working sessions were preserved.
- Layout was reviewed on one simulated iPhone model and two text sizes, not every supported device/OS combination.
- The connection uses provider website interfaces. Passing with these accounts today does not guarantee that every login method or a future website revision will behave the same way.

The app is ready for an initial personal-device test, subject to signing. It is not an App Store release.

## Icon validation

Added the generated 1024 × 1024 opaque RGB app icon, confirmed both build configurations select the AppIcon asset, built the simulator and iPhone Release configurations, and verified that both compiled Info.plist files identify AppIcon as the primary icon. The icon-only update has not been installed on the physical iPhone; Run from Xcode to update it.

## Usage Check name

Updated the dashboard title and the Home Screen display name to Usage Check. Both simulator and iPhone Release builds passed. Verified the compiled display name and preserved bundle identifier in both configurations. The existing icon and signing settings are unchanged. Run from Xcode to update the installed iPhone copy.
