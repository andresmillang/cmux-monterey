import SwiftUI
import Foundation

// Codable structure for persisting tab data
struct TabData: Codable {
    let id: UUID
    var title: String
    var currentDirectory: String
}

struct SessionState: Codable {
    var tabs: [TabData]
    var selectedTabId: UUID?
}

class Tab: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String {
        didSet {
            // Notify that tab was renamed for persistence
            NotificationCenter.default.post(name: .tabStateDidChange, object: nil)
        }
    }
    @Published var currentDirectory: String

    init(id: UUID = UUID(), title: String = "Terminal", currentDirectory: String? = nil) {
        self.id = id
        self.title = title
        self.currentDirectory = currentDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    convenience init(from data: TabData) {
        self.init(id: data.id, title: data.title, currentDirectory: data.currentDirectory)
    }

    func toData() -> TabData {
        TabData(id: id, title: title, currentDirectory: currentDirectory)
    }
}

extension Notification.Name {
    static let tabStateDidChange = Notification.Name("tabStateDidChange")
}

class TabManager: ObservableObject {
    static let shared = TabManager()

    @Published var tabs: [Tab] = []
    @Published var selectedTabId: UUID?

    private var hasRestoredState = false
    private var initializationComplete = false

    private static let stateFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.ghosttytabs.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("session.json")
    }()

    private init() {
        // Try to restore saved state
        if restoreState() {
            hasRestoredState = true
        } else {
            // Only add a fresh tab if no state was restored
            addTab(saveState: false)
        }

        // Mark initialization complete after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.initializationComplete = true
        }

        // Listen for tab state changes (like renames)
        NotificationCenter.default.addObserver(
            forName: .tabStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveState()
        }

        // Save state when app terminates
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveState()
        }

        // Also save when app resigns active (user switches away or system sleep)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveState()
        }

        // Save when app is hidden
        NotificationCenter.default.addObserver(
            forName: NSApplication.didHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveState()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Persistence

    func saveState() {
        let tabData = tabs.map { $0.toData() }
        let state = SessionState(tabs: tabData, selectedTabId: selectedTabId)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: Self.stateFileURL, options: .atomic)
        } catch {
            print("Failed to save session state: \(error)")
        }
    }

    @discardableResult
    private func restoreState() -> Bool {
        guard FileManager.default.fileExists(atPath: Self.stateFileURL.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: Self.stateFileURL)
            let state = try JSONDecoder().decode(SessionState.self, from: data)

            guard !state.tabs.isEmpty else {
                return false
            }

            tabs = state.tabs.map { Tab(from: $0) }
            selectedTabId = state.selectedTabId ?? tabs.first?.id

            return true
        } catch {
            print("Failed to restore session state: \(error)")
            return false
        }
    }

    // MARK: - Tab Management

    func addTab(saveState shouldSave: Bool = true) {
        let newTab = Tab(title: "Terminal \(tabs.count + 1)")
        tabs.append(newTab)
        selectedTabId = newTab.id
        if shouldSave {
            self.saveState()
        }
    }

    func closeTab(_ tab: Tab) {
        guard tabs.count > 1 else { return }

        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)

            if selectedTabId == tab.id {
                if index > 0 {
                    selectedTabId = tabs[index - 1].id
                } else {
                    selectedTabId = tabs.first?.id
                }
            }
            saveState()
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
        // saveState is called automatically via the didSet observer
    }
}
