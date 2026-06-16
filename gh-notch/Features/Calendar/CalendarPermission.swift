import Foundation

/// The app's view of calendar authorization, collapsed from EventKit's richer
/// `EKAuthorizationStatus` to the three states the UI actually distinguishes.
///
/// `writeOnly` and `restricted` map to `denied` because the feature needs to read
/// events; the mapping itself lives in `EventKitCalendarService` (which imports
/// EventKit) so this type stays pure.
enum CalendarPermission: Equatable {
    /// The user has not been asked yet — request lazily, on first activation.
    case notDetermined
    /// Access is unavailable (denied, restricted, or write-only).
    case denied
    /// Read access is granted.
    case granted
}
