import Foundation
import OSLog

/// Loads, persists, and publishes `AppSettings`. The single source of truth
/// UI (`PreferencesView`) binds against and `AppDelegate` observes to
/// propagate changes live to the overlay and hotkey manager, with no
/// restart (#4).
@MainActor
final class SettingsStore: ObservableObject {
    static let defaultsKey = "dev.tftoverlay.settings"

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = Self.load(from: defaults)
    }

    static func load(from defaults: UserDefaults) -> AppSettings {
        guard let data = defaults.data(forKey: defaultsKey) else {
            return .defaults
        }
        guard let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            AppLog.settings.error("Failed to decode stored settings; falling back to defaults")
            return .defaults
        }
        return AppSettings.migrated(decoded)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
