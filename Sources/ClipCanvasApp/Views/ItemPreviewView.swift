import AppKit
import ClipCanvasCore
import SwiftUI

struct ItemPreviewView: View {
    let item: ClipboardItem
    let imageData: Data?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(item.source.name, systemImage: "app")
                Spacer()
                Text(item.lastCopiedAt.formatted())
                    .foregroundStyle(.secondary)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            Divider()
            Group {
                if item.kind == .image,
                   let imageData,
                   let image = NSImage(data: imageData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ScrollView {
                        Text(item.plainText ?? item.metadata.fileNames.joined(separator: "\n"))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 440)
    }
}
