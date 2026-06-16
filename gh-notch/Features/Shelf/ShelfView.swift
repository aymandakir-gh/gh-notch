import AppKit
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
                Text(item.isDirectory ? category.label : FileMetadata.humanSize(item.byteSize))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            SharePickerButton(urls: [store.stagedURL(for: item)])
                .frame(width: 18, height: 18)
                .help("Share / AirDrop")
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
        .frame(width: 178)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.06)))
        // Drag a shelf item back out to Finder or another app (copies the staged file).
        // Pin the panel open for the drag; skip if the staged copy has vanished.
        .onDrag {
            store.beginDragOut()
            let url = store.stagedURL(for: item)
            guard FileManager.default.fileExists(atPath: url.path),
                  let provider = NSItemProvider(contentsOf: url) else {
                return NSItemProvider()
            }
            return provider
        }
    }
}

/// A small share button that anchors an `NSSharingServicePicker` (AirDrop, Mail,
/// Messages, …) to itself — SwiftUI has no native equivalent, and the picker needs
/// a real `NSView` to present from.
struct SharePickerButton: NSViewRepresentable {
    let urls: [URL]

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.title = ""
        button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.contentTintColor = .secondaryLabelColor
        button.target = context.coordinator
        button.action = #selector(Coordinator.present(_:))
        context.coordinator.urls = urls
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.urls = urls
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var urls: [URL] = []

        @objc func present(_ sender: NSButton) {
            guard !urls.isEmpty else { return }
            let picker = NSSharingServicePicker(items: urls)
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
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
