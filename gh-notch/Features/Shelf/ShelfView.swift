import SwiftUI
import UniformTypeIdentifiers

/// The File Shelf in the expanded panel: a header with clear-all, a horizontal
/// row of held-file chips (icon + name + size + remove), a dashed empty state, and
/// drag-in. Drag-out / share are layered on in the next slice.
struct ShelfView: View {
    @Bindable var store: ShelfStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Shelf")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.isEmpty {
                    Button { store.clear() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear shelf")
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    /// Load each dropped provider's file URL and stage it. Returns whether any
    /// providers were accepted; the actual add is async + off the main actor.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in await store.add(url) }
            }
        }
        return !fileProviders.isEmpty
    }

    @ViewBuilder private var content: some View {
        if store.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.items) { chip($0) }
                }
            }
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
            )
        }
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
            Text(isDropTargeted ? "Release to add" : "Drop files here")
        }
        .font(.system(size: 12))
        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.white.opacity(0.15),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [4])
                )
        )
    }

    private func chip(_ item: ShelfItem) -> some View {
        let category = FileMetadata.category(
            isDirectory: item.isDirectory,
            fileExtension: (item.displayName as NSString).pathExtension
        )
        return HStack(spacing: 6) {
            Image(systemName: category.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(FileMetadata.humanSize(item.byteSize))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Button { store.remove(item) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remove from shelf")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 150)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.06)))
    }
}

#Preview {
    let now = Date()
    let store = ShelfStore(source: FakeFileSource(initial: [
        ShelfItem(id: "1", originalPath: "/a/report.pdf", stagedName: "report.pdf",
                  displayName: "report.pdf", byteSize: 1_500_000, isDirectory: false, addedAt: now),
        ShelfItem(id: "2", originalPath: "/a/photo.png", stagedName: "photo.png",
                  displayName: "photo.png", byteSize: 240_000, isDirectory: false, addedAt: now)
    ]))
    return ShelfView(store: store)
        .frame(width: 360)
        .padding()
        .background(Color.black)
}
