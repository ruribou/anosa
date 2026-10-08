import Foundation

/// App Group で共有する UserDefaults。
enum SharedDefaults {
    /// App Group の suite。取れなければ `.standard`（この場合アプリと拡張で共有されない）。
    static func make() -> UserDefaults {
        UserDefaults(suiteName: AnosaStore.appGroupIdentifier) ?? .standard
    }
}
