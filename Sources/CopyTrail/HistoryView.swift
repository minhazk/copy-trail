import SwiftUI
import CopyTrailCore

struct HistoryView: View {
    let history: ClipboardHistory
    let shortcutAvailable: Bool
    let onCopy: (Clip) -> Void
    let onDismiss: () -> Void
    @State private var query = ""
    @State private var selection: UUID?
    @FocusState private var searchFocused: Bool

    private var results: [Clip] { history.matching(query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.tint)
                Text("Copy Trail").font(.title2.bold())
                Spacer()
                Text("This session").font(.caption).foregroundStyle(.secondary)
            }
            .padding()

            TextField("Search copied text…", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .onSubmit(copySelection)
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }

            Divider()
            if results.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "Your trail starts here" : "No matching clips",
                    systemImage: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                    description: Text(query.isEmpty
                        ? "Copy text or a link to see it here. History clears when you quit."
                        : "Try another search.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        ForEach(results) { clip in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "doc.text").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(clip.text.prefix(500)))
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(clip.copiedAt, style: .time)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Button { onCopy(clip) } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy this item")
                                .accessibilityLabel("Copy saved item")
                            }
                            .padding(.vertical, 6)
                            .tag(clip.id)
                            .contextMenu {
                                Button("Copy") { onCopy(clip) }
                                Button("Delete", role: .destructive) { history.remove(clip.id) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onKeyPress(.return) { copySelection(); return .handled }
                    .onChange(of: selection) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if let message = history.message {
                    Text(message).foregroundStyle(.red)
                }
                if !shortcutAvailable {
                    Text("⌘⇧V is unavailable. Open Copy Trail from the menu bar.")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text("\(history.clips.count) / \(history.capacity)").monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(history.isPaused ? "Resume" : "Pause") {
                        history.setPaused(!history.isPaused)
                    }
                    Button("Clear history", role: .destructive) { history.clear() }
                        .disabled(history.clips.isEmpty)
                    Menu {
                        Button("Quit Copy Trail") { NSApplication.shared.terminate(nil) }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel("More options")
                }
                Text(history.isPaused ? "Recording paused" : "Enter to copy · Esc to close · ⌘V to paste in your app")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(12)
        }
        .frame(width: 460, height: 540)
        .onAppear { searchFocused = true; selection = results.first?.id }
        .onChange(of: query) { selection = results.first?.id }
        .onChange(of: history.clips.map(\.id)) {
            if !results.contains(where: { $0.id == selection }) { selection = results.first?.id }
        }
        .onExitCommand(perform: onDismiss)
    }

    private func copySelection() {
        guard let clip = results.first(where: { $0.id == selection }) ?? results.first else { return }
        onCopy(clip)
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selection } ?? 0
        selection = results[min(max(index + delta, 0), results.count - 1)].id
    }
}
