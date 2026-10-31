import SwiftUI
import CopyTrailCore

struct ClipRow: View {
    let clip: Clip
    let selected: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onHoverChanged: (Bool) -> Void
    @State private var hovered = false
    @State private var removeHovered = false
    @State private var expanded = false
    @State private var textWidth: CGFloat = 264
    @State private var thumbnail: NSImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showActions: Bool { hovered || removeHovered || selected }

    private var needsExpansion: Bool {
        guard case .text(let text) = clip.content else { return false }
        if text.count > 500 { return true }
        let font = NSFont.systemFont(ofSize: 13)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        let height = (text as NSString).boundingRect(
            with: NSSize(width: max(1, textWidth), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph]
        ).height
        return height > ceil(font.ascender - font.descender + font.leading) * 2 + 2
            || text.components(separatedBy: .newlines).count > 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onCopy) {
                content
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { textWidth = proxy.size.width }
                                .onChange(of: proxy.size.width) { _, width in textWidth = width }
                        }
                    }
                    .padding(.leading, 12).padding(.trailing, 40).padding(.vertical, 7)
                    .contentShape(.rect(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("Copy this item")
            .accessibilityLabel(clip.text.isEmpty ? "Copy saved image" : "Copy: \(clip.text.prefix(120))")

            if needsExpansion {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(expanded ? "Show less" : "Expand")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(PickerTheme.surface, in: .rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse copied text" : "Expand copied text")
                .padding(.leading, 12).padding(.bottom, 7)
            }
        }
        .overlay(alignment: .trailing) {
            removeButton
                .padding(.trailing, 12)
                .opacity(showActions ? 1 : 0)
                .offset(x: showActions || reduceMotion ? 0 : 4)
                .allowsHitTesting(showActions)
                .disabled(!showActions)
                .accessibilityHidden(!showActions)
        }
        .background(selected ? PickerTheme.selection : ((hovered || removeHovered) ? PickerTheme.hover : .clear),
                    in: .rect(cornerRadius: 9))
        .contentShape(.rect(cornerRadius: 9))
        .onHover {
            hovered = $0
            onHoverChanged($0)
        }
        .onDisappear { onHoverChanged(false) }
        .overlay { HandCursorRegion().accessibilityHidden(true) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showActions)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hovered)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: removeHovered)
        .task(id: clip.id) {
            if case .image(let data, _) = clip.content { thumbnail = ImagePreview.thumbnail(data) }
        }
    }

    @ViewBuilder private var content: some View {
        switch clip.content {
        case .text(let text):
            Text(expanded ? text : String(text.prefix(500)))
                .font(.system(size: 13)).lineSpacing(2).lineLimit(expanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable().scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 84, alignment: .leading)
                    .clipShape(.rect(cornerRadius: 5))
                    .accessibilityLabel("Copied image")
            } else {
                Text("Image").foregroundStyle(.secondary)
            }
        }
    }

    private var removeButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                .foregroundStyle(removeHovered ? Color(red: 0.95, green: 0.34, blue: 0.34) : .secondary)
                .frame(width: 26, height: 26)
                .contentShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.plain).help("Remove from history").accessibilityLabel("Remove saved item")
        .onHover { removeHovered = $0 }
    }
}
