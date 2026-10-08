import Foundation

/// 「行きたい」の場所を現在地から近い順に並べる。リージョン監視とスナップショットで同じ順序を使う。
enum NearestPlaces {
    struct Entry {
        var place: Place
        var distanceMeters: Double
    }

    /// 距離の昇順、同距離は `id.uuidString` の昇順。`limit` が 0 以下なら空。
    static func wantToGo(near location: Coordinate, places: [Place], limit: Int) -> [Entry] {
        guard limit > 0 else { return [] }
        let entries = places
            .filter { $0.status == .wantToGo }
            .map { Entry(place: $0, distanceMeters: location.distance(to: $0.coordinate)) }
            .sorted { lhs, rhs in
                if lhs.distanceMeters != rhs.distanceMeters { return lhs.distanceMeters < rhs.distanceMeters }
                return lhs.place.id.uuidString < rhs.place.id.uuidString
            }
        return Array(entries.prefix(limit))
    }
}
