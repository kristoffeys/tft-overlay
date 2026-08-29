import AppKit
import OverlayKit

/// The overlay's rebindable hotkey actions and their factory defaults.
/// The single source of truth for both `AppDelegate`'s registration and
/// `GeneralSettings`' default bindings, so the two can never drift.
enum AppHotkeyAction: String, CaseIterable, Codable {
    case toggleInteractive
    case toggleLayout
    case toggleVisibility
    case cycleForward
    case cycleBackward

    var action: HotkeyAction {
        HotkeyAction(id: rawValue)
    }

    var displayName: String {
        switch self {
        case .toggleInteractive: "Toggle Interactive Mode"
        case .toggleLayout: "Toggle Compact / Expanded"
        case .toggleVisibility: "Show / Hide Overlay"
        case .cycleForward: "Next Panel"
        case .cycleBackward: "Previous Panel"
        }
    }

    var defaultHotkey: Hotkey {
        switch self {
        case .toggleInteractive: Hotkey(keyCode: 31, modifierFlags: .option) // Option+O
        case .toggleLayout: Hotkey(keyCode: 37, modifierFlags: .option) // Option+L
        case .toggleVisibility: Hotkey(keyCode: 4, modifierFlags: .option) // Option+H
        case .cycleForward: Hotkey(keyCode: 8, modifierFlags: .option) // Option+C
        case .cycleBackward: Hotkey(keyCode: 8, modifierFlags: [.option, .shift]) // Option+Shift+C
        }
    }
}
