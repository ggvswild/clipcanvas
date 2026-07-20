import ClipCanvasCore
import SwiftUI

struct PinboardsSettingsView: View {
    @EnvironmentObject private var model: AppModel

    @State private var state = PinboardManagementState()
    @State private var editorPinboard: Pinboard?
    @State private var isCreating = false
    @State private var deleteCandidate: Pinboard?

    var body: some View {
        HStack(spacing: 12) {
            pinboardList
                .frame(width: 190)
            contentPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: reconcileAndLoad)
        .onReceive(model.$pinboards) { _ in
            reconcileAndLoad()
        }
        .onChange(of: state.selectedPinboardID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            state.query = ""
            loadSelected()
        }
        .sheet(isPresented: $isCreating) {
            createEditor
        }
        .sheet(item: $editorPinboard) { pinboard in
            editEditor(pinboard)
        }
        .alert(
            "pinboard.delete",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            presenting: deleteCandidate
        ) { pinboard in
            Button("common.cancel", role: .cancel) {}
            Button("pinboard.delete", role: .destructive) {
                model.deletePinboard(pinboard.id)
                deleteCandidate = nil
            }
        } message: { _ in
            Text("pinboard.delete_preserves_history")
        }
    }

    private var pinboardList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("settings.pinboards")
                    .font(.headline)
                Spacer()
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "pinboard.create"))
            }
            .padding(.horizontal, 4)

            List(selection: $state.selectedPinboardID) {
                ForEach(model.pinboards.filter(\.isSystem)) { pinboard in
                    pinboardRow(pinboard)
                        .tag(pinboard.id)
                }
                ForEach(model.pinboards.filter { !$0.isSystem }) { pinboard in
                    pinboardRow(pinboard)
                        .tag(pinboard.id)
                }
                .onMove { source, destination in
                    model.reorderPinboards(
                        ids: state.reorderedOrdinaryIDs(
                            pinboards: model.pinboards,
                            fromOffsets: source,
                            toOffset: destination
                        )
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .padding(12)
        .background(
            .white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }

    private func pinboardRow(_ pinboard: Pinboard) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(PinboardColorPalette.color(for: pinboard.color))
                .frame(width: 8, height: 8)
            Image(systemName: pinboard.symbol)
                .frame(width: 16)
            Text(pinboard.name)
                .lineLimit(1)
            Spacer(minLength: 4)
            if pinboard.isSystem {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help(String(localized: "pinboard.system_locked"))
            }
        }
        .padding(.vertical, 3)
    }

    private var contentPane: some View {
        VStack(spacing: 12) {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let selectedPinboard {
                contentHeader(selectedPinboard)
                TextField("pinboard.search", text: $state.query)
                    .textFieldStyle(.roundedBorder)

                if state.filteredItems.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: state.query.isEmpty
                            ? "pin.slash"
                            : "magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(state.filteredItems) { item in
                                candidateRow(
                                    item,
                                    pinboardID: selectedPinboard.id
                                )
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "pinboard.empty_groups",
                    systemImage: "square.grid.2x2",
                    description: Text("pinboard.empty_groups.description")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .background(
            .white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var selectedPinboard: Pinboard? {
        guard let id = state.selectedPinboardID else {
            return nil
        }
        return model.pinboards.first { $0.id == id }
    }

    private var emptyTitle: LocalizedStringKey {
        state.query.isEmpty ? "pinboard.empty" : "pinboard.no_results"
    }

    private func contentHeader(_ pinboard: Pinboard) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        PinboardColorPalette.color(for: pinboard.color)
                            .opacity(0.28)
                    )
                Image(systemName: pinboard.symbol)
                    .foregroundStyle(
                        PinboardColorPalette.color(for: pinboard.color)
                    )
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(pinboard.name)
                    .font(.headline)
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "pinboard.items_count"),
                        state.items.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !pinboard.isSystem {
                Button("pinboard.edit") {
                    editorPinboard = pinboard
                }
                Button("pinboard.delete", role: .destructive) {
                    deleteCandidate = pinboard
                }
            }
        }
    }

    private func candidateRow(
        _ item: ClipboardItem,
        pinboardID: UUID
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: itemSymbol(for: item.kind))
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? item.plainText ?? item.kind.rawValue)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(item.source.name)
                    Text("·")
                    Text(
                        item.lastCopiedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("pinboard.remove") {
                if model.unpin(itemID: item.id, from: pinboardID) {
                    state.remove(itemID: item.id)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(
            .white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.045), lineWidth: 1)
        }
    }

    private var createEditor: some View {
        PinboardEditorView { name, color, symbol in
            guard let created = model.createPinboard(
                name: name,
                color: color,
                symbol: symbol,
                selecting: false
            ) else {
                return
            }
            state.selectedPinboardID = created.id
        }
    }

    private func editEditor(_ pinboard: Pinboard) -> some View {
        PinboardEditorView(pinboard: pinboard) { name, color, symbol in
            model.updatePinboard(
                id: pinboard.id,
                name: name,
                color: color,
                symbol: symbol
            )
        }
    }

    private func reconcileAndLoad() {
        let previousSelection = state.selectedPinboardID
        state.reconcile(pinboards: model.pinboards)
        if state.selectedPinboardID != previousSelection || state.items.isEmpty {
            loadSelected()
        }
    }

    private func loadSelected() {
        guard let id = state.selectedPinboardID else {
            state.items = []
            return
        }
        state.items = model.pinboardItems(in: id)
    }

    private func itemSymbol(for kind: ClipboardKind) -> String {
        switch kind {
        case .text:
            "text.alignleft"
        case .richText:
            "textformat"
        case .image:
            "photo"
        case .link:
            "link"
        case .files:
            "doc.on.doc"
        case .unknown:
            "questionmark.square"
        }
    }
}
