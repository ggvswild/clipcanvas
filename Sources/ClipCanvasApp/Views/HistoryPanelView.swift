import ClipCanvasCore
import SwiftUI

struct HistoryPanelView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            header
            content
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(2)
        .preferredColorScheme(.dark)
        .onChange(of: model.searchFocusRequestID) {
            searchFocused = model.isSearchFocused
        }
        .onChange(of: searchFocused) { _, isFocused in
            model.updateSearchFocus(isFocused)
        }
        .sheet(isPresented: $model.isPreviewPresented) {
            if let item = model.selectedItem {
                ItemPreviewView(item: item, imageData: model.imageData(for: item))
            }
        }
        .sheet(isPresented: $model.isCreatePinboardPresented) {
            PinboardEditorView { name, color, symbol in
                model.createPinboard(name: name, color: color, symbol: symbol)
            }
        }
        .confirmationDialog(
            "delete.title",
            isPresented: $model.isDeleteConfirmationPresented
        ) {
            Button("delete.confirm", role: .destructive) {
                model.deleteSelected()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("delete.message")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("search.placeholder", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { model.reload() }
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                        model.reload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 220, height: 30)
            .background(.white.opacity(0.08), in: Capsule())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(model.pinboardTabs.enumerated()), id: \.offset) { _, pinboard in
                        if let pinboard {
                            Button {
                                model.selectPinboard(pinboard.id)
                            } label: {
                                Label(pinboard.name, systemImage: pinboard.symbol)
                                    .lineLimit(1)
                            }
                            .buttonStyle(PanelTabButtonStyle(
                                selected: model.selectedPinboardID == pinboard.id,
                                tint: PinboardColorPalette.color(for: pinboard.color)
                            ))
                            .contextMenu {
                                if !pinboard.isSystem {
                                    Button("pinboard.delete", role: .destructive) {
                                        model.deletePinboard(pinboard.id)
                                    }
                                }
                            }
                        } else {
                            Button {
                                model.selectPinboard(nil)
                            } label: {
                                Label("panel.clipboard", systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(PanelTabButtonStyle(
                                selected: model.selectedPinboardID == nil,
                                tint: .blue
                            ))
                        }
                    }
                }
                .frame(minWidth: 380, alignment: .center)
            }
            .frame(width: 380)
            .mask {
                LinearGradient(
                    stops: [
                        .init(
                            color: .black.opacity(pinboardStripFade.edgeOpacity),
                            location: 0
                        ),
                        .init(
                            color: .black.opacity(pinboardStripFade.contentOpacity),
                            location: pinboardStripFade.leadingContentLocation
                        ),
                        .init(
                            color: .black.opacity(pinboardStripFade.contentOpacity),
                            location: pinboardStripFade.trailingContentLocation
                        ),
                        .init(
                            color: .black.opacity(pinboardStripFade.edgeOpacity),
                            location: 1
                        )
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }

            Button {
                model.requestCreatePinboard()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("pinboard.create")

            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("common.refresh")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32, alignment: .center)
        .padding(.horizontal, 4)
        .onChange(of: model.query) { _, query in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                if model.query == query {
                    model.reload()
                }
            }
        }
    }

    private var pinboardStripFade: PinboardStripEdgeFadeAppearance {
        .soft
    }

    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: model.query.isEmpty ? "rectangle.stack" : "magnifyingglass")
            } description: {
                Text(emptyDescription)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            cardScroller
        }
    }

    private var cardScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 11) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        clipboardCard(item, index: index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            }
            .onChange(of: model.selectedItemID) { _, selectedID in
                if let selectedID {
                    withAnimation(.snappy) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }
        }
    }

    private func clipboardCard(_ item: ClipboardItem, index: Int) -> some View {
        ClipboardCardView(
            item: item,
            isSelected: model.selectedItemID == item.id,
            quickPasteIndex: index < 9 ? index + 1 : nil,
            imageData: model.imageData(for: item)
        )
        .id(item.id)
        .onTapGesture {
            model.selectedItemID = item.id
        }
        .onTapGesture(count: 2) {
            Task { await model.paste(item) }
        }
        .contextMenu {
            Button("action.paste") {
                Task { await model.paste(item) }
            }
            Button("action.paste_plain") {
                Task { await model.paste(item, forcePlainText: true) }
            }
            Menu("action.pin_to") {
                ForEach(model.pinboards) { pinboard in
                    Button(pinboard.name) {
                        model.pin(item, to: pinboard.id)
                    }
                }
            }
            Divider()
            Button("action.preview") {
                model.selectedItemID = item.id
                model.isPreviewPresented = true
            }
            Button("action.delete", role: .destructive) {
                model.selectedItemID = item.id
                model.requestDeleteSelected()
            }
        }
    }

    private var emptyTitle: LocalizedStringKey {
        model.query.isEmpty ? "empty.history.title" : "empty.search.title"
    }

    private var emptyDescription: LocalizedStringKey {
        model.query.isEmpty ? "empty.history.description" : "empty.search.description"
    }
}

struct PinboardStripEdgeFadeAppearance: Equatable {
    static let soft = PinboardStripEdgeFadeAppearance(
        edgeOpacity: 0,
        contentOpacity: 1,
        fadeFraction: 0.06
    )

    let edgeOpacity: Double
    let contentOpacity: Double
    let fadeFraction: CGFloat

    var leadingContentLocation: CGFloat {
        fadeFraction
    }

    var trailingContentLocation: CGFloat {
        1 - fadeFraction
    }
}

private struct PanelTabButtonStyle: ButtonStyle {
    let selected: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let appearance = PinboardTabAppearance.readable

        configuration.label
            .font(.caption.weight(selected ? .bold : .semibold))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .foregroundStyle(
                Color.white.opacity(selected ? 1 : 0.9)
            )
            .background(
                tint.opacity(
                    selected
                        ? appearance.selectedBackgroundOpacity
                        : appearance.defaultBackgroundOpacity
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        selected
                            ? Color.white.opacity(appearance.selectedBorderOpacity)
                            : tint.opacity(appearance.defaultBorderOpacity),
                        lineWidth: selected
                            ? appearance.selectedBorderWidth
                            : appearance.defaultBorderWidth
                    )
            }
            .shadow(
                color: selected
                    ? tint.opacity(appearance.selectedShadowOpacity)
                    : .clear,
                radius: selected ? 5 : 0,
                y: selected ? 1 : 0
            )
            .scaleEffect(
                selected ? appearance.selectedScale : appearance.defaultScale
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.snappy(duration: 0.16), value: selected)
    }
}

struct PinboardTabAppearance: Equatable {
    static let readable = PinboardTabAppearance(
        defaultBackgroundOpacity: 0.28,
        selectedBackgroundOpacity: 0.82,
        defaultBorderOpacity: 0.38,
        selectedBorderOpacity: 0.46,
        defaultBorderWidth: 0.75,
        selectedBorderWidth: 1.4,
        defaultScale: 1,
        selectedScale: 1.025,
        selectedShadowOpacity: 0.22
    )

    let defaultBackgroundOpacity: Double
    let selectedBackgroundOpacity: Double
    let defaultBorderOpacity: Double
    let selectedBorderOpacity: Double
    let defaultBorderWidth: CGFloat
    let selectedBorderWidth: CGFloat
    let defaultScale: CGFloat
    let selectedScale: CGFloat
    let selectedShadowOpacity: Double
}
