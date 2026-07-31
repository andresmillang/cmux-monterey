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
                Color.clear
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    )
                    .onTapGesture {
                        tabManager.addTab()
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

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
    @State private var isHoveringClose = false
    @State private var isEditing = false
    @State private var editingTitle = ""
    @FocusState private var isTextFieldFocused: Bool

    var isSelected: Bool {
        tabManager.selectedTabId == tab.id
    }

    var body: some View {
        HStack(spacing: 0) {
            // Tab content - icon and title
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .secondary)

                if isEditing {
                    TextField("", text: $editingTitle, onCommit: {
                        tabManager.renameTab(tab, to: editingTitle)
                        isEditing = false
                        isTextFieldFocused = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                    .focused($isTextFieldFocused)
                    .onExitCommand {
                        isEditing = false
                        isTextFieldFocused = false
                    }
                    .onAppear {
                        // Delay focus slightly to ensure view is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                } else {
                    Text(tab.title)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
            }
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    tabManager.selectTab(tab)
                }
            }

            // Close button with larger hit area
            if (isHovering || isSelected) && !isEditing && tabManager.tabs.count > 1 {
                Color.clear
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(isHoveringClose ? 1.0 : 0.7) : (isHoveringClose ? .primary : .secondary))
                    )
                    .onHover { hovering in
                        isHoveringClose = hovering
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .onTapGesture {
                        tabManager.closeTab(tab)
                    }
                    .padding(.trailing, 6)
            } else {
                // Placeholder to maintain consistent layout
                Color.clear
                    .frame(width: 28, height: 28)
                    .padding(.trailing, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovering ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear))
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Rename") {
                editingTitle = tab.title
                isEditing = true
                // Focus will be set by onAppear of TextField
            }
            Divider()
            Button("Close Tab") {
                tabManager.closeTab(tab)
            }
            .disabled(tabManager.tabs.count <= 1)
        }
        .onChange(of: isEditing) { newValue in
            if !newValue {
                isTextFieldFocused = false
            }
        }
    }
}
