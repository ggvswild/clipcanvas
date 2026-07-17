import Carbon
import ClipCanvasCore
import Foundation

final class GlobalHotKeyService: @unchecked Sendable {
    typealias Handler = @Sendable () -> Void

    private var eventHandler: EventHandlerRef?
    private var hotKeyReferences: [ShortcutAction: EventHotKeyRef] = [:]
    private var handlers: [UInt32: Handler] = [:]

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return OSStatus(eventNotHandledErr)
            }
            let service = Unmanaged<GlobalHotKeyService>
                .fromOpaque(userData)
                .takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, let handler = service.handlers[hotKeyID.id] else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async(execute: handler)
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        for reference in hotKeyReferences.values {
            UnregisterEventHotKey(reference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    @discardableResult
    func register(
        action: ShortcutAction,
        shortcut: KeyboardShortcut,
        handler: @escaping Handler
    ) -> OSStatus {
        unregister(action: action)
        let id = UInt32(actionIndex(action) + 1)
        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: id
        )
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers.rawValue,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if status == noErr, let reference {
            hotKeyReferences[action] = reference
            handlers[id] = handler
        }
        return status
    }

    func unregister(action: ShortcutAction) {
        if let reference = hotKeyReferences.removeValue(forKey: action) {
            UnregisterEventHotKey(reference)
        }
        handlers.removeValue(forKey: UInt32(actionIndex(action) + 1))
    }

    private func actionIndex(_ action: ShortcutAction) -> Int {
        ShortcutAction.allCases.firstIndex(of: action) ?? 0
    }

    private static let signature: OSType = {
        let scalars = Array("ClCv".utf8)
        return scalars.reduce(0) { ($0 << 8) | OSType($1) }
    }()
}
