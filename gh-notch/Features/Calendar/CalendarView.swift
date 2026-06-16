import AppKit
import SwiftUI

/// Compact next-event indicator for the collapsed bar: a calendar glyph plus the
/// compact countdown (e.g. "15m", "now"). Sized to its content.
struct CalendarChip: View {
    let event: CalendarEvent
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(CalendarFormatting.compact(for: event, now: now))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .fixedSize()
    }
}

/// Today's agenda for the expanded panel, with graceful empty / denied /
/// not-determined states. Reads everything from `CalendarModel`; `now` is passed
/// in (the ticking clock) so relative labels stay current.
struct CalendarAgendaView: View {
    @Bindable var model: CalendarModel
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var content: some View {
        switch model.permission {
        case .granted:
            if model.agenda.isEmpty {
                hint("No events today")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(model.agenda) { row($0) }
                    }
                }
                .frame(maxHeight: 84)
            }
        case .notDetermined:
            hint("Checking your calendar…")
        case .denied:
            denied
        }
    }

    private func row(_ event: CalendarEvent) -> some View {
        let ended = !event.isAllDay && now >= event.end
        return HStack(spacing: 8) {
            Text(timeLabel(event))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(event.title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(CalendarFormatting.relative(for: event, now: now))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .opacity(ended ? 0.5 : 1)
    }

    private func timeLabel(_ event: CalendarEvent) -> String {
        event.isAllDay
            ? "all day"
            : CalendarFormatting.time(event.start, locale: .current, timeZone: .current)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var denied: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calendar access is off")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("Enable in System Settings…") { openCalendarSettings() }
                .font(.system(size: 11))
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    let now = Date()
    let model = CalendarModel(
        service: FakeCalendarService(authorization: .granted, events: [
            CalendarEvent(id: "1", title: "Standup", start: now.addingTimeInterval(-1800),
                          end: now.addingTimeInterval(-900), isAllDay: false),
            CalendarEvent(id: "2", title: "Design review", start: now.addingTimeInterval(900),
                          end: now.addingTimeInterval(4500), isAllDay: false)
        ]),
        now: { now }
    )
    model.refresh()
    return CalendarAgendaView(model: model, now: now)
        .frame(width: 340)
        .padding()
        .background(Color.black)
}
