import Foundation

/// Which displays get a notch panel (Settings → General).
enum ShowOnDisplays: String, CaseIterable, Codable, Identifiable {
    case builtInOnly
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .builtInOnly: return "Built-in display only"
        case .all: return "All displays"
        }
    }
}

/// What the selection logic needs to know about a screen — pure and testable;
/// `PanelManager` maps real `NSScreen`s in.
struct ScreenDescriptor: Equatable {
    var isBuiltIn: Bool
    var hasNotch: Bool
    /// The screen whose frame origin is (0,0) — the menu-bar screen.
    var isMenuBarPrimary: Bool
}

enum DisplaySelection {

    /// Indices of the screens that should host a panel.
    ///
    /// `builtInOnly` prefers the built-in screen; in clamshell mode (no
    /// built-in) it falls back to the menu-bar screen, then to the first
    /// screen — the notch UI should never silently vanish.
    static func targetIndices(of screens: [ScreenDescriptor], mode: ShowOnDisplays) -> [Int] {
        guard !screens.isEmpty else { return [] }
        switch mode {
        case .all:
            return Array(screens.indices)
        case .builtInOnly:
            if let builtIn = screens.firstIndex(where: { $0.isBuiltIn }) { return [builtIn] }
            if let primary = screens.firstIndex(where: { $0.isMenuBarPrimary }) { return [primary] }
            return [0]
        }
    }
}
