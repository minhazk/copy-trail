import AppKit
import CopyTrailCore

@MainActor
final class PasteboardClient: ClipboardAccess {
    private let pasteboard = NSPasteboard.general
    var changeCount: Int { pasteboard.changeCount }
    var typeNames: Set<String> { Set((pasteboard.types ?? []).map(\.rawValue)) }
    func readText() -> String? { pasteboard.string(forType: .string) }
    func writeText(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
