#if os(macOS)
import AppKit

/// Prepares the window for a screenshot taken from outside: sizes and places it, brings it
/// to the front so the title bar is in its active colors, and writes its window number to
/// the file named by `-QuillSnapshot <path>`. The caller captures that window with
/// `screencapture -l` and then quits the app. Used by Scripts/screenshots.sh.
@MainActor
enum WindowSnapshot {
    static let size = CGSize(width: 1400, height: 900)

    static func prepare(reportingTo path: String) {
        Task { @MainActor in
            func mainWindow() -> NSWindow? {
                NSApp.windows.filter { $0.isVisible && !($0 is NSPanel) }
                    .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            }
            for _ in 0..<100 where mainWindow() == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard let window = mainWindow() else { exit(2) }
            window.setContentSize(size)
            if let screen = window.screen ?? NSScreen.main {
                let area = screen.visibleFrame
                window.setFrameTopLeftPoint(NSPoint(x: area.minX + 40, y: area.maxY - 10))
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .seconds(2.5))
            try? "\(window.windowNumber)".write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
#endif
