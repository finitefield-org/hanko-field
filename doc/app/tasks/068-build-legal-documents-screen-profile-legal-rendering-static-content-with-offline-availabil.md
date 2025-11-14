# Build legal documents screen (`/profile/legal`) rendering static content with offline availability.

**Parent Section:** 11. Profile & Settings
**Task ID:** 068

## Goal
Implement `/profile/legal` so users can browse terms/privacy/commercial notices offline with static markdown content.

## Implementation Steps
1. Provide a repository/controller that loads localized legal documents, caches them offline, and exposes last-synced timestamps.
2. Build the screen with an app bar download icon, offline banner, and a document list showing title/summary/version chips.
3. Render markdown/HTML inside an outlined card viewer with a footer button to open the canonical web page.

## Material Design 3 Components
- **App bar:** `Center-aligned top app bar` with `download_for_offline` icon button.
- **Document list:** `ListTile` rows with leading icon avatars and trailing `AssistChip` for version tags.
- **Content viewer:** `Outlined card` containing markdown/HTML renderer with scroll physics.
- **Footer:** `TextButton.icon` to open the selected document in an external browser.
