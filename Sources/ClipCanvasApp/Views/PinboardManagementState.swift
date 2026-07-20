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

    mutating func remove(itemID: UUID) {
        items.removeAll { $0.id == itemID }
    }

    func reorderedOrdinaryIDs(
        pinboards: [Pinboard],
        fromOffsets: IndexSet,
        toOffset: Int
    ) -> [UUID] {
        var ordinary = pinboards.filter { !$0.isSystem }
        let validOffsets = fromOffsets
            .filter { ordinary.indices.contains($0) }
            .sorted()
        let moving = validOffsets.map { ordinary[$0] }

        for index in validOffsets.reversed() {
            ordinary.remove(at: index)
        }

        let removedBeforeDestination = validOffsets.filter { $0 < toOffset }.count
        let destination = min(
            max(0, toOffset - removedBeforeDestination),
            ordinary.count
        )
        ordinary.insert(contentsOf: moving, at: destination)
        return ordinary.map(\.id)
    }
}
