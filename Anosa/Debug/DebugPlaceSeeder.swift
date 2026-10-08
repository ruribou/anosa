#if DEBUG
import AnosaKit
import Foundation
import OSLog

/// シミュレータで通知を確かめるための、DEBUG ビルドだけの導線。
/// 起動引数 `-AnosaDebugAddPlace "<名前>,<緯度>,<経度>"` で場所を 1 件「行きたい」に追加する。
/// 同じ名前・同じ座標の場所がすでにあれば追加しない。
@MainActor
enum DebugPlaceSeeder {
    static let argumentKey = "AnosaDebugAddPlace"

    private static let logger = Logger(subsystem: "com.example.anosa", category: "debug")
    /// 座標を同じとみなす差（度）。小数点以下 6 桁（約 0.1m）。
    private static let coordinateTolerance = 0.000_001

    struct Seed: Equatable {
        var name: String
        var coordinate: Coordinate
    }

    static func seedFromLaunchArguments(defaults: UserDefaults = .standard) {
        guard let value = defaults.string(forKey: argumentKey) else { return }
        guard let seed = parse(value) else {
            logger.error("\(argumentKey, privacy: .public) の形式が違います（<名前>,<緯度>,<経度>）")
            return
        }
        do {
            let store = PlaceStore(container: AppContainer.shared)
            let exists = try store.places().contains { place in
                place.name == seed.name
                    && abs(place.latitude - seed.coordinate.latitude) < coordinateTolerance
                    && abs(place.longitude - seed.coordinate.longitude) < coordinateTolerance
            }
            guard !exists else { return }
            try store.save(Place(
                name: seed.name,
                latitude: seed.coordinate.latitude,
                longitude: seed.coordinate.longitude,
                savedAt: Date()
            ))
            logger.info("デバッグ用の場所を追加しました")
        } catch {
            logger.error("デバッグ用の場所を追加できません: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 名前に「,」を含められるよう、後ろの 2 つを緯度・経度として読む。
    static func parse(_ value: String) -> Seed? {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let latitude = Double(parts[parts.count - 2].trimmingCharacters(in: .whitespaces)),
              let longitude = Double(parts[parts.count - 1].trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        let name = parts.dropLast(2).joined(separator: ",").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return Seed(name: name, coordinate: Coordinate(latitude: latitude, longitude: longitude))
    }
}
#endif
