# Testing

## Automated checks

- Swift XCTest coverage includes remaining-usage calculations, expired readings, missing or invalid data, reset timestamps, additional quotas, and cache round-tripping.
- Mocked JavaScript checks cover successful reads, the Codex authentication retry, exact-origin restrictions, Claude workspace selection, plan metadata handling, field filtering, rate limits, and access blocks.
- Test fixtures use synthetic data and do not require provider credentials.

Run instructions are in the [README](README.md#development).

## Integration checks

Simulator checks have covered live provider reads, session persistence across app restarts and updates, foreground refresh, cooldown behavior, light and dark appearance, and larger text sizes. These checks do not guarantee compatibility with every account, sign-in method, device, or future provider website change.

Multiple-workspace switching and Disconnect against a real account still need end-to-end validation. iPad layouts have not been validated. Device installation requires each developer's own signing configuration.

When reporting an issue, describe the steps and observed behavior. Remove account details, workspace names, credentials, and private usage information from any logs or screenshots.
