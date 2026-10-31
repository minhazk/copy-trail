import AppKit
import SwiftUI
import CopyTrailCore

@main
struct CopyTrailApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
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

    @objc private func togglePanel() {
        if panel?.isVisible == true { dismiss(); return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = frontmost
        }
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
                                 styleMask: [.titled, .closable],
                                 backing: .buffered, defer: false)
            window.title = "Copy Trail"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.delegate = self
            window.center()
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
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
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
