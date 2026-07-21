import CoreGraphics

struct PanelPetPerchLayout: Equatable {
    static let standard = PanelPetPerchLayout(
        windowWidth: 112,
        windowHeight: 94,
        petWidth: 78,
        petHeight: 82,
        trailingInset: 22
    )

    let windowWidth: CGFloat
    let windowHeight: CGFloat
    let petWidth: CGFloat
    let petHeight: CGFloat
    let trailingInset: CGFloat

    func petWindowFrame(above panelFrame: CGRect) -> CGRect {
        CGRect(
            x: panelFrame.maxX - trailingInset - windowWidth,
            y: panelFrame.maxY,
            width: windowWidth,
            height: windowHeight
        )
    }
}
