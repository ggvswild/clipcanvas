import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class ScreenSharingMonitor: ObservableObject {
    @Published private(set) var isSharing = false

    private var timer: Timer?
    var onChange: ((Bool) -> Void)?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let detected = Self.detectSharingIndicator()
        guard detected != isSharing else { return }
        isSharing = detected
        onChange?(detected)
    }

    private static func detectSharingIndicator() -> Bool {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }
        let ownerHints = [
            "zoom", "teams", "webex", "slack", "discord",
            "screensharing", "screen sharing", "facetime"
        ]
        let titleHints = [
            "you are sharing", "screen sharing", "sharing your screen",
            "正在共享", "屏幕共享", "共享你的屏幕"
        ]
        return windowInfo.contains { info in
            let owner = (info[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let title = (info[kCGWindowName as String] as? String ?? "").lowercased()
            return ownerHints.contains(where: owner.contains)
                && titleHints.contains(where: title.contains)
        }
    }
}
