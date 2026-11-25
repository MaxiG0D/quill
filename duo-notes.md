# iPhone Duo redesign notes
Journey: Inbox (InboxScreen) -> Thread (ThreadScreen / ThreadPane) -> Compose sheet; Mailboxes sheet on the way
Stack: SwiftUI only, iOS 26 target, Xcode 27.2 / iPhoneOS27.2 SDK (Duo toolbar APIs present); no Duo simulator listed
Stage: 3  Next: wait for user choices on the Stage 3 table, then Stage 4

## Findings
- RootView: size class (compact -> stack, else 3-col split), selection carried across — Ready [HIG, T461]
- No UIScreen / idiom / breakpoints / fixed widths / UIRequiresFullScreen; ignoresSafeArea only on backgrounds — Ready [T461]
- BottomSearchBar (search + Compose) custom bar in safeAreaInset — Change/Decision [T462]
- ReplyBar custom bottom bar in ThreadScreen — Change/Decision [T462]
- ComposeHeader (Cancel/title/Send) and FormatBar custom bars in the sheet; MailboxesSheet custom Close — Change/Decision [T462, T466]
- InboxScreen avatar toolbar item has no title+symbol Label — Change [HIG]
- ThreadScreen "More" menu uses ellipsis, not overflow — Change [HIG]
- SplitToolbar: ToolbarSpacer(.fixed); no visibility priority — Change [HIG]
- Split view forced to .all columns on inner display — Decision [T466]
- Floating ComposeButton over iPad list — Decision [HIG]
- No custom side-by-side/overlay layouts, no camera: ArrangementView, camera N/A
- Ready: size classes, ThreadConversation/Document (scrolling, may cross fold), orientations, sheets/menus; N/A: camera, hinge, scene accessories

## Decisions
- (pending, see Stage 3 table in chat)

## Done / verified
- nothing changed yet; assessment is code-only (not run in simulator)
