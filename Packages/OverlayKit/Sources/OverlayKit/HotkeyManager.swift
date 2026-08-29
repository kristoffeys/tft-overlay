import AppKit
import OSLog

/// A key combination identified by its virtual key code and modifier flags.
public struct Hotkey: Hashable, Sendable, Codable {
    public let keyCode: UInt16
    public let modifierFlags: UInt

    public init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
    }

    /// Raw-value initializer for round-tripping through storage (settings,
    /// tests) where an `NSEvent.ModifierFlags` isn't at hand.
    public init(keyCode: UInt16, rawModifierFlags: UInt) {
        self.keyCode = keyCode
        modifierFlags = NSEvent.ModifierFlags(rawValue: rawModifierFlags)
            .intersection(.deviceIndependentFlagsMask).rawValue
    }
}

/// Stable identifier for a rebindable action (e.g. "toggleInteractive"),
/// independent of whatever key combination is currently bound to it.
public struct HotkeyAction: Hashable, Sendable, Codable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

/// Outcome of attempting to bind a hotkey to an action.
public enum HotkeyRegistrationResult: Sendable, Equatable {
    case registered
    /// The combination is already bound to a different action; registration
    /// was refused so the caller can surface the conflict instead of
    /// silently stealing the other action's binding.
    case conflict(HotkeyAction)
}

/// Registers global hotkeys via `NSEvent` monitors and dispatches them to
/// handlers, keyed by a stable `HotkeyAction` rather than the raw key
/// combination — so a binding can be rebound at runtime without callers
/// re-registering their handler.
///
/// This is intentionally minimal for Phase 0 — one process-wide monitor
/// fanning out to registered handlers by key combination.
@MainActor
public final class HotkeyManager {
    public typealias Handler = () -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var bindings: [HotkeyAction: Hotkey] = [:]
    private var handlers: [HotkeyAction: Handler] = [:]

    public init() {}

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    /// Binds `hotkey` to `action`, replacing any combination previously bound
    /// to that same action. Refuses (returning `.conflict`) when `hotkey` is
    /// already bound to a *different* action — callers should surface that
    /// to the user rather than silently stealing the other binding.
    @discardableResult
    public func register(
        _ hotkey: Hotkey,
        for action: HotkeyAction,
        handler: @escaping Handler
    ) -> HotkeyRegistrationResult {
        if let existing = conflictingAction(for: hotkey, excluding: action) {
            OverlayKitLog.hotkeys.notice(
                "Refused to bind \(action.id, privacy: .public) — \(hotkey.keyCode) already bound to \(existing.id, privacy: .public)"
            )
            return .conflict(existing)
        }
        bindings[action] = hotkey
        handlers[action] = handler
        ensureMonitorsInstalled()
        return .registered
    }

    /// The action (if any) already bound to `hotkey`, other than `action`
    /// itself. Used both internally by `register` and by UI code (e.g. a
    /// hotkey recorder) that wants to warn about a conflict before the user
    /// commits a new binding.
    public func conflictingAction(for hotkey: Hotkey, excluding action: HotkeyAction? = nil) -> HotkeyAction? {
        bindings.first { $0.key != action && $0.value == hotkey }?.key
    }

    public func hotkey(for action: HotkeyAction) -> Hotkey? {
        bindings[action]
    }

    public func unregister(_ action: HotkeyAction) {
        bindings.removeValue(forKey: action)
        handlers.removeValue(forKey: action)
    }

    public func unregisterAll() {
        bindings.removeAll()
        handlers.removeAll()
    }

    private func ensureMonitorsInstalled() {
        // Global: fires while some other app is frontmost (the normal case
        // for an accessory-policy app with no Dock icon). Local: fires when
        // our own overlay panel is key (e.g. it just became key to accept a
        // drag/click while interactive) — without this the hotkey would
        // stop working the moment the panel takes focus.
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event)
            }
        }
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let hotkey = Hotkey(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
                if let action = bindings.first(where: { $0.value == hotkey })?.key {
                    handlers[action]?()
                    return nil
                }
                return event
            }
        }
    }

    private func handle(_ event: NSEvent) {
        let hotkey = Hotkey(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        if let action = bindings.first(where: { $0.value == hotkey })?.key {
            handlers[action]?()
        }
    }
}
