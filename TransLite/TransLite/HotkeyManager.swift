import Carbon
import AppKit

/// Manages global keyboard shortcuts using Carbon Hot Key APIs
final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onSingleTap: () -> Void
    private let onDoubleTap: () -> Void
    private var currentKeyCode: UInt32 = 17 // Default: T

    // Double-tap detection
    private var lastTapTime: Date?
    private var pendingTimer: Timer?
    private let doubleTapInterval: TimeInterval = 0.3 // 300ms

    // Unique identifier for our hotkey
    private let hotkeyID = EventHotKeyID(signature: OSType(0x5442_4152), id: 1) // "TBAR"

    // Default key code for 'T'
    static let defaultKeyCode: UInt32 = 17

    init(onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void) {
        self.onSingleTap = onSingleTap
        self.onDoubleTap = onDoubleTap
    }

    deinit {
        unregisterHotkey()
    }

    /// Registers the global hotkey (Cmd+Shift+<key>)
    func registerHotkey(keyCode: UInt32? = nil) {
        currentKeyCode = keyCode ?? Self.defaultKeyCode
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        let hotKeyID = hotkeyID

        // Register the hotkey
        let status = RegisterEventHotKey(
            currentKeyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard status == noErr else {
            print("Failed to register hotkey: \(status)")
            return
        }

        // Install event handler
        installEventHandler()
    }

    /// Unregisters the global hotkey
    func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// Updates the hotkey to use a new key code
    func updateHotkey(keyCode: UInt32) {
        unregisterHotkey()
        registerHotkey(keyCode: keyCode)
    }

    // MARK: - Double-Tap Detection

    private func handleHotkeyPressed() {
        let now = Date()

        // Cancel any pending single-tap timer
        pendingTimer?.invalidate()
        pendingTimer = nil

        // Check if this is a double-tap
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < doubleTapInterval {
            // Double-tap detected
            lastTapTime = nil
            onDoubleTap()
        } else {
            // Possible single-tap - wait to see if another tap comes
            lastTapTime = now
            pendingTimer = Timer.scheduledTimer(withTimeInterval: doubleTapInterval, repeats: false) { [weak self] _ in
                self?.lastTapTime = nil
                self?.onSingleTap()
            }
        }
    }

    // MARK: - Key Code Helpers

    /// Converts a character to its key code
    static func keyCode(for character: Character) -> UInt32? {
        let keyCodeMap: [Character: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47
        ]
        return keyCodeMap[Character(character.lowercased())]
    }

    /// Converts a key code to its character
    static func character(for keyCode: UInt32) -> Character? {
        let characterMap: [UInt32: Character] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: "."
        ]
        return characterMap[keyCode]
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // We need to capture self in a way that Carbon callbacks can use
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }

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

                guard status == noErr else { return status }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                // Check if this is our hotkey
                if hotKeyID.signature == manager.hotkeyID.signature && hotKeyID.id == manager.hotkeyID.id {
                    DispatchQueue.main.async {
                        manager.handleHotkeyPressed()
                    }
                    return noErr
                }

                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        if status != noErr {
            print("Failed to install event handler: \(status)")
        }
    }
}
