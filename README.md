# Quill

A native mail client for iPhone, iPad and Mac, built with SwiftUI.

## Requirements

Xcode 26 or later. The app targets iOS 26 and macOS 26.

## Running

Open `Quill.xcodeproj` and run the `Quill` scheme on a simulator, a device or My Mac.

Out of the box the app opens the sample mailbox from the design mockups. With a Google
client ID it signs in to Gmail instead.

## Gmail

1. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials), create a
   project and enable the Gmail API.
2. Configure the OAuth consent screen, and add your own Google account as a test user.
3. Create an OAuth client of type iOS with the bundle ID `com.maxig0d.quill`.
4. Paste its client ID into `App/Configuration.swift`.

The same client serves iPhone, iPad and Mac. Sign-in uses the system web sign-in sheet with
PKCE, and the token is kept in the keychain. Quill asks for the `gmail.modify` scope, which
covers reading, filing and sending.

Mail access goes through the `MailService` protocol. `GmailMailService` lists the Inbox, Starred, Drafts, Trash and the newest
100 threads, fetches only those whose history ID changed since the last refresh (40 per pass, to stay inside Gmail's 6,000 quota units a minute), and keeps
the result in `Application Support/Quill/mailbox.json` so the app opens at once and reads
offline. Archive, Trash, star and unread are written back to Gmail. Pins and snoozes have
no Gmail equivalent, so they stay on the device. `SampleMailService` remains for previews,
tests and screenshots.

Not built yet: sending attachments, saving drafts to Gmail, downloading attachments,
rendering HTML mail as HTML (it is shown as text), push notifications, and more than the
newest 100 threads outside search.

## Layout

| Path | Contents |
| --- | --- |
| `App/` | The app target: the entry point, icon and entitlements. |
| `QuillKit/Sources/QuillKit/Core/` | Models, sectioning, search, `MailStore`, Google sign-in (`Google/`) and the Gmail client (`Gmail/`). No SwiftUI. |
| `QuillKit/Sources/QuillKit/Design/` | Design tokens: colors, type roles, spacing, radius and motion. |
| `QuillKit/Sources/QuillKit/Components/` | Reusable views such as `MailRow`, `PinnedCard` and `MonogramAvatar`. |
| `QuillKit/Sources/QuillKit/Features/` | Screens, grouped by feature. `Root/` chooses the phone or wide layout. |
| `QuillKit/Tests/` | Unit tests for the models, logic and store. |
| `UITests/` | Navigation tests, and screenshot tests for each mockup screen. |
| `Screenshots/` | The latest screenshot of each screen, written by CI. |
| `Design/Icon/` | `icons.json` holds each icon's colors. `node Scripts/render-icons.cjs` draws the app icon sets and the picker's previews from it. |

The Xcode project uses synchronized folders, so new files appear in the project as soon
as they are added on disk. One type per file.

## Design tokens

Every color, type role, spacing step and radius comes from the Tokens page of the mockups
and lives in `Design/`. Views use `Palette`, `Spacing`, `Radius`, `Motion` and
`.textRole(_:)` instead of literal values.

## Testing

```sh
xcodebuild test -project Quill.xcodeproj -scheme Quill -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project Quill.xcodeproj -scheme Quill -destination 'platform=macOS'
```

The screenshot tests launch the app with `-QuillScreen <inbox|thread|search|compose|mailboxes|settings|zero>`
and `-QuillAppearance <light|dark>`, which loads the mockup's mailbox frozen at the moment
the mockups show. CI runs everything on each push and commits the latest screenshots to
`Screenshots/` on the branch, so a pull request shows what changed visually.
