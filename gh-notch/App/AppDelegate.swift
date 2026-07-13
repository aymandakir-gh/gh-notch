import AppKit
import SwiftUI

/// AppKit lifecycle owner.
///
/// Responsibilities:
/// - Activate the app as an accessory (no Dock icon, no main menu focus steal).
/// - Boot the `PanelManager` (one panel per selected screen; shared feature
///   models; gesture monitors).
/// - Trigger a (debounced) rebuild when displays change.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panelManager: PanelManager?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: lives in the notch, not the Dock. Mirrors LSUIElement so
        // behavior is correct even if the plist is overridden at runtime.
        NSApp.setActivationPolicy(.accessory)

        let manager = PanelManager()
        manager.start()
        panelManager = manager

        observeScreenChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelManager?.stop()
        panelManager = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    /// Rebuild panels when displays are connected/disconnected or resolution
    /// changes (e.g. plugging in an external monitor, menu bar resizing).
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // queue: .main guarantees the main thread; make that visible to
            // the compiler so the MainActor-isolated manager is reachable.
            MainActor.assumeIsolated {
                self?.panelManager?.scheduleRebuild()
            }
        }
    }
}
