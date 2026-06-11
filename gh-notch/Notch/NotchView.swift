import SwiftUI

/// SwiftUI root rendered inside the notch panel.
///
/// Foundation slice: a collapsed black pill that hugs the notch and expands into
/// an empty surface on hover/click. Feature widgets (media, calendar, AI bar,
/// etc.) will mount into the expanded area in later slices.
struct NotchView: View {
    @Bindable var viewModel: NotchViewModel
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
            if viewModel.isExpanded {
                expandedSurface
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelShape)
        .onHover { hovering in
            isHovering = hovering
            // Hover-to-peek: expand on enter, collapse on leave. A click also
            // toggles, for trackpad users who prefer an explicit tap.
            if hovering {
                viewModel.expand()
            } else {
                viewModel.collapse()
            }
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.isExpanded)
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack {
            Spacer(minLength: 0)
        }
        .frame(height: collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggle() }
    }

    private var collapsedHeight: CGFloat {
        viewModel.geometry?.notchHeight ?? NotchGeometry.fallbackHeight
    }

    // MARK: - Expanded

    private var expandedSurface: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.secondary)
            Text("gh-notch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Foundation ready — features mount here.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: - Shape

    /// The notch silhouette: square top corners (flush with the screen edge),
    /// rounded bottom corners. Expanding only grows downward, so the top stays
    /// glued to the physical notch.
    private var panelShape: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(.black)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .strokeBorder(.white.opacity(viewModel.isExpanded ? 0.08 : 0), lineWidth: 1)
        )
    }

    private var bottomRadius: CGFloat {
        viewModel.isExpanded ? 16 : 10
    }
}

#Preview {
    NotchView(viewModel: NotchViewModel())
        .frame(width: 360, height: 232)
        .background(Color.gray)
}
