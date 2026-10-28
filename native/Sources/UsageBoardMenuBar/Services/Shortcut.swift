import Carbon

final class BoardShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    func register() -> Bool {
        unregister()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<BoardShortcut>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { owner.action?() }
            return noErr
        }, 1, &type, context, &handler)
        guard status == noErr else { return false }
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_U), UInt32(cmdKey | shiftKey),
                                         EventHotKeyID(signature: 0x55424F41, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { unregister() }
        return result == noErr
    }
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil
    }
    deinit { unregister() }
}
