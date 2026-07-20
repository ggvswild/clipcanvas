import SwiftUI

enum PinboardColorPalette {
    static let supportedNames = [
        "cyan",
        "blue",
        "purple",
        "pink",
        "orange",
        "green"
    ]

    static func color(for name: String) -> Color {
        switch name {
        case "blue":
            .blue
        case "purple":
            .purple
        case "pink":
            .pink
        case "orange":
            .orange
        case "green":
            .green
        default:
            .cyan
        }
    }
}
