import AppKit
import Carbon

@MainActor
final class HotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    func register() {
        HotKeyDispatcher.onPressed = onPressed
        let hotKeyID = EventHotKeyID(signature: OSType("TDBR".fourCharCodeValue), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in
                HotKeyDispatcher.onPressed?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}

@MainActor
private enum HotKeyDispatcher {
    static var onPressed: (() -> Void)?
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
