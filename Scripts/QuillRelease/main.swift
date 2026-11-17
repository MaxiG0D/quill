// Quill Release: a small front end for Scripts/release-mac.sh (Publish tab) and
// Scripts/screenshots.sh (Screenshots tab). Built by Scripts/build-release-app.sh into
// "Quill Release.app" at the repository root.

import AppKit
import SwiftUI

@main
struct QuillReleaseApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = ReleaseModel()

    var body: some Scene {
        Window("Quill Release", id: "main") {
            ReleaseView()
                .environment(model)
                .frame(minWidth: 560, minHeight: 600)
        }
        .defaultSize(width: 620, height: 740)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Model

struct Step: Identifiable {
    enum State { case running, done, failed }
    let id = UUID()
    let title: String
    var state: State
}

@MainActor @Observable
final class ReleaseModel {
    enum Phase: Equatable { case editing, running, succeeded, failed(String), cancelled }
    enum Tab: String { case publish, screenshots }
    enum Job { case release, screenshots }

    /// The repository: the applet lives at its root. QUILL_ROOT overrides it for testing.
    let rootURL: URL = {
        if let override = ProcessInfo.processInfo.environment["QUILL_ROOT"] {
            return URL(fileURLWithPath: override)
        }
        return Bundle.main.bundleURL.deletingLastPathComponent()
    }()

    private(set) var currentVersion = "?"
    private(set) var currentBuild = 0
    /// Empty keeps the current version's number, which a release can't reuse: it must be higher.
    var version = ""
    var notes = "" { didSet { UserDefaults.standard.set(notes, forKey: "notesDraft") } }
    var publish = true
    var retakeAfterRelease = UserDefaults.standard.bool(forKey: "retakeAfterRelease") {
        didSet { UserDefaults.standard.set(retakeAfterRelease, forKey: "retakeAfterRelease") }
    }

    var screenshotMac = true
    var screenshotIPhone = true
    var screenshotSocial = true
    var commitScreenshots = UserDefaults.standard.bool(forKey: "commitScreenshots") {
        didSet { UserDefaults.standard.set(commitScreenshots, forKey: "commitScreenshots") }
    }

    var tab: Tab = Tab(rawValue: UserDefaults.standard.string(forKey: "tab") ?? "") ?? .publish {
        didSet { UserDefaults.standard.set(tab.rawValue, forKey: "tab") }
    }
    private(set) var job: Job = .release
    private(set) var phase: Phase = .editing
    private(set) var steps: [Step] = []
    private(set) var log = ""
    private(set) var archiveURL: URL?
    private(set) var imagesChangedAt = Date()
    private var process: Process?

    init() {
        notes = UserDefaults.standard.string(forKey: "notesDraft") ?? ""
        reloadCurrentVersion()
    }

    // MARK: Version

    /// The last published release (from GitHub), or the project's own version when offline.
    func reloadCurrentVersion() {
        let project = (try? String(contentsOf: rootURL.appending(path: "Quill.xcodeproj/project.pbxproj"), encoding: .utf8)) ?? ""
        if let range = project.range(of: "MARKETING_VERSION = ") {
            let value = project[range.upperBound...].prefix { $0 != ";" }
            if !value.isEmpty { currentVersion = String(value) }
        }
        Task.detached {
            let tag = Self.output("/opt/homebrew/bin/gh", ["release", "view", "--repo", "MaxiG0D/quill", "--json", "tagName", "-q", ".tagName"], in: self.rootURL)
            let build = Self.output("/usr/bin/git", ["rev-list", "--count", "HEAD"], in: self.rootURL)
            await MainActor.run {
                if let tag, tag.hasPrefix("v") { self.currentVersion = String(tag.dropFirst()) }
                if let build, let number = Int(build) { self.currentBuild = number }
            }
        }
    }

    nonisolated private static func output(_ tool: String, _ arguments: [String], in directory: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum Bump { case patch, minor, major }

    private var currentParts: [Int] {
        let parts = currentVersion.split(separator: ".").compactMap { Int($0) }
        return parts.count == 3 ? parts : [0, 0, 0]
    }

    func bumped(_ bump: Bump) -> String {
        let p = currentParts
        switch bump {
        case .patch: return "\(p[0]).\(p[1]).\(p[2] + 1)"
        case .minor: return "\(p[0]).\(p[1] + 1).0"
        case .major: return "\(p[0] + 1).0.0"
        }
    }

    func isValidVersion(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        return parts.count == 3 && parts.allSatisfy { $0 != nil }
    }

    /// Why the release can't start yet, or nil when it can.
    var problem: String? {
        if version.isEmpty { return "Pick the new version." }
        if !isValidVersion(version) { return "Version must look like 0.2.0." }
        if version == currentVersion { return "\(currentVersion) is already out." }
        return nil
    }

    var screenshotProblem: String? {
        screenshotMac || screenshotIPhone || screenshotSocial ? nil : "Pick at least one image."
    }

    // MARK: Running

    func startRelease() {
        guard problem == nil else { return }
        var environment: [String: String] = [:]
        if !publish { environment["QUILL_DRY_RUN"] = "1" }
        if retakeAfterRelease && publish { environment["SCREENSHOTS"] = "1" }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = FileManager.default.temporaryDirectory.appending(path: "quill-release-notes.md")
            try? notes.write(to: url, atomically: true, encoding: .utf8)
            environment["QUILL_NOTES_FILE"] = url.path
        }
        run(.release, arguments: ["Scripts/release-mac.sh", version], environment: environment)
    }

    func startScreenshots() {
        guard screenshotProblem == nil else { return }
        var arguments = ["Scripts/screenshots.sh"]
        if screenshotMac && screenshotIPhone && screenshotSocial {
            // No argument means everything.
        } else {
            if screenshotMac { arguments.append("mac") }
            if screenshotIPhone { arguments.append("iphone") }
            if screenshotSocial { arguments.append("social") }
        }
        if commitScreenshots { arguments.append("--commit") }
        run(.screenshots, arguments: arguments, environment: [:])
    }

    private func run(_ job: Job, arguments: [String], environment extra: [String: String]) {
        guard phase != .running else { return }
        self.job = job
        steps = []
        log = ""
        pendingLine = ""
        archiveURL = nil
        phase = .running

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = arguments
        process.currentDirectoryURL = rootURL
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        environment.merge(extra) { $1 }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.append(text) }
        }
        process.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = pipe.fileHandleForReading.readDataToEndOfFile()
            let status = finished.terminationStatus
            let reason = finished.terminationReason
            Task { @MainActor in
                guard let self else { return }
                if !rest.isEmpty { self.append(String(decoding: rest, as: UTF8.self)) }
                self.finish(status: status, reason: reason)
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            phase = .failed("Couldn't start \(arguments[0]): \(error.localizedDescription)")
        }
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        phase = .cancelled
        // Stop the children first (xcodebuild, simctl…), or they'd keep running without the script.
        Self.terminateTree(process.processIdentifier)
    }

    private static func terminateTree(_ pid: pid_t) {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-P", String(pid)]
        let output = Pipe()
        pgrep.standardOutput = output
        try? pgrep.run()
        pgrep.waitUntilExit()
        let children = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .split(separator: "\n").compactMap { pid_t($0) }
        children.forEach(terminateTree)
        kill(pid, SIGTERM)
    }

    func reset() {
        phase = .editing
        reloadCurrentVersion()
        if job == .release { version = "" }
    }

    private var pendingLine = ""

    private func append(_ text: String) {
        log += text
        pendingLine += text
        while let newline = pendingLine.firstIndex(of: "\n") {
            let line = String(pendingLine[..<newline])
            pendingLine = String(pendingLine[pendingLine.index(after: newline)...])
            handle(line: line)
        }
    }

    private func handle(line: String) {
        if line.hasPrefix("==> ") {
            if let last = steps.indices.last, steps[last].state == .running { steps[last].state = .done }
            steps.append(Step(title: String(line.dropFirst(4)), state: .running))
        } else if line.hasPrefix("Release archive: ") {
            archiveURL = URL(fileURLWithPath: rootURL.appending(path: String(line.dropFirst("Release archive: ".count))).path)
        }
    }

    private func finish(status: Int32, reason: Process.TerminationReason) {
        process = nil
        if phase == .cancelled {
            if let last = steps.indices.last, steps[last].state == .running { steps[last].state = .failed }
            return
        }
        if status == 0 && reason == .exit {
            if let last = steps.indices.last { steps[last].state = .done }
            phase = .succeeded
            imagesChangedAt = Date()
            if job == .release && publish { notes = "" }
        } else {
            if let last = steps.indices.last { steps[last].state = .failed }
            let lines = log.split(separator: "\n")
            let message = lines.last { $0.hasPrefix("screenshots.sh:") || $0.hasPrefix("error:") }.map(String.init)
                ?? "The script stopped with status \(status). See the log below."
            phase = .failed(message)
        }
    }
}

