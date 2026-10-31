import AppKit
import SwiftUI
import CopyTrailCore

@main
enum CopyTrailApp {
    @MainActor static func main() {
        // AppKit owns the one picker window. An empty SwiftUI Settings scene can
        // otherwise create an unused window when the application is activated.
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let history = ClipboardHistory(clipboard: PasteboardClient())
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var shortcut: GlobalShortcut?
    private var shortcutAvailable = false
    private var pollingTask: Task<Void, Never>?
    private var previousApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copy Trail")
        item.button?.toolTip = "Copy Trail (⌘⇧V)"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
        shortcut = GlobalShortcut { [weak self] in self?.togglePanel() }
        shortcutAvailable = shortcut?.register() ?? false
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(750)) }
                catch { break }
                self?.history.poll()
            }
        }
    }

    private func installMenu() {
        let menu = NSMenu()
        let application = NSMenuItem()
        application.submenu = NSMenu()
        application.submenu?.addItem(withTitle: "Quit Copy Trail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(application)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        edit.submenu = NSMenu(title: "Edit")
        for (title, selector, key) in [
            ("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
            ("Copy", "copy:", "c"), ("Paste", "paste:", "v"),
            ("Select All", "selectAll:", "a")
        ] {
            edit.submenu?.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if panel?.isVisible != true { togglePanel() }
        return false
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { dismiss(); return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = frontmost
        }
        if panel == nil {
            let window = PickerPanel(contentRect: NSRect(x: 0, y: 0, width: 336, height: 480),
                                 styleMask: [.borderless],
                                 backing: .buffered, defer: false)
            window.title = "Copy Trail"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = NSAppearance(named: .darkAqua)
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.delegate = self
            panel = window
        }
        // A fresh view resets search and keyboard focus each time the picker opens.
        panel?.contentView = NSHostingView(rootView: HistoryView(
            history: history, shortcutAvailable: shortcutAvailable,
            onCopy: { [weak self] clip in
                guard let self, self.history.restore(clip) else { return }
                self.dismiss()
            }, onDismiss: { [weak self] in self?.dismiss() }
        ))
        positionPanelBelowStatusItem()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    private func positionPanelBelowStatusItem() {
        guard let panel else { return }
        guard let button = statusItem?.button, let statusWindow = button.window else {
            panel.center()
            return
        }
        // Convert from the button's local coordinates to global AppKit screen
        // coordinates; this also follows the menu bar across displays.
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        guard let screen = statusWindow.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let size = panel.frame.size
        let x = min(max(anchor.midX - size.width / 2, visible.minX), visible.maxX - size.width)
        let y = max(visible.minY, min(anchor.minY - 8, visible.maxY) - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func dismiss() {
        panel?.orderOut(nil)
        previousApplication?.activate(options: [])
        previousApplication = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clicking another app should close the picker without stealing focus back.
        panel?.orderOut(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollingTask?.cancel()
        shortcut?.unregister()
        history.clear()
    }
}

private final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
