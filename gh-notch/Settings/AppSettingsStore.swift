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

    /// Which displays host a panel. `PanelManager` observes and rebuilds.
    var showOnDisplays: ShowOnDisplays {
        didSet { defaults.set(showOnDisplays.rawValue, forKey: Keys.showOnDisplays) }
    }

    /// Seconds the pointer must dwell on the notch before hover expands the
    /// panel — kills accidental expansions from crossing the screen top.
    var hoverDwell: TimeInterval {
        didSet {
            let clamped = Self.clampDwell(hoverDwell)
            if hoverDwell != clamped { hoverDwell = clamped } // in-didSet assignment does not recurse
            defaults.set(hoverDwell, forKey: Keys.hoverDwell)
        }
    }

    /// Manual notch/pill width in points; nil = automatic (sampled).
    var notchWidthOverride: Double? {
        didSet {
            if let notchWidthOverride {
                defaults.set(notchWidthOverride, forKey: Keys.notchWidthOverride)
            } else {
                defaults.removeObject(forKey: Keys.notchWidthOverride)
            }
        }
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
        static let showOnDisplays = "display.showOn"
        static let hoverDwell = "display.hoverDwell"
        static let notchWidthOverride = "display.notchWidthOverride"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.stringArray(forKey: Keys.disabledSections) ?? []
        self.disabledSections = SectionsLogic.disabledSet(fromRawValues: raw)
        self.blendCollapsed = defaults.object(forKey: Keys.blendCollapsed) as? Bool ?? true
        self.showOnDisplays = defaults.string(forKey: Keys.showOnDisplays)
            .flatMap(ShowOnDisplays.init(rawValue:)) ?? .builtInOnly
        let dwell = defaults.object(forKey: Keys.hoverDwell) as? Double
        self.hoverDwell = dwell.map(Self.clampDwell) ?? NotchMotion.defaultHoverDwell
        self.notchWidthOverride = defaults.object(forKey: Keys.notchWidthOverride) as? Double
    }

    /// Hover-dwell is bounded to [0, 0.5]s — enforced identically on load and on
    /// assignment so an out-of-range write can't persist a bad value until relaunch.
    private static func clampDwell(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, 0.0), 0.5)
    }

    private func persistDisabledSections() {
        defaults.set(SectionsLogic.rawValues(from: disabledSections), forKey: Keys.disabledSections)
    }
}
