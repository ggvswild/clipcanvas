import Combine
import ClipCanvasCore
import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var isPanelPresented = false
    @Published var isCapturePaused = false
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var pinboards: [Pinboard] = []
    @Published private(set) var searchFocusRequestID = 0
    @Published var selectedItemID: UUID?
    @Published var selectedPinboardID: UUID?
    @Published var query = ""
    @Published var isStackMode = false
    @Published var errorMessage: String?
    @Published var isPreviewPresented = false
    @Published var isDeleteConfirmationPresented = false
    @Published var isCreatePinboardPresented = false
    @Published var isScreenSharingActive = false

    private var repository: ClipboardRepository?
    private var pasteService: PasteService?
    private var targetApplication: (() -> NSRunningApplication?)?
    private var hidePanelHandler: (() -> Void)?
    var pasteStrategy: PasteStrategy = .activeApp
    var alwaysPastePlainText = false

    func togglePanel() {
        isPanelPresented.toggle()
    }

    func hidePanel() {
        isPanelPresented = false
    }

    func requestSearchFocus() {
        searchFocusRequestID += 1
    }

    func configure(
        repository: ClipboardRepository,
        pasteService: PasteService,
        targetApplication: @escaping () -> NSRunningApplication?,
        hidePanel: @escaping () -> Void
    ) {
        self.repository = repository
        self.pasteService = pasteService
        self.targetApplication = targetApplication
        hidePanelHandler = hidePanel
        reload()
    }

    func replaceItems(_ newItems: [ClipboardItem]) {
        let previousSelection = selectedItemID
        items = newItems
        if let previousSelection,
           newItems.contains(where: { $0.id == previousSelection }) {
            selectedItemID = previousSelection
        } else {
            selectedItemID = newItems.first?.id
        }
    }

    func replacePinboards(_ newPinboards: [Pinboard]) {
        pinboards = newPinboards
        if let selectedPinboardID,
           newPinboards.contains(where: { $0.id == selectedPinboardID }) {
            return
        }
        selectedPinboardID = nil
    }

    func moveSelection(by offset: Int) {
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }
        let currentIndex = selectedItemID.flatMap { selectedID in
            items.firstIndex(where: { $0.id == selectedID })
        } ?? 0
        let nextIndex = min(max(0, currentIndex + offset), items.count - 1)
        selectedItemID = items[nextIndex].id
    }

    func itemForQuickPaste(index: Int) -> ClipboardItem? {
        guard index >= 1, index <= min(9, items.count) else {
            return nil
        }
        return items[index - 1]
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else { return nil }
        return items.first(where: { $0.id == selectedItemID })
    }

    var pinboardTabs: [Pinboard?] {
        [nil] + pinboards.map(Optional.some)
    }

    var isPresentingSheet: Bool {
        isPreviewPresented || isDeleteConfirmationPresented || isCreatePinboardPresented
    }

    func reload() {
        guard let repository else { return }
        do {
            replacePinboards(try repository.listPinboards())
            let page: HistoryPage
            if let selectedPinboardID {
                page = try repository.items(in: selectedPinboardID, limit: 100)
            } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                page = try repository.search(query, limit: 100)
            } else {
                page = try repository.list(.init(limit: 100))
            }
            replaceItems(page.items)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func received(_ item: ClipboardItem) {
        reload()
        selectedItemID = item.id
    }

    func selectPinboard(_ id: UUID?) {
        selectedPinboardID = id
        reload()
    }

    func selectAdjacentPinboard(offset: Int) {
        let destinations = pinboardTabs.map { $0?.id }
        guard !destinations.isEmpty else { return }
        let current = destinations.firstIndex(where: { $0 == selectedPinboardID }) ?? 0
        let next = (current + offset + destinations.count) % destinations.count
        selectPinboard(destinations[next])
    }

    func pasteSelected(forcePlainText: Bool = false) async {
        guard let selectedItem else { return }
        await paste(selectedItem, forcePlainText: forcePlainText)
    }

    func paste(_ item: ClipboardItem, forcePlainText: Bool = false) async {
        guard let pasteService else { return }
        hidePanelHandler?()
        do {
            try await pasteService.perform(
                item: item,
                strategy: pasteStrategy,
                plainText: alwaysPastePlainText || forcePlainText,
                targetApplication: targetApplication?()
            )
            if SettingsStore.shared.soundEffects {
                NSSound(named: "Tink")?.play()
            }
            errorMessage = nil
        } catch PasteError.accessibilityDenied {
            pasteStrategy = .clipboardOnly
            errorMessage = String(localized: "error.accessibility")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestDeleteSelected() {
        guard selectedItem != nil else { return }
        isDeleteConfirmationPresented = true
    }

    func deleteSelected() {
        guard let selectedItemID, let repository else { return }
        do {
            try repository.delete(id: selectedItemID)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pin(_ item: ClipboardItem, to pinboardID: UUID) {
        guard let repository else { return }
        do {
            try repository.pin(itemID: item.id, to: pinboardID)
            if selectedPinboardID == pinboardID {
                reload()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestCreatePinboard() {
        isCreatePinboardPresented = true
    }

    func createPinboard(name: String, color: String, symbol: String) {
        guard let repository else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "pinboard.name_required")
            return
        }
        do {
            let pinboard = try repository.createPinboard(
                name: trimmedName,
                color: color,
                symbol: symbol
            )
            replacePinboards(try repository.listPinboards())
            selectPinboard(pinboard.id)
            isCreatePinboardPresented = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePinboard(_ id: UUID) {
        guard let repository else { return }
        do {
            try repository.deletePinboard(id: id)
            if selectedPinboardID == id {
                selectedPinboardID = nil
            }
            reload()
            errorMessage = nil
        } catch ClipboardRepositoryError.systemPinboardCannotBeDeleted {
            errorMessage = String(localized: "pinboard.system_delete_error")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func imageData(for item: ClipboardItem) -> Data? {
        guard item.kind == .image,
              let representation = item.representations.first,
              let repository else {
            return nil
        }
        return try? repository.representationData(representation)
    }

    func eraseHistory(preservingPinned: Bool) {
        guard let repository else { return }
        do {
            try repository.eraseHistory(preservingPinned: preservingPinned)
            reload()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enforceRetention(_ period: RetentionPeriod) {
        guard let repository,
              let cutoff = period.cutoff() else {
            return
        }
        do {
            try repository.deleteItems(olderThan: cutoff, preservingPinned: true)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
