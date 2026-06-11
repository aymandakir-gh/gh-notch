import SwiftUI

/// Entry point for gh-notch.
///
/// The app is a notch / menu-bar utility with no Dock icon (`LSUIElement` is set
/// in `Info.plist`). SwiftUI owns the `@main` declaration, but all window
/// management happens in `AppDelegate` via AppKit, because the notch panel needs
/// `NSPanel` APIs that SwiftUI does not expose.
///
/// We deliberately declare an empty `Settings` scene rather than a `WindowGroup`:
/// a `WindowGroup` would create a standard app window at launch, which we do not
/// want. `Settings` provides a valid scene with no visible window until the user
/// opens preferences (wired up in a later slice).
@main
struct GhNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
