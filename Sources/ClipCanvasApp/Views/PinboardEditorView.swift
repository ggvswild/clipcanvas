import SwiftUI

struct PinboardEditorView: View {
    @State private var name = ""
    @State private var color = "cyan"
    @State private var symbol = "pin.fill"
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String, String, String) -> Void

    private let colors = ["cyan", "blue", "purple", "pink", "orange", "green"]
    private let symbols = ["pin.fill", "link", "book.fill", "star.fill", "briefcase.fill", "heart.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("pinboard.create")
                .font(.title2.bold())

            TextField("pinboard.name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("pinboard.color")
                    .font(.headline)
                HStack {
                    ForEach(colors, id: \.self) { candidate in
                        Button {
                            color = candidate
                        } label: {
                            Circle()
                                .fill(colorValue(candidate))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if color == candidate {
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
                            symbol = candidate
                        } label: {
                            Image(systemName: candidate)
                                .frame(width: 32, height: 28)
                                .background(
                                    symbol == candidate ? colorValue(color).opacity(0.35) : .clear,
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
                Button("pinboard.create") {
                    onCreate(name, color, symbol)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 390)
    }

    private func colorValue(_ name: String) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "orange": .orange
        case "green": .green
        default: .cyan
        }
    }
}
