import AppKit
import SwiftUI

/// Let AppKit manage the cursor across the whole card, including its buttons.
/// Cursor rectangles restore the previous cursor automatically on exit/window hide.
struct HandCursorRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { CursorView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }

    private final class CursorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func resetCursorRects() {
            addCursorRect(visibleRect, cursor: .pointingHand)
        }

        override func updateTrackingAreas() {
            for area in trackingAreas { removeTrackingArea(area) }
            super.updateTrackingAreas()
            addTrackingArea(NSTrackingArea(rect: .zero,
                options: [.cursorUpdate, .activeInKeyWindow, .inVisibleRect],
                owner: self, userInfo: nil))
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.pointingHand.set()
        }
    }
}
