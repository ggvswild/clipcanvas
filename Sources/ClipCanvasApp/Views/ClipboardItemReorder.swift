import ClipCanvasCore
import Foundation

enum ClipboardItemReorder {
    static func ids(
        in items: [ClipboardItem],
        moving movingID: UUID,
        onto targetID: UUID,
        insertAfter: Bool
    ) -> [UUID]? {
        guard let from = items.firstIndex(where: { $0.id == movingID }),
              let to = items.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }
        guard movingID != targetID else {
            return items.map(\.id)
        }

        var ids = items.map(\.id)
        ids.remove(at: from)

        var destination = to
        if from < to {
            destination -= 1
        }
        if insertAfter {
            destination += 1
        }
        destination = min(max(0, destination), ids.count)
        ids.insert(movingID, at: destination)
        return ids
    }
}
