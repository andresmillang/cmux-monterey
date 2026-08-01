import SwiftUI
import AppKit
import Foundation

// MARK: - Session Persistence

struct TabSessionData: Codable {
    let id: UUID
    let title: String
    let currentDirectory: String
}

struct SessionData: Codable {
    let tabs: [TabSessionData]
    let selectedTabId: UUID?
}

// Stores session metadata and terminal scrollback text under ~/.ghosttytabs
// (path intentionally has no spaces so it can be used as a ghostty `command`).
enum SessionStore {
    static let directory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".ghosttytabs")

    static var sessionFile: URL { directory.appendingPathComponent("session.json") }

    static func scrollbackFile(for id: UUID) -> URL {
        directory.appendingPathComponent("scrollback-\(id.uuidString).txt")
    }

    static func restoreScript(for id: UUID) -> URL {
        directory.appendingPathComponent("restore-\(id.uuidString).sh")
    }

    static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func load() -> SessionData? {
        guard let data = try? Data(contentsOf: sessionFile) else { return nil }
        return try? JSONDecoder().decode(SessionData.self, from: data)
    }

    static func save(_ session: SessionData) {
        ensureDirectory()
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: sessionFile, options: .atomic)
    }

    static func writeScrollback(_ text: String, for id: UUID) {
        ensureDirectory()

        // Keep at most ~500KB, trimmed at a line boundary from the front.
        var data = Data(text.utf8)
        let maxBytes = 500_000
        if data.count > maxBytes {
            var slice = data.suffix(maxBytes)
            if let newlineIndex = slice.firstIndex(of: 0x0A) {
                slice = slice[slice.index(after: newlineIndex)...]
            }
            data = Data(slice)
        }

        try? data.write(to: scrollbackFile(for: id), options: .atomic)
        writeRestoreScript(for: id)
    }

    private static func writeRestoreScript(for id: UUID) {
        let scrollbackPath = scrollbackFile(for: id).path
        let script = """
        #!/bin/sh
        cat '\(scrollbackPath)' 2>/dev/null
        printf '\\n\\033[2m-- session restored --\\033[0m\\n\\n'
        exec "${SHELL:-/bin/zsh}" -l
        """
        let url = restoreScript(for: id)
        try? Data(script.utf8).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    static func removeFiles(for id: UUID) {
        try? FileManager.default.removeItem(at: scrollbackFile(for: id))
        try? FileManager.default.removeItem(at: restoreScript(for: id))
    }
}

// MARK: - Tab

class Tab: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var currentDirectory: String

    // If set, the terminal for this tab launches this script instead of the
    // plain shell; the script prints the saved scrollback then execs the shell.
    let restoreScriptPath: String?

    init(
        id: UUID = UUID(),
        title: String = "Terminal",
        currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        restoreScriptPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.currentDirectory = currentDirectory
        self.restoreScriptPath = restoreScriptPath
    }
}

// MARK: - TabManager

class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selectedTabId: UUID?

    // Don't overwrite saved scrollback right after launch, before terminals
    // have had a chance to restore/produce content.
    private let launchDate = Date()
    private var observers: [NSObjectProtocol] = []

    init() {
        restoreSession()

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.saveSession()
        })
        observers.append(center.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.saveSession()
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Persistence

    private func restoreSession() {
        if let session = SessionStore.load(), !session.tabs.isEmpty {
            for tabData in session.tabs {
                let scriptPath = SessionStore.restoreScript(for: tabData.id).path
                let hasScript = FileManager.default.fileExists(atPath: scriptPath)
                let tab = Tab(
                    id: tabData.id,
                    title: tabData.title,
                    currentDirectory: tabData.currentDirectory,
                    restoreScriptPath: hasScript ? scriptPath : nil
                )
                tabs.append(tab)
            }
            if let selected = session.selectedTabId,
               tabs.contains(where: { $0.id == selected }) {
                selectedTabId = selected
            } else {
                selectedTabId = tabs.first?.id
            }
        } else {
            addTab()
        }
    }

    func saveSession() {
        // Update working directories from live terminals, then save metadata.
        let sessionTabs = tabs.map { tab -> TabSessionData in
            if let view = TerminalRegistry.shared.view(for: tab.id),
               let pwd = view.lastReportedPwd, !pwd.isEmpty {
                tab.currentDirectory = pwd
            }
            return TabSessionData(
                id: tab.id,
                title: tab.title,
                currentDirectory: tab.currentDirectory
            )
        }
        SessionStore.save(SessionData(tabs: sessionTabs, selectedTabId: selectedTabId))

        // Scrollback: skip during the launch grace period so a just-launched
        // (still empty) terminal can't clobber a good saved file.
        guard Date().timeIntervalSince(launchDate) > 10 else { return }
        for tab in tabs {
            guard let view = TerminalRegistry.shared.view(for: tab.id),
                  let text = view.readAllText() else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            SessionStore.writeScrollback(trimmed, for: tab.id)
        }
    }

    // MARK: Tab operations

    func addTab() {
        let newTab = Tab(title: "Terminal \(tabs.count + 1)")
        tabs.append(newTab)
        selectedTabId = newTab.id
    }

    func closeTab(_ tab: Tab) {
        guard tabs.count > 1 else { return }

        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)
            SessionStore.removeFiles(for: tab.id)

            if selectedTabId == tab.id {
                if index > 0 {
                    selectedTabId = tabs[index - 1].id
                } else {
                    selectedTabId = tabs.first?.id
                }
            }
        }
    }

    func closeCurrentTab() {
        guard let selectedId = selectedTabId,
              let tab = tabs.first(where: { $0.id == selectedId }) else { return }
        closeTab(tab)
    }

    func selectTab(_ tab: Tab) {
        selectedTabId = tab.id
    }

    func selectNextTab() {
        guard let currentId = selectedTabId,
              let currentIndex = tabs.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        selectedTabId = tabs[nextIndex].id
    }

    func selectPreviousTab() {
        guard let currentId = selectedTabId,
              let currentIndex = tabs.firstIndex(where: { $0.id == currentId }) else { return }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        selectedTabId = tabs[prevIndex].id
    }

    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTabId = tabs[index].id
    }

    func renameTab(_ tab: Tab, to newTitle: String) {
        tab.title = newTitle.isEmpty ? tab.title : newTitle
    }
}
