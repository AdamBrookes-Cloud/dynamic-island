
import SwiftUI
import AppKit

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var islandPanel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let width: CGFloat = 600
        let height: CGFloat = 200
        let topInset: CGFloat = 0
    

        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(rootView: ContentView())
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            panel.setFrameOrigin(
                NSPoint(
                    x: screen.frame.midX - width / 2,
                    y: screen.frame.maxY - height - topInset
                )
            )
        }

        islandPanel = panel
        panel.orderFrontRegardless()

        registerKeyboardShortcut()
    }

    private func registerKeyboardShortcut() {
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            guard self?.matchesShortcut(event) == true else {
                return event
            }

            self?.toggleIsland()
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            guard self?.matchesShortcut(event) == true else {
                return
            }

            DispatchQueue.main.async {
                self?.toggleIsland()
            }
        }
    }

    private func matchesShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
            .intersection([.control, .option, .command, .shift])

        return event.keyCode == 2
            && modifiers == [.control, .option, .command]
    }

    private func toggleIsland() {
        guard let panel = islandPanel else {
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }
}
