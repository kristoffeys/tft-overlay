import Foundation
import OverlayKit

/// Where the overlay panel should sit on screen. Mirrors `OverlayAnchor`
/// (OverlayKit) with a `String` `RawValue` so it round-trips through
/// `UserDefaults`/JSON without OverlayKit needing `Codable` conformance on a
/// type that's otherwise pure AppKit-facing.
enum OverlayAnchorPreference: String, Codable, CaseIterable, Equatable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var overlayAnchor: OverlayAnchor {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    var displayName: String {
        switch self {
        case .topLeading: "Top Left"
        case .topTrailing: "Top Right"
        case .bottomLeading: "Bottom Left"
        case .bottomTrailing: "Bottom Right"
        }
    }
}

/// General app-wide preferences: launch behavior and rebindable hotkeys.
struct GeneralSettings: Codable, Equatable {
    var launchAtLogin: Bool
    var hotkeys: [String: Hotkey]

    static let defaults = GeneralSettings(
        launchAtLogin: false,
        hotkeys: Dictionary(uniqueKeysWithValues: AppHotkeyAction.allCases.map { ($0.rawValue, $0.defaultHotkey) })
    )

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin, hotkeys
    }

    init(launchAtLogin: Bool, hotkeys: [String: Hotkey]) {
        self.launchAtLogin = launchAtLogin
        self.hotkeys = hotkeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hotkeys = try container.decodeIfPresent([String: Hotkey].self, forKey: .hotkeys) ?? [:]
    }
}

/// Overlay appearance/behavior preferences. Values are clamped to the same
/// ranges `OverlayPanelController` itself enforces, so a hand-edited
/// defaults blob can't produce an invalid opacity/scale.
struct OverlaySettings: Codable, Equatable {
    var opacity: Double
    var scale: Double
    var anchor: OverlayAnchorPreference
    var idleTimeoutSeconds: Double
    /// Whether the overlay accepts clicks on launch. On by default — the
    /// overlay is meant to be usable standalone, and a panel that ignores
    /// every click until you discover a hotkey is a dead end.
    var startsUnlocked: Bool
    /// Whether an idle spell locks the overlay back to click-through.
    /// Off by default, since with `startsUnlocked` it would otherwise undo
    /// the user's default seconds after launch.
    var autoLockWhenIdle: Bool

    static let defaults = OverlaySettings(
        opacity: 0.9,
        scale: 1.0,
        anchor: .bottomTrailing,
        idleTimeoutSeconds: 8,
        startsUnlocked: true,
        autoLockWhenIdle: false
    )

    private enum CodingKeys: String, CodingKey {
        case opacity, scale, anchor, idleTimeoutSeconds, startsUnlocked, autoLockWhenIdle
    }

    init(
        opacity: Double,
        scale: Double,
        anchor: OverlayAnchorPreference,
        idleTimeoutSeconds: Double,
        startsUnlocked: Bool = true,
        autoLockWhenIdle: Bool = false
    ) {
        self.opacity = min(max(opacity, 0.1), 1.0)
        self.scale = min(max(scale, 0.5), 3.0)
        self.anchor = anchor
        self.idleTimeoutSeconds = max(idleTimeoutSeconds, 0)
        self.startsUnlocked = startsUnlocked
        self.autoLockWhenIdle = autoLockWhenIdle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? OverlaySettings.defaults.opacity
        let scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? OverlaySettings.defaults.scale
        let anchor = try container.decodeIfPresent(OverlayAnchorPreference.self, forKey: .anchor)
            ?? OverlaySettings.defaults.anchor
        let idleTimeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .idleTimeoutSeconds)
            ?? OverlaySettings.defaults.idleTimeoutSeconds
        let startsUnlocked = try container.decodeIfPresent(Bool.self, forKey: .startsUnlocked)
            ?? OverlaySettings.defaults.startsUnlocked
        let autoLockWhenIdle = try container.decodeIfPresent(Bool.self, forKey: .autoLockWhenIdle)
            ?? OverlaySettings.defaults.autoLockWhenIdle
        self.init(
            opacity: opacity,
            scale: scale,
            anchor: anchor,
            idleTimeoutSeconds: idleTimeoutSeconds,
            startsUnlocked: startsUnlocked,
            autoLockWhenIdle: autoLockWhenIdle
        )
    }
}

/// Data-source preferences: which patch's data to show and whether to
/// refresh it automatically. Kept to primitives here — this package must not
/// depend on TFTData, so "active patch" is just an identifying string the
/// data layer interprets.
struct DataSettings: Codable, Equatable {
    var activePatch: String
    var autoRefreshEnabled: Bool

    static let defaults = DataSettings(activePatch: "auto", autoRefreshEnabled: true)

    private enum CodingKeys: String, CodingKey {
        case activePatch, autoRefreshEnabled
    }

    init(activePatch: String, autoRefreshEnabled: Bool) {
        self.activePatch = activePatch
        self.autoRefreshEnabled = autoRefreshEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activePatch = try container.decodeIfPresent(String.self, forKey: .activePatch) ?? DataSettings.defaults
            .activePatch
        autoRefreshEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoRefreshEnabled)
            ?? DataSettings.defaults.autoRefreshEnabled
    }
}

/// Typed, versioned app settings persisted to `UserDefaults` as a single
/// JSON blob (#4). Every section decodes each field independently via
/// `decodeIfPresent`, so adding a new field or section later never fails an
/// existing user's decode — it just falls back to that field's default.
/// `schemaVersion` and `migrated(_:)` exist for the rarer case: a structural
/// change (a rename, a value moved between sections) that plain defaulting
/// can't express on its own.
struct AppSettings: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var general: GeneralSettings
    var overlay: OverlaySettings
    var data: DataSettings

    static let defaults = AppSettings(
        schemaVersion: currentSchemaVersion,
        general: .defaults,
        overlay: .defaults,
        data: .defaults
    )

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, general, overlay, data
    }

    init(schemaVersion: Int, general: GeneralSettings, overlay: OverlaySettings, data: DataSettings) {
        self.schemaVersion = schemaVersion
        self.general = general
        self.overlay = overlay
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Missing entirely => a pre-versioning blob (or none at all); treat
        // as schema 0 so `migrated(_:)` has a chance to backfill it.
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        general = try container.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? .defaults
        overlay = try container.decodeIfPresent(OverlaySettings.self, forKey: .overlay) ?? .defaults
        data = try container.decodeIfPresent(DataSettings.self, forKey: .data) ?? .defaults
    }

    /// Applied once on every load. Backfills anything the persisted blob
    /// predates — most commonly a rebindable action added after the user
    /// first saved settings — and bumps `schemaVersion` to current.
    /// Idempotent: running it twice on an already-current blob is a no-op.
    static func migrated(_ settings: AppSettings) -> AppSettings {
        var migrated = settings
        for action in AppHotkeyAction.allCases where migrated.general.hotkeys[action.rawValue] == nil {
            migrated.general.hotkeys[action.rawValue] = action.defaultHotkey
        }
        migrated.schemaVersion = AppSettings.currentSchemaVersion
        return migrated
    }
}
