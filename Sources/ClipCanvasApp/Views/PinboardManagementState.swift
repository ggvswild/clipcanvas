import ClipCanvasCore
import Foundation

struct PinboardManagementState {
    var selectedPinboardID: UUID?
    var query = ""
    var items: [ClipboardItem] = []

    var filteredItems: [ClipboardItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return items
        }
        return items.filter { item in
            [item.title, item.plainText, item.source.name]
                .compactMap { $0 }
                .joined(separator: "\n")
                .localizedCaseInsensitiveContains(term)
        }
    }

    mutating func reconcile(pinboards: [Pinboard]) {
        guard !pinboards.isEmpty else {
            selectedPinboardID = nil
            query = ""
            items = []
            return
        }
        if let selectedPinboardID,
           pinboards.contains(where: { $0.id == selectedPinboardID }) {
            return
        }
        selectedPinboardID = pinboards.first?.id
        query = ""
        items = []
    }
}
