import AppKit
import ClipCanvasCore
import Foundation

final class CaptureService: @unchecked Sendable {
    typealias ConfigurationProvider = () -> PrivacyConfiguration
    typealias SourceProvider = () -> ClipboardSource
    typealias CaptureHandler = (ClipboardItem) -> Void

    private let pasteboard: NSPasteboard
    private let repository: ClipboardRepository
    private let configuration: ConfigurationProvider
    private let source: SourceProvider
    private let onCapture: CaptureHandler
    private let reader = PasteboardSnapshotReader()
    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        pasteboard: NSPasteboard = .general,
        repository: ClipboardRepository,
        captureExisting: Bool = false,
        configuration: @escaping ConfigurationProvider,
        source: @escaping SourceProvider,
        onCapture: @escaping CaptureHandler = { _ in }
    ) {
        self.pasteboard = pasteboard
        self.repository = repository
        lastChangeCount = captureExisting ? -1 : pasteboard.changeCount
        self.configuration = configuration
        self.source = source
        self.onCapture = onCapture
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            try? self?.captureNow()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func captureNow() throws {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        let typeNames = Set(pasteboard.types?.map(\.rawValue) ?? [])
        let candidate = CaptureCandidate(
            sourceBundleID: source().bundleID,
            types: typeNames,
            plainText: pasteboard.string(forType: .string)
        )
        guard PrivacyPolicy(configuration: configuration()).evaluate(candidate) == .allowed else {
            return
        }
        guard let draft = reader.read(from: pasteboard, source: source()) else {
            return
        }
        onCapture(try repository.upsert(draft))
    }
}
