import AppKit
import ClipCanvasCore
import SwiftUI

struct ClipboardCardView: View {
    static let height: CGFloat = 215

    let item: ClipboardItem
    let isSelected: Bool
    let quickPasteIndex: Int?
    let imageData: Data?

    var body: some View {
        VStack(spacing: 0) {
            header
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
            footer
        }
        .frame(width: 238, height: Self.height)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    isSelected ? kindColor : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 2.5 : 1
                )
        }
        .shadow(
            color: isSelected ? kindColor.opacity(0.26) : .black.opacity(0.14),
            radius: isSelected ? 10 : 4,
            y: 3
        )
        .scaleEffect(isSelected ? 1 : 0.985)
        .animation(.snappy(duration: 0.16), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: kindSymbol)
                .font(.caption.bold())
            Text(kindTitle)
                .font(.caption.bold())
            Spacer()
            Text(relativeTime)
                .font(.caption2)
                .lineLimit(1)
            sourceIcon
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(kindColor.gradient)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                ContentUnavailableView("", systemImage: "photo", description: Text("card.preview_unavailable"))
            }
        case .files:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.metadata.fileNames.prefix(4), id: \.self) { fileName in
                    Label(fileName, systemImage: "doc")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        case .link:
            VStack(alignment: .leading, spacing: 7) {
                Text(item.title ?? item.metadata.domain ?? "Link")
                    .font(.headline)
                    .lineLimit(2)
                Text(item.plainText ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        default:
            Text(displayText)
                .font(.system(.callout, design: item.kind == .richText ? .default : .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(6)
                .textSelection(.disabled)
        }
    }

    private var footer: some View {
        HStack {
            Text(metadataText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if let quickPasteIndex {
                Text("⌘\(quickPasteIndex)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 27)
        .background(.black.opacity(0.1))
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let path = item.source.iconPath,
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 21, height: 21)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: "app.fill")
                .frame(width: 21, height: 21)
        }
    }

    private var displayText: String {
        let text = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text! : String(localized: "card.preview_unavailable")
    }

    private var metadataText: String {
        switch item.kind {
        case .image:
            if let width = item.metadata.imageWidth, let height = item.metadata.imageHeight {
                return "\(width) × \(height)"
            }
            return ByteCountFormatter.string(
                fromByteCount: Int64(item.metadata.byteCount ?? 0),
                countStyle: .file
            )
        case .files:
            return String(
                format: NSLocalizedString("card.files_count", comment: ""),
                item.metadata.fileCount ?? item.metadata.fileNames.count
            )
        default:
            return String(
                format: NSLocalizedString("card.characters_count", comment: ""),
                item.plainText?.count ?? 0
            )
        }
    }

    private var kindTitle: String {
        switch item.kind {
        case .text: String(localized: "kind.text")
        case .richText: String(localized: "kind.richText")
        case .image: String(localized: "kind.image")
        case .link: String(localized: "kind.link")
        case .files: String(localized: "kind.files")
        case .unknown: String(localized: "kind.unknown")
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.lastCopiedAt, relativeTo: Date())
    }

    private var kindSymbol: String {
        switch item.kind {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .image: "photo"
        case .link: "link"
        case .files: "doc.on.doc"
        case .unknown: "questionmark.square"
        }
    }

    private var kindColor: Color {
        switch item.kind {
        case .text: .blue
        case .richText: .indigo
        case .image: .pink
        case .link: .cyan
        case .files: .orange
        case .unknown: .gray
        }
    }

    private var accessibilityLabel: String {
        "\(kindTitle), \(item.source.name), \(displayText)"
    }
}
