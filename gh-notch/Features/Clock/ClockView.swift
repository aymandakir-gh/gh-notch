import SwiftUI

/// Compact time + date display for the expanded panel.
struct ClockView: View {
    @Bindable var model: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.timeText)
                .font(.system(size: 26, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(model.dateText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    ClockView(model: ClockModel())
        .padding()
        .background(Color.black)
}
