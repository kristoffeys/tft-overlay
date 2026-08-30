@testable import TFTOverlay
import XCTest

final class AppSettingsTests: XCTestCase {
    func testDefaultsAreStableAndClamped() {
        let defaults = AppSettings.defaults

        XCTAssertEqual(defaults.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(defaults.overlay.opacity, 0.9)
        XCTAssertEqual(defaults.overlay.scale, 1.0)
        XCTAssertEqual(defaults.overlay.anchor, .bottomTrailing)
        XCTAssertEqual(defaults.data.activePatch, "auto")
        XCTAssertTrue(defaults.data.autoRefreshEnabled)
        XCTAssertFalse(defaults.general.launchAtLogin)
        // Every rebindable action has a factory default binding.
        for action in AppHotkeyAction.allCases {
            XCTAssertNotNil(defaults.general.hotkeys[action.rawValue], "missing default for \(action.rawValue)")
        }
    }

    func testOverlaySettingsClampsOutOfRangeValues() {
        let settings = OverlaySettings(opacity: 5.0, scale: -1, anchor: .topLeading, idleTimeoutSeconds: -10)

        XCTAssertEqual(settings.opacity, 1.0)
        XCTAssertEqual(settings.scale, 0.5)
        XCTAssertEqual(settings.idleTimeoutSeconds, 0)
    }

    func testDecodingEmptyJSONFallsBackToAllDefaults() throws {
        let data = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.general, .defaults)
        XCTAssertEqual(decoded.overlay, .defaults)
        XCTAssertEqual(decoded.data, .defaults)
        // schemaVersion missing entirely reads as 0, pre-migration.
        XCTAssertEqual(decoded.schemaVersion, 0)
    }

    func testDecodingPartialSectionFillsMissingFieldsWithDefaults() throws {
        let json = """
        { "overlay": { "opacity": 0.5 } }
        """
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.overlay.opacity, 0.5)
        XCTAssertEqual(decoded.overlay.scale, OverlaySettings.defaults.scale)
        XCTAssertEqual(decoded.overlay.anchor, OverlaySettings.defaults.anchor)
    }

    func testMigrationBackfillsHotkeyAddedAfterUserFirstSavedSettings() throws {
        // Simulates a persisted blob from before `cycleBackward` existed as
        // a rebindable action: schemaVersion 0, hotkeys missing that key.
        let json = """
        {
          "schemaVersion": 0,
          "general": { "launchAtLogin": true, "hotkeys": { "toggleInteractive": { "keyCode": 31, "modifierFlags": 524288 } } }
        }
        """
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertNil(decoded.general.hotkeys[AppHotkeyAction.cycleBackward.rawValue])

        let migrated = AppSettings.migrated(decoded)

        XCTAssertEqual(migrated.schemaVersion, AppSettings.currentSchemaVersion)
        // Pre-existing binding is preserved...
        XCTAssertEqual(migrated.general.hotkeys[AppHotkeyAction.toggleInteractive.rawValue]?.keyCode, 31)
        // ...and every action introduced since gets its factory default.
        for action in AppHotkeyAction.allCases {
            XCTAssertNotNil(
                migrated.general.hotkeys[action.rawValue],
                "missing binding for \(action.rawValue) after migration"
            )
        }
        XCTAssertEqual(
            migrated.general.hotkeys[AppHotkeyAction.cycleBackward.rawValue],
            AppHotkeyAction.cycleBackward.defaultHotkey
        )
        XCTAssertTrue(migrated.general.launchAtLogin)
    }

    func testMigrationIsIdempotent() {
        let once = AppSettings.migrated(.defaults)
        let twice = AppSettings.migrated(once)
        XCTAssertEqual(once, twice)
    }
}

/// The overlay ships unlocked, and cannot quietly lock itself.
///
/// It used to start click-through with no on-screen explanation, so every
/// affordance in the panel — search, filters, pins, tooltips — was
/// unreachable until the user discovered a hotkey nothing mentioned. The
/// two settings below are a pair: defaulting to unlocked is only coherent
/// if the idle timer that used to flip it back is off by default too,
/// otherwise the panel would re-lock itself seconds after every launch.
extension AppSettingsTests {
    func testOverlayStartsUnlockedAndDoesNotAutoLock() {
        XCTAssertTrue(OverlaySettings.defaults.startsUnlocked)
        XCTAssertFalse(OverlaySettings.defaults.autoLockWhenIdle)
    }

    /// Settings saved before these keys existed must adopt the new defaults
    /// rather than decoding as `false` and locking the overlay for anyone
    /// who had already run the app.
    func testSettingsPredatingTheLockKeysAdoptTheUnlockedDefault() throws {
        let json = """
        { "overlay": { "opacity": 0.5, "scale": 1.0, "anchor": "topLeading", "idleTimeoutSeconds": 8 } }
        """
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.overlay.startsUnlocked, "an existing user must not silently get a locked overlay")
        XCTAssertFalse(decoded.overlay.autoLockWhenIdle)
        // The fields that were present still decode.
        XCTAssertEqual(decoded.overlay.opacity, 0.5)
        XCTAssertEqual(decoded.overlay.anchor, .topLeading)
    }

    /// An explicit choice to lock survives a round trip — the default must
    /// not overwrite what the user actually set.
    func testExplicitLockChoiceRoundTrips() throws {
        var settings = AppSettings.defaults
        settings.overlay.startsUnlocked = false
        settings.overlay.autoLockWhenIdle = true

        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))

        XCTAssertFalse(decoded.overlay.startsUnlocked)
        XCTAssertTrue(decoded.overlay.autoLockWhenIdle)
    }
}
