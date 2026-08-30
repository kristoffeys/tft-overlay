import Foundation

public enum CompLoaderError: Error, LocalizedError {
    case decodingFailed(file: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case let .decodingFailed(file, underlying):
            "Failed to decode comp \"\(file)\": \(underlying)"
        }
    }
}

/// Decodes `Comp` values from `data/comps/*.json`-shaped files.
public enum CompLoader {
    /// Every `.json` file in `directory`, decoded as a `Comp` and sorted by
    /// filename. Intended for the real `data/comps/` directory at runtime.
    public static func loadAll(from directory: URL) throws -> [Comp] {
        let urls = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { try decode(Data(contentsOf: $0), file: $0.lastPathComponent) }
    }

    public static func load(_ data: Data) throws -> Comp {
        try decode(data, file: "<data>")
    }

    /// The comps bundled with TFTUI itself as fixtures — copies of whatever
    /// `data/comps/` currently holds (the two hand-authored comps plus the
    /// scraper's output, per ADR 0004) — so panels, previews, tests and the
    /// demo app all render without depending on a path outside this package.
    public static func bundledFixtures() throws -> [Comp] {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Comps") ?? []
        return try urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try decode(Data(contentsOf: $0), file: $0.lastPathComponent) }
    }

    private static func decode(_ data: Data, file: String) throws -> Comp {
        do {
            return try JSONDecoder().decode(Comp.self, from: data)
        } catch {
            throw CompLoaderError.decodingFailed(file: file, underlying: error)
        }
    }
}