// MARK: - Views

struct ReleaseView: View {
    @Environment(ReleaseModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.phase != .editing {
                ProgressPanel()
            } else if model.tab == .screenshots {
                ScreenshotsPanel()
            } else {
                PublishPanel()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Quill").font(.title2.bold())
                Text("Version \(model.currentVersion) is the latest release")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Section", selection: Binding(get: { model.tab }, set: { model.tab = $0 })) {
                Text("Publish").tag(ReleaseModel.Tab.publish)
                Text("Screenshots").tag(ReleaseModel.Tab.screenshots)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .disabled(model.phase != .editing)
        }
        .padding(20)
    }
}

struct PublishPanel: View {
    @Environment(ReleaseModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        TextField("Version", text: $model.version, prompt: Text(model.bumped(.patch)))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 120)
                            .labelsHidden()
                        Spacer()
                        Picker("Bump", selection: $model.version) {
                            Text("Fix").tag(model.bumped(.patch))
                            Text("Feature").tag(model.bumped(.minor))
                            Text("Major").tag(model.bumped(.major))
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                } header: {
                    Text("Version")
                } footer: {
                    Text("Builds from the code in this folder, as it is committed. The folder must have no uncommitted changes.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextEditor(text: $model.notes)
                        .font(.body)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                } header: {
                    Text("Release notes (optional)")
                } footer: {
                    Text("Markdown shown on the GitHub release. Left empty, GitHub writes them from the commits since the last release.")
                        .foregroundStyle(.secondary)
                }

                Section("Publish") {
                    Toggle(isOn: $model.publish) {
                        Text("Notarize and publish to GitHub")
                        Text(model.publish ? "Installed copies get the update on their next check" : "Dry run: build and export only")
                    }
                    Toggle(isOn: $model.retakeAfterRelease) {
                        Text("Retake the README screenshots afterwards")
                        Text("Leaves the new images uncommitted for you to review")
                    }
                    .disabled(!model.publish)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if let problem = model.problem {
                    Label(problem, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(model.publish ? "Build and Publish \(model.version)" : "Build") { model.startRelease() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.problem != nil)
            }
            .padding(16)
        }
    }
}

struct ScreenshotsPanel: View {
    @Environment(ReleaseModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: $model.screenshotMac) {
                        Text("Mac")
                        Text("hero.png and mac-dark.png, from the app's window")
                    }
                    Toggle(isOn: $model.screenshotIPhone) {
                        Text("iPhone")
                        Text("iphone.png, from the Harmony iPhone simulator")
                    }
                    Toggle(isOn: $model.screenshotSocial) {
                        Text("Social preview")
                        Text("docs/social-preview.png, the repository's link image")
                    }
                } header: {
                    Text("Images")
                } footer: {
                    Text("Retaken from the sample mailbox in the code in this folder, never from real mail. The Mac shots need Screen Recording allowed for this app.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle(isOn: $model.commitScreenshots) {
                        Text("Commit and push to main")
                        Text("Off: the images are left in the folder for you to review first")
                    }
                }

