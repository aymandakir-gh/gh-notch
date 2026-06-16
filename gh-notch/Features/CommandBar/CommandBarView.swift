import AppKit
import SwiftUI

/// The AI command bar: a Spotlight-style text field rendered in the notch.
///
/// Parses locally first (math, percentages, counts, transforms, date) and shows
/// a live on-device result as you type; unrecognized queries dispatch to the
/// configured AI endpoint on submit. The result line shows underneath with a
/// badge marking on-device vs. remote, a copy button, and a spinner while a
/// request is in flight. When empty, a few example chips hint at what's possible.
/// The result is capped to two lines so the panel can't balloon.
struct CommandBarView: View {
    @Bindable var viewModel: CommandBarViewModel
    @FocusState private var isFocused: Bool
    @State private var copied = false
    @State private var copyToken = 0

    /// Example commands shown when the field is empty.
    private let hints = ["12 * 8", "20% of 80", "upper hello"]

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
                resultRow(result)
            } else if showHints {
                hintRow
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.result)
        .animation(.easeOut(duration: 0.15), value: viewModel.isLoading)
        .onAppear { isFocused = true }
        .onChange(of: viewModel.input) { _, _ in
            copied = false
            viewModel.previewLocal()
        }
    }

    private var showHints: Bool {
        isFocused && viewModel.input.isEmpty && !viewModel.isLoading
    }

    private func resultRow(_ result: CommandResult) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: result.handledLocally ? "lock.fill" : "cloud")
                .font(.system(size: 9))
                .foregroundStyle(result.handledLocally ? .green : .orange)
                .help(result.handledLocally ? "Resolved on-device" : "From your AI endpoint")
            Text(result.output)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(copied ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy result")
        }
        .transition(.opacity)
    }

    private var hintRow: some View {
        HStack(spacing: 6) {
            ForEach(hints, id: \.self) { hint in
                Button { viewModel.input = hint } label: {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity)
    }

    private func copy() {
        guard let output = viewModel.result?.output else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        copied = true
        copyToken &+= 1
        let token = copyToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copyToken == token { copied = false }
        }
    }
}

#Preview {
    CommandBarView(viewModel: CommandBarViewModel())
        .frame(width: 340)
        .padding()
        .background(Color.black)
}
