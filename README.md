# StreamShelf iOS

A SwiftUI + WKWebView starter app for opening movie/series URLs from HD-Repka and Seasonvar.

## Open in Xcode
1. Unzip the archive on a Mac.
2. Open `StreamShelf.xcodeproj`.
3. In Signing & Capabilities, change the Bundle Identifier and select your Apple Developer team.
4. Run on an iPhone or simulator (iOS 16+).

## Included
- Paste a film/episode page URL (no search).
- Local global viewing history.
- Automatically reopen the last watched page.
- Best-effort save of HTML5 video position and title/season/episode metadata.
- Detect embedded iframe players and offer a player picker.
- Stored audio/quality preferences.
- Best-effort popup/ad reduction.

## Important limitations
- iOS WebKit's same-origin security rules mean the app cannot read playback time from many third-party iframe players. In those cases it can save the page/player URL, but exact time may not be available.
- Season/episode detection is heuristic, based on page title and URL.
- Audio language and quality are preferences only. Each embedded player controls its own audio/quality settings; the app cannot universally force them.
- Site HTML/player changes can break player detection. Some sites may block embedded playback or require cookies/DRM.
- Ad filtering is best-effort and may interfere with some player scripts. Disable it in Settings if playback fails.

History is stored locally on the iPhone in UserDefaults. No account or cloud sync.
