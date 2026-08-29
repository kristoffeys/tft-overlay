import AppKit
@testable import OverlayKit
import XCTest

@MainActor
final class HotkeyManagerTests: XCTestCase {
    private func hotkey(_ keyCode: UInt16, _ flags: NSEvent.ModifierFlags = .option) -> Hotkey {
        Hotkey(keyCode: keyCode, modifierFlags: flags)
    }

    func testRegisterNewActionSucceeds() {
        let manager = HotkeyManager()
        let action = HotkeyAction(id: "toggleInteractive")

        let result = manager.register(hotkey(31), for: action) {}

        XCTAssertEqual(result, .registered)
        XCTAssertEqual(manager.hotkey(for: action), hotkey(31))
    }

    func testRegisterConflictingHotkeyIsRefused() {
        let manager = HotkeyManager()
        let first = HotkeyAction(id: "toggleInteractive")
        let second = HotkeyAction(id: "toggleLayout")

        XCTAssertEqual(manager.register(hotkey(31), for: first) {}, .registered)
        let result = manager.register(hotkey(31), for: second) {}

        XCTAssertEqual(result, .conflict(first))
        // The conflicting registration must not have taken effect.
        XCTAssertNil(manager.hotkey(for: second))
        XCTAssertEqual(manager.hotkey(for: first), hotkey(31))
    }

    func testConflictingActionExcludesSelf() {
        let manager = HotkeyManager()
        let action = HotkeyAction(id: "toggleInteractive")
        _ = manager.register(hotkey(31), for: action) {}

        // Rebinding an action to the key it already owns is not a conflict.
        XCTAssertNil(manager.conflictingAction(for: hotkey(31), excluding: action))
        // But it is a conflict for any other action.
        XCTAssertEqual(manager.conflictingAction(for: hotkey(31)), action)
    }

    func testUnregisterFreesHotkeyForReuse() {
        let manager = HotkeyManager()
        let first = HotkeyAction(id: "toggleInteractive")
        let second = HotkeyAction(id: "toggleLayout")
        _ = manager.register(hotkey(31), for: first) {}

        manager.unregister(first)

        XCTAssertNil(manager.hotkey(for: first))
        XCTAssertEqual(manager.register(hotkey(31), for: second) {}, .registered)
    }

    func testRebindingReplacesPreviousHotkeyForSameAction() {
        let manager = HotkeyManager()
        let action = HotkeyAction(id: "toggleInteractive")
        _ = manager.register(hotkey(31), for: action) {}

        _ = manager.register(hotkey(4), for: action) {}

        XCTAssertEqual(manager.hotkey(for: action), hotkey(4))
        // The old combination is free again.
        XCTAssertNil(manager.conflictingAction(for: hotkey(31)))
    }

    func testHotkeyFormattingIncludesModifiersAndKeyLabel() {
        let combo = Hotkey(keyCode: 31, modifierFlags: .option)
        XCTAssertEqual(HotkeyFormatting.displayString(for: combo), "⌥O")

        let multi = Hotkey(keyCode: 8, modifierFlags: [.option, .shift])
        XCTAssertEqual(HotkeyFormatting.displayString(for: multi), "⌥⇧C")
    }
}
