import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let appState: AppState
    private let auth: AuthController

    init(appState: AppState, auth: AuthController) {
        self.appState = appState
        self.auth = auth
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = statusBarImage()
        statusItem?.button?.imagePosition = .imageOnly
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self

        popover.behavior = ProcessInfo.processInfo.environment["TODOBAR_KEEP_POPOVER_OPEN"] == "1"
            ? .applicationDefined
            : .transient
        popover.contentSize = NSSize(width: PopoverLayout.width, height: PopoverLayout.height)
        let rootView = TaskPopoverView()
            .environmentObject(appState)
            .environmentObject(auth)
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NotificationCenter.default.post(name: .todoBarPopoverDidShow, object: nil)
        }
    }

    private func statusBarImage() -> NSImage? {
        let image = NSImage(named: "TodoBarMenuBarIcon")
            ?? NSImage(systemSymbolName: "checklist", accessibilityDescription: "TodoBar")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        image?.accessibilityDescription = "TodoBar"
        return image
    }
}

extension Notification.Name {
    static let todoBarPopoverDidShow = Notification.Name("TodoBarPopoverDidShow")
}
