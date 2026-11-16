# Quill

A native mail client for iPhone, iPad and Mac, built with SwiftUI.

## Requirements

Xcode 26 or later. The app targets iOS 26 and macOS 26.

## Running

Open `Quill.xcodeproj` and run the `Quill` scheme on a simulator, a device or My Mac.

The app currently runs on the sample mailbox from the design mockups. Mail access goes
through the `MailService` protocol, so a Gmail implementation can replace
`SampleMailService` without touching the interface.

## Layout

| Path | Contents |
| --- | --- |
| `App/` | The app target: the entry point, icon and entitlements. |
| `QuillKit/Sources/QuillKit/Core/` | Models, sectioning, search, the mail service and `MailStore`. No SwiftUI. |
| `QuillKit/Sources/QuillKit/Design/` | Design tokens: colors, type roles, spacing, radius and motion. |
| `QuillKit/Sources/QuillKit/Components/` | Reusable views such as `MailRow`, `PinnedCard` and `MonogramAvatar`. |
| `QuillKit/Sources/QuillKit/Features/` | Screens, grouped by feature. `Root/` chooses the phone or wide layout. |
| `QuillKit/Tests/` | Unit tests for the models, logic and store. |
| `UITests/` | Navigation tests, and screenshot tests for each mockup screen. |
| `Design/Icon/` | Icon sources. `node Scripts/render-icons.cjs` renders them into the asset catalog. |

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

The screenshot tests launch the app with `-QuillScreen <inbox|thread|search|compose|mailboxes|zero>`
and `-QuillAppearance <light|dark>`, which loads the mockup's mailbox frozen at the moment
the mockups show. CI runs everything on each push and uploads the screenshots as an artifact.