                Section("Current images") {
                    Previews().id(model.imagesChangedAt)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if let problem = model.screenshotProblem {
                    Label(problem, systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.commitScreenshots ? "Retake and Commit" : "Retake Screenshots") { model.startScreenshots() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.screenshotProblem != nil)
            }
            .padding(16)
        }
    }
}

struct Previews: View {
    @Environment(ReleaseModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            ForEach(["docs/screenshots/hero.png", "docs/screenshots/iphone.png", "docs/social-preview.png"], id: \.self) { path in
                if let image = NSImage(contentsOf: model.rootURL.appending(path: path)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onTapGesture { NSWorkspace.shared.open(model.rootURL.appending(path: path)) }
                        .help(path)
                }
            }
        }
        .frame(height: 70)
    }
}

struct ProgressPanel: View {
    @Environment(ReleaseModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            outcome

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.steps) { step in
                    HStack(spacing: 10) {
                        icon(for: step.state).frame(width: 18)
                        Text(step.title)
                            .foregroundStyle(step.state == .failed ? .red : .primary)
                    }
                }
            }

            LogView(text: model.log)
                .frame(minHeight: 180, idealHeight: 360, maxHeight: .infinity)
                .layoutPriority(-1)

            HStack {
                if model.phase == .running {
                    Spacer()
                    Button("Cancel", role: .cancel) { model.cancel() }
                } else {
                    if let archive = model.archiveURL {
                        Button("Show Exported App") { NSWorkspace.shared.activateFileViewerSelecting([archive]) }
                    }
                    if model.phase == .succeeded && model.job == .release && model.publish {
                        Button("Open Release on GitHub") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/MaxiG0D/quill/releases/latest")!)
                        }
                    }
                    if model.phase == .succeeded && (model.job == .screenshots || model.retakeAfterRelease) {
                        Button("Show Images") {
                            NSWorkspace.shared.activateFileViewerSelecting([model.rootURL.appending(path: "docs/screenshots")])
                        }
                    }
                    Spacer()
                    Button(model.phase == .succeeded ? "Done" : "Back") { model.reset() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder private var outcome: some View {
        switch model.phase {
        case .running:
            Label(runningTitle, systemImage: "hammer").font(.headline)
        case .succeeded:
            Label(successTitle, systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        case .cancelled:
            Label(model.job == .release ? "Cancelled. If it already said \"Publishing the release\", check GitHub before running again." : "Cancelled.", systemImage: "stop.circle")
                .font(.headline)
                .foregroundStyle(.orange)
        case .editing:
            EmptyView()
        }
    }

    private var runningTitle: String {
        switch model.job {
        case .release: model.publish ? "Building and publishing \(model.version)…" : "Building \(model.version)…"
        case .screenshots: "Retaking the screenshots…"
        }
    }

    private var successTitle: String {
        switch model.job {
        case .release:
            model.publish ? "\(model.version) is published. Installed copies find it on their next check." : "Build finished. Nothing was published."
        case .screenshots:
            model.commitScreenshots ? "The screenshots are retaken and pushed." : "The screenshots are retaken. Review them, then commit."
        }
    }

    @ViewBuilder private func icon(for state: Step.State) -> some View {
        switch state {
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}

struct LogView: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                Color.clear.frame(height: 1).id("bottom")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
            .onChange(of: text) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
}
