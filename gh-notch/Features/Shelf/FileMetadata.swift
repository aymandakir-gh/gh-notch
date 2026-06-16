import Foundation
import UniformTypeIdentifiers

/// Broad file category used to pick an icon and a short label.
enum FileCategory: String {
    case image, pdf, text, audio, video, archive, folder, other

    var symbolName: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        case .audio: return "music.note"
        case .video: return "film"
        case .archive: return "archivebox"
        case .folder: return "folder"
        case .other: return "doc"
        }
    }

    var label: String {
        switch self {
        case .image: return "Image"
        case .pdf: return "PDF"
        case .text: return "Text"
        case .audio: return "Audio"
        case .video: return "Video"
        case .archive: return "Archive"
        case .folder: return "Folder"
        case .other: return "File"
        }
    }
}

/// Pure file-metadata helpers: human-readable size and type categorisation. All
/// deterministic and locale-stable so they can be unit-tested against fixtures.
enum FileMetadata {

    /// Finder-style decimal size ("999 B", "1 KB", "1.5 MB"). Uses '.' regardless of
    /// system locale so output is stable (matches the command bar's approach).
    static func humanSize(_ bytes: Int64) -> String {
        if bytes < 1000 { return "\(bytes) B" }
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unit = units[0]
        for candidate in units {
            value /= 1000
            unit = candidate
            if value < 1000 { break }
        }
        let rounded = (value * 10).rounded() / 10
        let number: String
        if rounded.rounded() == rounded {
            number = String(Int(rounded))
        } else {
            number = Self.decimalFormatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
        }
        return "\(number) \(unit)"
    }

    /// Category for a directory or a file extension.
    static func category(isDirectory: Bool, fileExtension: String) -> FileCategory {
        if isDirectory { return .folder }
        return category(forExtension: fileExtension)
    }

    /// Category from a bare file extension (e.g. "png").
    static func category(forExtension fileExtension: String) -> FileCategory {
        guard !fileExtension.isEmpty, let type = UTType(filenameExtension: fileExtension) else {
            return .other
        }
        return category(for: type)
    }

    static func category(for type: UTType) -> FileCategory {
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .archive) { return .archive }
        if type.conforms(to: .text) { return .text }
        return .other
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
