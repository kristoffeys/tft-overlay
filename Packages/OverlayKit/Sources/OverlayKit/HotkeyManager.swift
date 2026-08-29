import AppKit

/// A key combination identified by its virtual key code and modifier flags.
public struct Hotkey: Hashable, Sendable {
    public let keyCode: UInt16
    public let modifierFlags: UInt

    public init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
    }
}

/// Registers global hotkeys via `NSEvent` monitors and dispatches them to handlers.
///
/// This is intentionally minimal for Phase 0 — one process-wide monitor
/// fanning out to registered handlers by key combination.
@MainActor
public final class HotkeyManager {
    public typealias Handler = () -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var handlers: [Hotkey: Handler] = [:]

    public init() {}

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    public func register(_ hotkey: Hotkey, handler: @escaping Handler) {
        handlers[hotkey] = handler
        ensureMonitorsInstalled()
    }

    public func unregister(_ hotkey: Hotkey) {
        handlers.removeValue(forKey: hotkey)
    }

    public func unregisterAll() {
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
                if handlers[hotkey] != nil {
                    handle(event)
                    return nil
                }
                return event
            }
        }
    }

    private func handle(_ event: NSEvent) {
        let hotkey = Hotkey(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        handlers[hotkey]?()
    }
}
