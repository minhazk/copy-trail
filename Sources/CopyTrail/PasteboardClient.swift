import AppKit
import ImageIO
import CopyTrailCore

@MainActor
final class PasteboardClient: ClipboardAccess {
    private let pasteboard: NSPasteboard
    init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }
    var changeCount: Int { pasteboard.changeCount }
    var typeNames: Set<String> { Set((pasteboard.types ?? []).map(\.rawValue)) }
    func readText() -> String? { pasteboard.string(forType: .string) }
    func readImage() -> ClipContent? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            guard let data = pasteboard.data(forType: type),
                  data.count <= ClipboardHistory.maximumImageBytes,
                  ImagePreview.thumbnail(data) != nil else { continue }
            return .image(data: data, type: type.rawValue)
        }
        return nil
    }
    func writeText(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
    func writeImage(_ data: Data, type: String) -> Bool {
        guard [NSPasteboard.PasteboardType.png.rawValue, NSPasteboard.PasteboardType.tiff.rawValue].contains(type),
              data.count <= ClipboardHistory.maximumImageBytes,
              ImagePreview.thumbnail(data) != nil else { return false }
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
    }
}
