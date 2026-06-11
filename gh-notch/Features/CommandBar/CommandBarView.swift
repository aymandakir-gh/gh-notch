import SwiftUI

/// The AI command bar: a Spotlight-style text field rendered in the notch.
///
/// Parses locally first (math, counts, transforms, date); unrecognized queries
/// dispatch to the configured AI endpoint. The result line shows underneath with
/// a badge marking on-device vs. remote, and a spinner while a request is in
/// flight.
struct CommandBarView: View {
    @Bindable var viewModel: CommandBarViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                TextField("Type a command…", text: $viewModel.input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .focused($isFocused)
                    .onSubmit { Task { await viewModel.submit() } }

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.08))
            )

            if let result = viewModel.result {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: result.handledLocally ? "lock.fill" : "cloud")
                        .font(.system(size: 9))
                        .foregroundStyle(result.handledLocally ? .green : .orange)
                        .help(result.handledLocally ? "Resolved on-device" : "From your AI endpoint")
                    Text(result.output)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.result)
        .animation(.easeOut(duration: 0.15), value: viewModel.isLoading)
        .onAppear { isFocused = true }
    }
}

#Preview {
    CommandBarView(viewModel: CommandBarViewModel())
        .frame(width: 340)
        .padding()
        .background(Color.black)
}
