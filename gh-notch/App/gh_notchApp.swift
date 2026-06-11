import SwiftUI

/// Entry point for gh-notch.
///
/// The app is a notch / menu-bar utility with no Dock icon (`LSUIElement` is set
/// in `Info.plist`). SwiftUI owns the `@main` declaration, but all window
/// management happens in `AppDelegate` via AppKit, because the notch panel needs
/// `NSPanel` APIs that SwiftUI does not expose.
///
/// We declare a `Settings` scene rather than a `WindowGroup`: a `WindowGroup`
/// would create a standard app window at launch, which we do not want. `Settings`
/// provides the ⌘, preferences window (the AI endpoint config) with no visible
/// window until the user opens it.
@main
struct GhNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
