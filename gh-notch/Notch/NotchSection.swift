import Foundation

/// The sections of the expanded surface, in display order.
///
/// A deliberate enum registry (not a protocol): every section is first-party,
/// the switch in `NotchView` stays exhaustive, and the ordering/filter rules are
/// pure and testable here. Grows a protocol only if third-party sections ever
/// become a thing (docs/PARITY-ROADMAP.md §2.3).
enum ExpandedSection: String, CaseIterable, Identifiable, Codable {
    case commandBar
    case calendar
    case shelf
    case statusRow

    var id: String { rawValue }

    /// Name shown in Settings → Features.
    var displayName: String {
        switch self {
        case .commandBar: return "AI Command Bar"
        case .calendar: return "Calendar"
        case .shelf: return "File Shelf"
        case .statusRow: return "Clock & Battery"
        }
    }

    /// The status row hosts the Settings gear — the panel's only discoverable
    /// path to preferences (the app has no Dock icon or menu-bar extra), so it
    /// can never be disabled.
    var isAlwaysOn: Bool { self == .statusRow }
}

/// Pure section-list rules.
enum SectionsLogic {

    /// Sections to render, in registry order: everything not disabled, with
    /// always-on sections forced back in even if the disabled set names them.
    static func visibleSections(
        disabled: Set<ExpandedSection>
    ) -> [ExpandedSection] {
        ExpandedSection.allCases.filter { $0.isAlwaysOn || !disabled.contains($0) }
    }

    /// Decode a persisted disabled-set (raw strings), dropping unknown values
    /// so removed sections can't wedge future launches.
    static func disabledSet(fromRawValues raw: [String]) -> Set<ExpandedSection> {
        Set(raw.compactMap(ExpandedSection.init(rawValue:)))
    }

    /// Raw strings for persistence, sorted for stable writes.
    static func rawValues(from disabled: Set<ExpandedSection>) -> [String] {
        disabled.map(\.rawValue).sorted()
    }
}
