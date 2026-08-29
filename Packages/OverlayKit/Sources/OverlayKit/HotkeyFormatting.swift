import AppKit

/// Human-readable rendering of a `Hotkey`, for the preferences hotkey
/// recorder and any other UI listing current bindings.
///
/// Key-code-to-label uses the standard ANSI virtual key codes (US layout).
/// Live recording UI should prefer `NSEvent.charactersIgnoringModifiers`
/// from the captured event where possible; this table exists for
/// redisplaying a binding restored from storage, where no event is at hand.
public enum HotkeyFormatting {
    public static func displayString(for hotkey: Hotkey) -> String {
        modifierSymbols(for: hotkey.modifierFlags) + keyLabel(for: hotkey.keyCode)
    }

    private static func modifierSymbols(for rawFlags: UInt) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: rawFlags)
        var symbols = ""
        if flags.contains(.control) {
            symbols += "⌃"
        }
        if flags.contains(.option) {
            symbols += "⌥"
        }
        if flags.contains(.shift) {
            symbols += "⇧"
        }
        if flags.contains(.command) {
            symbols += "⌘"
        }
        return symbols
    }

    // Standard ANSI virtual key codes, per Carbon's HIToolbox constants.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 31: "O"
        case 32: "U"
        case 34: "I"
        case 35: "P"
        case 37: "L"
        case 38: "J"
        case 40: "K"
        case 45: "N"
        case 46: "M"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 25: "9"
        case 26: "7"
        case 28: "8"
        case 29: "0"
        case 36: "↩"
        case 48: "⇥"
        case 49: "Space"
        case 51: "⌫"
        case 53: "⎋"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        case 122: "F1"
        case 120: "F2"
        case 99: "F3"
        case 118: "F4"
        case 96: "F5"
        case 97: "F6"
        case 98: "F7"
        case 100: "F8"
        case 101: "F9"
        case 109: "F10"
        case 103: "F11"
        case 111: "F12"
        default: "Key \(keyCode)"
        }
    }
}
