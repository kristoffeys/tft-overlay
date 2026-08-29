// DEFERRED — this package is a stub. Do not implement real LCU logic here.
//
// TFT removed native macOS support at Set 18 / Patch 18.1 (the Unreal Engine
// client shipping 2026-10-09). On macOS there is no League client, no
// lockfile, no LCU REST/WebSocket API, and no Live Client Data API on port
// 2999 — see README.md. The real host for this project is Mactician, an
// Android emulator running the mobile TFT build, which exposes none of this.
//
// This package exists solely so the dependency graph is ready if/when Riot
// restores native macOS support (tracked as "Deferred — Native macOS client"
// in README.md's phase table). Everything below intentionally reports
// itself as unavailable.

/// Errors surfaced by `LCUClient`. Currently there is exactly one: the LCU
/// simply does not exist on this platform today.
public enum LCUError: Error, Sendable {
    case unavailableOnMacOS
}

/// Stub client for the League Client Update (LCU) API.
///
/// Every operation is a no-op that reports unavailability. Do not add real
/// lockfile/REST/WebSocket handling until Riot ships a native macOS client.
public struct LCUClient: Sendable {
    public init() {}

    /// Always `false` on macOS today.
    public var isAvailable: Bool {
        false
    }

    /// Always throws `LCUError.unavailableOnMacOS`.
    public func connect() async throws {
        throw LCUError.unavailableOnMacOS
    }
}
