import AppKit
import SwiftUI

/// AppKit lifecycle owner.
///
/// Responsibilities for this slice (v0.1-alpha foundation):
/// - Activate the app as an accessory (no Dock icon, no main menu focus steal).
/// - Build the notch panel and attach the SwiftUI root view.
/// - Reposition the panel when the active screen or its geometry changes.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let viewModel = NotchViewModel()
    private var notchPanel: NotchPanel?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: lives in the notch, not the Dock. Mirrors LSUIElement so
        // behavior is correct even if the plist is overridden at runtime.
        NSApp.setActivationPolicy(.accessory)

        let panel = NotchPanel(viewModel: viewModel)
        panel.attachContent(NotchView(viewModel: viewModel))
        panel.repositionToActiveScreen()
        panel.orderFrontRegardless()
        notchPanel = panel

        observeScreenChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    /// Reposition when displays are connected/disconnected or resolution changes
    /// (e.g. plugging in an external monitor, or the menu bar resizing).
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notchPanel?.repositionToActiveScreen()
        }
    }
}
