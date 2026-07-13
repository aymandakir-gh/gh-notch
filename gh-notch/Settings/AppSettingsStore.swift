import Foundation
import Observation

/// Observable, persisted app-level settings (feature toggles, display options).
///
/// Deliberately separate from `SettingsStore` (the AI command bar's endpoint +
/// Keychain store): these are plain `UserDefaults` booleans/lists under
/// namespaced keys (`feature.*`, `display.*`). Injectable defaults for tests.
@MainActor
@Observable
final class AppSettingsStore {

    /// Shared instance used by the panel and the Settings window.
    static let shared = AppSettingsStore()

    /// Sections the user has switched off (persisted as raw strings; unknown
    /// values are dropped on load). Always-on sections are filtered back in by
    /// `SectionsLogic.visibleSections` regardless of this set.
    var disabledSections: Set<ExpandedSection> {
        didSet { persistDisabledSections() }
    }

    /// Collapsed look: `true` keeps the v0.3 transparent menu-bar blend;
    /// `false` draws the island pill even when collapsed (the morph-native
    /// look). Slice E adds the Settings UI.
    var blendCollapsed: Bool {
        didSet { defaults.set(blendCollapsed, forKey: Keys.blendCollapsed) }
    }

    /// Sections to render right now, in order.
    var visibleSections: [ExpandedSection] {
        SectionsLogic.visibleSections(disabled: disabledSections)
    }

    func setSection(_ section: ExpandedSection, enabled: Bool) {
        if enabled {
            disabledSections.remove(section)
        } else if !section.isAlwaysOn {
            disabledSections.insert(section)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let disabledSections = "feature.sections.disabled"
        static let blendCollapsed = "display.blendCollapsed"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.stringArray(forKey: Keys.disabledSections) ?? []
        self.disabledSections = SectionsLogic.disabledSet(fromRawValues: raw)
        self.blendCollapsed = defaults.object(forKey: Keys.blendCollapsed) as? Bool ?? true
    }

    private func persistDisabledSections() {
        defaults.set(SectionsLogic.rawValues(from: disabledSections), forKey: Keys.disabledSections)
    }
}
