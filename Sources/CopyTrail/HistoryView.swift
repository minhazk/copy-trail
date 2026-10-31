import SwiftUI
import CopyTrailCore

struct HistoryView: View {
    let history: ClipboardHistory
    let shortcutAvailable: Bool
    let onCopy: (Clip) -> Void
    let onDismiss: () -> Void
    @State private var query = ""
    @State private var selection: UUID?
    @State private var hoveredClip: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    private var results: [Clip] { history.matching(query) }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) { floatingShelf }
            } else {
                floatingShelf
            }
        }
        .frame(width: 336, height: 480)
        .tint(.gray)
        .environment(\.colorScheme, .dark)
        .onAppear { searchFocused = true }
        .onChange(of: query) { selection = nil }
        .onChange(of: history.clips.map(\.id)) {
            if !results.contains(where: { $0.id == selection }) { selection = nil }
        }
        .onExitCommand(perform: onDismiss)
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.return) { copySelection(); return .handled }
    }

    private var floatingShelf: some View {
        VStack(spacing: 10) {
            search
                .modifier(ShelfSurface(cornerRadius: 24, focused: searchFocused))
            VStack(spacing: 0) {
                if let message = history.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 12)
                }
                if !shortcutAvailable {
                    Text("⌘⇧V is unavailable. Use the menu bar icon.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 12)
                }
                if results.isEmpty {
                    emptyState
                } else {
                    clipList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: 20))
            .modifier(ShelfSurface(cornerRadius: 20))
        }
    }

    private var search: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(history.isPaused ? "Search history · recording paused" : "Search clipboard…", text: $query)
                .textFieldStyle(.plain).font(.system(size: 14))
                .focused($searchFocused)
                .onSubmit(copySelection)
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                .accessibilityLabel("Search clipboard history")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            Menu {
                Button(history.isPaused ? "Resume recording" : "Pause recording") {
                    history.setPaused(!history.isPaused)
                }
                Button("Clear history", role: .destructive) { history.clear() }
                    .disabled(history.clips.isEmpty)
                Divider()
                Button("Quit Copy Trail") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, 18).frame(height: 48)

    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(history.isPaused && query.isEmpty ? "Recording paused" : (query.isEmpty ? "Nothing copied yet" : "No matches"))
                .font(.system(size: 14, weight: .medium))
            Text(history.isPaused && query.isEmpty
                 ? "Resume from the search menu when you’re ready."
                 : (query.isEmpty ? "Copy text, an image or a screenshot.\nYour history will appear here." : "Try another search."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, clip in
                        ClipRow(clip: clip, selected: selection == clip.id,
                                onCopy: { onCopy(clip) }, onDelete: { history.remove(clip.id) },
                                onHoverChanged: { inside in
                                    if inside { hoveredClip = clip.id }
                                    else if hoveredClip == clip.id { hoveredClip = nil }
                                })
                            .overlay(alignment: .bottom) {
                                if index + 1 < results.count {
                                    let nextID = results[index + 1].id
                                    Rectangle().fill(PickerTheme.separator)
                                        .frame(height: 1).padding(.horizontal, 12)
                                        .opacity(hoveredClip == clip.id || hoveredClip == nextID
                                                 || selection == clip.id || selection == nextID ? 0 : 1)
                                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hoveredClip)
                                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selection)
                                        .allowsHitTesting(false)
                                }
                            }
                            .id(clip.id)
                            .contextMenu {
                                Button("Copy") { onCopy(clip) }
                                Button("Delete", role: .destructive) { history.remove(clip.id) }
                            }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 8)
            }
            .onChange(of: selection) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private func copySelection() {
        guard let clip = results.first(where: { $0.id == selection }) ?? results.first else { return }
        onCopy(clip)
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selection } ?? (delta > 0 ? -1 : results.count)
        selection = results[min(max(index + delta, 0), results.count - 1)].id
    }
}
