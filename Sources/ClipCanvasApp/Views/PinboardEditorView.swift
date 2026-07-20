import ClipCanvasCore
import SwiftUI

struct PinboardEditorDraft: Equatable {
    var name: String
    var color: String
    var symbol: String

    init(pinboard: Pinboard? = nil) {
        name = pinboard?.name ?? ""
        color = pinboard?.color ?? "cyan"
        symbol = pinboard?.symbol ?? "pin.fill"
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct PinboardEditorView: View {
    static let height: CGFloat = 285

    @State private var draft: PinboardEditorDraft
    @Environment(\.dismiss) private var dismiss

    private let isEditing: Bool
    private let onSave: (String, String, String) -> Void
    private let symbols = [
        "pin.fill",
        "link",
        "book.fill",
        "star.fill",
        "briefcase.fill",
        "heart.fill"
    ]

    init(
        pinboard: Pinboard? = nil,
        onSave: @escaping (String, String, String) -> Void
    ) {
        _draft = State(initialValue: PinboardEditorDraft(pinboard: pinboard))
        isEditing = pinboard != nil
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(actionTitle)
                .font(.title2.bold())

            TextField("pinboard.name", text: $draft.name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("pinboard.color")
                    .font(.headline)
                HStack {
                    ForEach(PinboardColorPalette.supportedNames, id: \.self) { candidate in
                        Button {
                            draft.color = candidate
                        } label: {
                            Circle()
                                .fill(PinboardColorPalette.color(for: candidate))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if draft.color == candidate {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("pinboard.symbol")
                    .font(.headline)
                HStack {
                    ForEach(symbols, id: \.self) { candidate in
                        Button {
                            draft.symbol = candidate
                        } label: {
                            Image(systemName: candidate)
                                .frame(width: 32, height: 28)
                                .background(
                                    draft.symbol == candidate
                                        ? PinboardColorPalette.color(for: draft.color).opacity(0.35)
                                        : .clear,
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("common.cancel") {
                    dismiss()
                }
                Button(actionTitle) {
                    onSave(draft.name, draft.color, draft.symbol)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.canSave)
            }
        }
        .padding(22)
        .frame(width: 390, height: Self.height)
    }

    private var actionTitle: LocalizedStringKey {
        isEditing ? "pinboard.edit" : "pinboard.create"
    }
}
