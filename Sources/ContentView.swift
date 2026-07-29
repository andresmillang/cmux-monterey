import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @State private var sidebarWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: 0) {
            // Vertical Tabs Sidebar
            VerticalTabsSidebar(sidebarWidth: sidebarWidth)
                .frame(width: sidebarWidth)

            // Divider
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)

            // Terminal Content - Keep all views alive, only show selected
            ZStack {
                ForEach(tabManager.tabs) { tab in
                    let isSelected = tabManager.selectedTabId == tab.id
                    GhosttyTerminalView(isVisible: isSelected)
                        .id(tab.id)
                        .opacity(isSelected ? 1 : 0)
                        .allowsHitTesting(isSelected)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct VerticalTabsSidebar: View {
    @EnvironmentObject var tabManager: TabManager
    let sidebarWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            HStack {
                Text("Tabs")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { tabManager.addTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Tab List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(tabManager.tabs) { tab in
                        TabItemView(tab: tab)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TabItemView: View {
    @EnvironmentObject var tabManager: TabManager
    @ObservedObject var tab: Tab
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editingTitle = ""

    var isSelected: Bool {
        tabManager.selectedTabId == tab.id
    }

    var body: some View {
        HStack(spacing: 8) {
            // Clickable area for selecting the tab
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .secondary)

                if isEditing {
                    TextField("", text: $editingTitle, onCommit: {
                        tab.title = editingTitle.isEmpty ? tab.title : editingTitle
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                    .onExitCommand {
                        isEditing = false
                    }
                } else {
                    Text(tab.title)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    tabManager.selectTab(tab)
                }
            }

            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isEditing {
                        tabManager.selectTab(tab)
                    }
                }

            // Close button - separate from tap area
            if (isHovering || isSelected) && !isEditing {
                Button(action: { tabManager.closeTab(tab) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .opacity(tabManager.tabs.count > 1 ? 1 : 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovering ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear))
        )
        .padding(.horizontal, 6)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Rename") {
                editingTitle = tab.title
                isEditing = true
            }
            Divider()
            Button("Close Tab") {
                tabManager.closeTab(tab)
            }
            .disabled(tabManager.tabs.count <= 1)
        }
    }
}
