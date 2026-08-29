import Foundation

/// Persists `OverlayGeometry` per display, keyed by `OverlayDisplayID`.
///
/// Backed by `UserDefaults` so it works headless (no window server needed),
/// which is what makes it unit-testable — inject a scratch suite in tests
/// instead of `.standard`.
public final class OverlayGeometryStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "com.tftoverlay.overlaykit.geometry") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func load(for display: OverlayDisplayID) -> OverlayGeometry? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key(for: display)) else { return nil }
        return try? JSONDecoder().decode(OverlayGeometry.self, from: data)
    }

    public func save(_ geometry: OverlayGeometry, for display: OverlayDisplayID) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(geometry) else { return }
        defaults.set(data, forKey: key(for: display))
    }

    public func clear(for display: OverlayDisplayID) {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key(for: display))
    }

    private func key(for display: OverlayDisplayID) -> String {
        "\(keyPrefix).\(display)"
    }
}
