import AppKit
import XCTest
import CopyTrailCore
@testable import CopyTrail

final class PasteboardImageTests: XCTestCase {
    @MainActor func testPNGAndTIFFCaptureThumbnailAndRestoreOriginalBytes() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let client = PasteboardClient(pasteboard: board)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16,
            pixelsHigh: 12, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for (format, type) in [(NSBitmapImageRep.FileType.png, NSPasteboard.PasteboardType.png), (.tiff, .tiff)] {
            let data = try XCTUnwrap(bitmap.representation(using: format, properties: [:]))
            let history = ClipboardHistory(clipboard: client)
            board.clearContents()
            XCTAssertTrue(board.setData(data, forType: type))
            let before = board.changeCount
            history.poll()
            XCTAssertEqual(board.changeCount, before)
            let clip = try XCTUnwrap(history.clips.first)
            XCTAssertEqual(clip.content, .image(data: data, type: type.rawValue))
            XCTAssertNotNil(ImagePreview.thumbnail(data))
            board.clearContents()
            board.setString("new clipboard", forType: .string)
            XCTAssertTrue(history.restore(clip))
            XCTAssertEqual(board.data(forType: type), data)
            history.poll()
            XCTAssertEqual(history.clips.count, 1)
        }
    }

    @MainActor func testMalformedImageDoesNotCaptureOrDestroyClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let client = PasteboardClient(pasteboard: board)
        let history = ClipboardHistory(clipboard: client)
        board.setData(Data([1, 2, 3]), forType: .png)
        history.poll()
        XCTAssertTrue(history.clips.isEmpty)
        board.clearContents()
        board.setString("keep me", forType: .string)
        XCTAssertFalse(client.writeImage(Data([1, 2, 3]), type: "public.png"))
        XCTAssertEqual(board.string(forType: .string), "keep me")
    }
}
