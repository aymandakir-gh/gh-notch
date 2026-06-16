import Foundation

/// A calendar event, reduced to the fields the notch UI needs. Deliberately free
/// of EventKit and SwiftUI so all model logic over it stays pure and testable.
struct CalendarEvent: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }
}
